// BACKLOG T003: measures the match ladder that test/match-lift.test.mjs
// times (127 deep, 50 arms; the same source text), so its cost is
// profiled the same way every time rather than ad hoc.
//
//   node scripts/ladder-profile.mjs [--rounds N] [--baseline DIR]
//
// Builds nothing: it reads ./output, and DIR/output for a baseline (a
// built copy of another commit, e.g. `git archive c120d48` extracted with
// .spago and output copied in, then `node scripts/build.mjs` there).
// Prints, with the load average before and after:
// - cold: N fresh processes per tree, alternating with the baseline. Each
//   compiles a small program first (as the test file does), then times
//   one ladder `compile` - the number the test asserts on;
// - steady: per-phase medians (lex, parse, resolve, check, specialize,
//   emit) of 15 in-process repetitions, after one warm-up compile.
// T003 recorded (docs/progress.md, 2026-10-08, load average 5.7): cold
// median 507 ms at c120d48 against 370 ms after the fix; steady parse
// 124 -> 92, check 125 -> 78, emit 43 -> 27 ms (load average 9-11).
import { spawnSync } from 'node:child_process';
import { loadavg } from 'node:os';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const ladderDepth = 127;
const ladderWidth = 50;
const steadyRepetitions = 15;
const defaultRounds = 7;
const small = 'type L = Nil | Cons(Int, L); fn f(xs: L, n: Int): Int = '
  + '(match xs { Nil => n, Cons(h, t) => match t { Nil => h + n, '
  + 'Cons(g, _) => g } }) + (match n { 0 => 1, _ => 2 }); '
  + 'fn main(): Int = match Cons(1, Nil) { '
  + 'Cons(a, _) => f(Cons(a, Nil), a), Nil => 0 };';

// Exactly the test's source.
const ladder = () => {
  const arms = Array.from({ length: ladderWidth - 1 },
    (_, value) => `${value} => f(p, q, r, s, t), `).join('');
  return 'fn f(p: Int, q: Int, r: Int, s: Int, t: Int): Int = '
    + `match p { ${arms}_ => `.repeat(ladderDepth) + 'q'
    + ' }'.repeat(ladderDepth) + '; fn main(): Int = f(1, 2, 3, 4, 5);';
};

const load = () => loadavg().map(value => value.toFixed(2)).join(' ');
const median = values => [...values].sort((a, b) => a - b)[
  Math.floor(values.length / 2)];
const modules = tree => name =>
  import(pathToFileURL(resolve(tree, 'output', name, 'index.js')).href);

const succeeded = (result, phase) => {
  if (!('value0' in result) || result.constructor.name !== 'Right') {
    throw new Error(`${phase} failed`);
  }
  return result.value0;
};

// Child mode: one cold ladder compile in this fresh process.
const cold = async tree => {
  const { compile } = await modules(tree)('Program.Compile');
  succeeded(compile(small), 'warm-up');
  const source = ladder();
  const started = performance.now();
  succeeded(compile(source), 'ladder');
  console.log((performance.now() - started).toFixed(0));
};

const coldRun = tree => {
  const result = spawnSync(process.execPath,
    [process.argv[1], '--cold', tree], { encoding: 'utf8' });
  if (result.status !== 0) throw new Error(result.stderr);
  return Number(result.stdout.trim());
};

const steady = async tree => {
  const imported = modules(tree);
  const { lex } = await imported('Format.Lex');
  const { parse } = await imported('Format.Parse');
  const { resolve: resolveNames } = await imported('Features.Resolve');
  const { check } = await imported('Features.Check');
  const { specialize } = await imported('Features.Specialize');
  const { emit } = await imported('Format.Go');
  const source = ladder();
  const parsed = succeeded(parse(source), 'parse');
  const resolved = succeeded(resolveNames(parsed), 'resolve');
  const checked = succeeded(check(resolved), 'check');
  const specialized = succeeded(specialize(checked), 'specialize');
  const phases = {
    lex: () => lex(source),
    parse: () => parse(source),
    resolve: () => resolveNames(parsed),
    check: () => check(resolved),
    specialize: () => specialize(checked),
    emit: () => emit(specialized)
  };
  const medians = {};
  for (const [name, run] of Object.entries(phases)) {
    const times = [];
    for (let index = 0; index < steadyRepetitions; index++) {
      const started = performance.now();
      run();
      times.push(performance.now() - started);
    }
    medians[name] = Math.round(median(times));
  }
  return medians;
};

const option = (name, fallback) => {
  const index = process.argv.indexOf(name);
  return index === -1 ? fallback : process.argv[index + 1];
};

const main = async () => {
  const rounds = Number(option('--rounds', defaultRounds));
  const baseline = option('--baseline', undefined);
  const trees = baseline === undefined ? [['current', '.']]
    : [['baseline', baseline], ['current', '.']];
  console.log(`load average before: ${load()}`);
  const times = Object.fromEntries(trees.map(([name]) => [name, []]));
  for (let round = 0; round < rounds; round++) {
    for (const [name, tree] of trees) times[name].push(coldRun(tree));
  }
  for (const [name] of trees) {
    console.log(`cold ${name}: ${times[name].join(' ')} `
      + `median ${median(times[name])} ms`);
  }
  for (const [name, tree] of trees) {
    console.log(`steady ${name} (median ms): `
      + JSON.stringify(await steady(tree)));
  }
  console.log(`load average after: ${load()}`);
};

if (process.argv[2] === '--cold') await cold(process.argv[3]);
else await main();
