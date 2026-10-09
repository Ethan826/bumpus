// Differential check of two built compilers, phase by phase. Use it for
// behavior-preserving refactors and performance work (T003): build the
// old commit in an isolated copy (e.g. `git archive <commit>` extracted,
// with .spago and output copied in, then `node scripts/build.mjs`), and
// compare it with the working tree.
//
//   node scripts/differential.mjs --baseline DIR [--candidate DIR]
//     [--corpus harvested|fuzz|matches|mutations|all] [--seed N]
//     [--count N] [--harvest FILE] [--regenerate]
//
// Each directory needs a built output/. For every source both compilers
// run lex (tokens or the wire diagnostic), parse, resolve, check and
// specialize (structural hashes of each result or the diagnostic),
// Go emission and the full compile; the first phase that disagrees is a
// difference. Corpora: `harvested` is every source the candidate's own
// test suite parses, plus examples/ and negative/ (regenerate it with
// --regenerate, which runs `node --test test/*.test.mjs` under
// scripts/differential-hook.mjs; it lands in .build, not git);
// `fuzz` is token soups, fixed lexer cases and `isName` probes;
// `matches` is generated nested-match programs; `mutations` edits
// harvested sources. Prints counts and the first differences, and exits
// 1 on any difference. T003 (2026-10-08) compared c120d48 with 7c6c0f5
// this way: 50,453 cases, 0 differences.
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import {
  existsSync, readFileSync, readdirSync, rmSync, writeFileSync
} from 'node:fs';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import {
  matchPrograms, mutations, nameProbes, random, soups, targeted
} from './differential-corpus.mjs';

const shownDifferences = 5;
const mutationSourceLimit = 3000;
const corpora = ['harvested', 'fuzz', 'matches', 'mutations'];

const option = (name, fallback) => {
  const index = process.argv.indexOf(name);
  return index === -1 ? fallback : process.argv[index + 1];
};

const compiler = async tree => {
  const load = name => import(pathToFileURL(
    resolve(tree, 'output', name, 'index.js')).href);
  const modules = ['Format.Lex', 'Format.Parse', 'Features.Resolve',
    'Features.Check', 'Features.Specialize', 'Format.Go',
    'Format.Diagnostic', 'Data.Either', 'Program.Compile'];
  const [lex, parse, resolution, check, specialize, go, diagnostic,
    either, compile] = await Promise.all(modules.map(load));
  return { lex: lex.lex, isName: lex.isName, parse: parse.parse,
    resolve: resolution.resolve, check: check.check,
    specialize: specialize.specialize, emit: go.emit,
    wire: diagnostic.wire, Left: either.Left, compile: compile.compile };
};

// Iterative, so a deeply nested IR cannot overflow the JS stack.
const digest = value => {
  const hash = createHash('sha1');
  const pending = [value];
  while (pending.length > 0) {
    const item = pending.pop();
    if (item === null || typeof item !== 'object') {
      hash.update(`${typeof item}:${String(item)};`);
    } else if (Array.isArray(item)) {
      hash.update(`[${item.length};`);
      for (let index = item.length - 1; index >= 0; index--) {
        pending.push(item[index]);
      }
    } else {
      const keys = Object.keys(item).sort();
      hash.update(`{${item.constructor?.name}:${keys.join(',')};`);
      for (let index = keys.length - 1; index >= 0; index--) {
        pending.push(item[keys[index]]);
      }
    }
  }
  return hash.digest('hex');
};

const textHash = text => createHash('sha1').update(text).digest('hex');

// Phase name → result hash or diagnostic, in pipeline order, stopping at
// the first rejection.
const outcome = (compiler, source) => {
  const phases = [];
  const step = (name, run) => {
    const result = run();
    if (result instanceof compiler.Left) {
      phases.push([name, `rejected ${JSON.stringify(
        compiler.wire(result.value0))}`]);
      return undefined;
    }
    phases.push([name, digest(result.value0)]);
    return result.value0;
  };
  if (step('lex', () => compiler.lex(source)) === undefined) return phases;
  const parsed = step('parse', () => compiler.parse(source));
  const resolved = parsed && step('resolve', () => compiler.resolve(parsed));
  const checked = resolved && step('check', () => compiler.check(resolved));
  const specialized = checked
    && step('specialize', () => compiler.specialize(checked));
  if (specialized === undefined) return phases;
  try {
    phases.push(['emit', textHash(compiler.emit(specialized))]);
  } catch (error) {
    phases.push(['emit', `threw ${error.message}`]);
  }
  const compiled = compiler.compile(source);
  phases.push(['compile', compiled instanceof compiler.Left
    ? `rejected ${JSON.stringify(compiler.wire(compiled.value0))}`
    : textHash(compiled.value0)]);
  return phases;
};

const guarded = (compiler, source) => {
  try {
    return outcome(compiler, source);
  } catch (error) {
    return [['crash', `${error.constructor.name}: ${error.message}`]];
  }
};

const firstDifference = (left, right) => {
  const length = Math.max(left.length, right.length);
  for (let index = 0; index < length; index++) {
    if (JSON.stringify(left[index]) !== JSON.stringify(right[index])) {
      return { phase: (left[index] ?? right[index])[0],
        baseline: left[index]?.[1], candidate: right[index]?.[1] };
    }
  }
  return undefined;
};

const compare = (pair, label, sources) => {
  const reached = {};
  const differences = [];
  for (const source of sources) {
    const left = guarded(pair.baseline, source);
    const right = guarded(pair.candidate, source);
    for (const [phase] of left) reached[phase] = (reached[phase] ?? 0) + 1;
    const found = firstDifference(left, right);
    if (found !== undefined) differences.push({ ...found, source });
  }
  console.log(`${label}: ${sources.length} sources, `
    + `${differences.length} differences; phases reached `
    + JSON.stringify(reached));
  for (const found of differences.slice(0, shownDifferences)) {
    console.log(`  ${found.phase}: baseline ${found.baseline}`
      + `\n    candidate ${found.candidate}`
      + `\n    source ${JSON.stringify(found.source.slice(0, 200))}`);
  }
  return differences.length;
};

const compareNames = (pair, probes) => {
  const differing = probes.filter(text =>
    pair.baseline.isName(text) !== pair.candidate.isName(text));
  console.log(`isName: ${probes.length} probes, `
    + `${differing.length} differences`);
  for (const text of differing.slice(0, shownDifferences)) {
    console.log(`  ${JSON.stringify(text)}`);
  }
  return differing.length;
};

const regenerate = (candidate, file) => {
  rmSync(file, { force: true });
  const tests = readdirSync(join(candidate, 'test'))
    .filter(name => name.endsWith('.test.mjs')).map(name => `test/${name}`);
  const hook = new URL('./differential-hook.mjs', import.meta.url).href;
  const result = spawnSync(process.execPath, ['--test', ...tests], {
    cwd: candidate, encoding: 'utf8',
    env: { ...process.env, BUMPUS_HARVEST: file,
      NODE_OPTIONS: `${process.env.NODE_OPTIONS ?? ''} --import=${hook}` }
  });
  // A failing test (e.g. a timing bound under load) still harvested its
  // sources; report it rather than discard the corpus, and keep the run's
  // output so the failure can be identified (it was once discarded).
  const log = `${file}.log`;
  writeFileSync(log, `${result.stdout ?? ''}${result.stderr ?? ''}`);
  console.log(`harvest: test run exited ${result.status}; log ${log}`);
  const failed = (result.stdout ?? '').split('\n')
    .filter(line => line.startsWith('✖ ') && !/failing tests/.test(line));
  for (const line of [...new Set(failed)]) console.log(`  ${line}`);
};

const sourcesIn = (tree, directory) => {
  const path = join(tree, directory);
  return existsSync(path) ? readdirSync(path).sort()
    .map(name => readFileSync(join(path, name), 'utf8')) : [];
};

const harvested = (candidate, file) => {
  if (!existsSync(file)) {
    throw new Error(`no harvest at ${file}; rerun with --regenerate`);
  }
  const lines = readFileSync(file, 'utf8').split('\n').filter(Boolean);
  return [...new Set([...lines.map(line => JSON.parse(line)),
    ...sourcesIn(candidate, 'examples'),
    ...sourcesIn(candidate, 'negative')])];
};

const main = async () => {
  const baseline = option('--baseline', undefined);
  if (baseline === undefined) throw new Error('--baseline DIR is required');
  const candidate = resolve(option('--candidate', '.'));
  const chosen = option('--corpus', 'all');
  const selected = chosen === 'all' ? corpora : [chosen];
  if (!selected.every(name => corpora.includes(name))) {
    throw new Error(`--corpus must be one of ${corpora.join('|')}|all`);
  }
  const stream = random(Number(option('--seed', 1)));
  const count = Number(option('--count', 1000));
  const file = resolve(option('--harvest',
    '.build/differential-harvest.jsonl'));
  if (process.argv.includes('--regenerate')) regenerate(candidate, file);
  const pair = { baseline: await compiler(resolve(baseline)),
    candidate: await compiler(candidate) };
  const needsHarvest = selected.includes('harvested')
    || selected.includes('mutations');
  const corpus = needsHarvest ? harvested(candidate, file) : [];
  let differences = 0;
  for (const name of selected) {
    if (name === 'harvested') {
      differences += compare(pair, name, corpus);
    } else if (name === 'fuzz') {
      differences += compare(pair, 'fuzz', [...targeted(),
        ...soups(stream, count)]);
      differences += compareNames(pair, nameProbes(stream, count));
    } else if (name === 'matches') {
      differences += compare(pair, name, matchPrograms(stream, count));
    } else {
      const small = corpus.filter(source =>
        source.length < mutationSourceLimit);
      differences += compare(pair, name, mutations(stream, small, count));
    }
  }
  console.log(`total differences: ${differences}`);
  process.exitCode = differences === 0 ? 0 : 1;
};

await main();
