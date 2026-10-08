// FN001 Task 1: builds and runs the staged-value programs of
// scripts/stage-{shapes,baselines,mixed,order}.mjs and reports build time,
// run time per full application, binary size, and the growth exponent of
// every program measured at both 5,000 and 20,000
// (docs/plans/2026-10-08-functions-plan.md, Task 1).
//
//   node scripts/stage-probe.mjs                   round 2's matrix
//   node scripts/stage-probe.mjs packed:5000:b64 … chosen runs
//   node scripts/stage-probe.mjs order             evaluation-order checks
//
// Modes: `full` (per-stage statements), `idle` and `bare` (build only),
// `chain` (one chained expression), `bNN` (blocks of NN stages).
// Every build and run has an explicit timeout, recorded as such. Rounds are
// chosen per shape so the timed phase dominates process start-up: about
// `stageBudget` stage applications for linear shapes, fewer for `copied`,
// whose stages each copy the whole environment. Raw files and results go
// to .build/fn001-task1/.
import { spawnSync } from 'node:child_process';
import { mkdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { baseline, baselineShapes } from './stage-baselines.mjs';
import { mixed, mixedShapes } from './stage-mixed.mjs';
import { orderProgram } from './stage-order.mjs';
import { checksum, program } from './stage-shapes.mjs';

const root = '.build/fn001-task1';
const buildTimeoutMs = 300_000;
const runTimeoutMs = 120_000;
const stageBudget = 40_000_000;
const copiedBudget = 400_000_000;
// Step 3, as a growth exponent: t(20,000) / t(5,000) = 4^k. Linear is
// k = 1 and quadratic k = 2; a ratio bound such as "within 5 × 4" admits
// 16, so it cannot tell them apart (the first full run, 2026-10-08, passed
// a 16.4× build that way). Up to this k counts as linear.
const linearExponent = 1.25;

const sizes = [5000, 20000];
const defaults = [
  ...baselineShapes.map(shape => [shape, 'full']),
  ['directMixed', 'full'],
  ...['packedArray', 'packedStruct'].flatMap(shape =>
    [[shape, 'idle'], [shape, 'b64']]),
  ...['b16', 'b64', 'b256'].map(mode => ['packed', mode])
].flatMap(([shape, mode]) => sizes.map(n => [shape, n, mode]));

// Small chains whose boundaries fall inside blocks, on block edges, and in
// the first block; k > m, so the shared partial is past `g`'s boundary.
const orderCases = [
  { n: 40, m: 13, k: 29, block: 8 },
  { n: 40, m: 16, k: 32, block: 16 },
  { n: 7, m: 2, k: 3, block: 3 },
  { n: 300, m: 150, k: 200, block: 64 }
];

const buildOnly = mode => ['idle', 'bare'].includes(mode);

// Every generator returns the Go text and the checksum a timed run must
// print, or null for a build-only program.
const generate = (shape, n, count, mode) => {
  if (baselineShapes.includes(shape)) return baseline(shape, n, count);
  if (mixedShapes.includes(shape)) return mixed(shape, n, count, mode);
  return { go: program(shape, n, count, mode),
    expected: buildOnly(mode) ? null : checksum(n, count) };
};

const rounds = (shape, n) => Math.max(1, Math.floor(shape === 'copied'
  ? copiedBudget / (n * n) : stageBudget / n));

const seconds = milliseconds => Number((milliseconds / 1000).toFixed(2));

const timed = (command, args, options) => {
  const started = performance.now();
  const result = spawnSync(command, args, { encoding: 'utf8', ...options });
  return { result, ms: performance.now() - started };
};

const outcome = result => result.error?.code === 'ETIMEDOUT' ? 'timeout'
  : result.status === 0 ? 'ok'
    : `failed (${result.status}): ${(result.stderr ?? '').slice(0, 300)}`;

const built = (name, go) => {
  const work = join(root, name);
  rmSync(work, { recursive: true, force: true });
  mkdirSync(work, { recursive: true });
  writeFileSync(join(work, 'main.go'), go);
  writeFileSync(join(work, 'go.mod'), 'module stageprobe\n\ngo 1.26\n');
  const env = { ...process.env, GOCACHE: resolve('.build/go-cache') };
  const build = timed('go', ['build', '-o', 'program', '.'],
    { cwd: work, env, timeout: buildTimeoutMs });
  return { work, build };
};

const measure = (shape, n, mode) => {
  const count = rounds(shape, n);
  const generated = generate(shape, n, count, mode);
  const { work, build } = built(`${shape}-${n}-${mode}`, generated.go);
  const row = { shape, n, mode, rounds: count, build: outcome(build.result),
    buildSeconds: seconds(build.ms) };
  if (row.build !== 'ok' || generated.expected === null) return row;
  row.binaryBytes = statSync(join(work, 'program')).size;
  const run = timed('./program', [], { cwd: work, timeout: runTimeoutMs });
  row.run = outcome(run.result);
  if (row.run !== 'ok') return row;
  const [nanoseconds, printed] = run.result.stdout.trim().split(' ')
    .map(Number);
  row.checksumOk = printed === generated.expected;
  row.runSeconds = seconds(nanoseconds / 1e6);
  row.microsecondsPerApplication =
    Number((nanoseconds / 1000 / count).toFixed(3));
  return row;
};

const exponent = (small, large) => Math.log(large / small) / Math.log(4);

const judged = (small, large, key) => {
  if (small[key] === undefined || large[key] === undefined) return 'n/a';
  const k = exponent(small[key], large[key]);
  return `${k <= linearExponent ? 'linear' : 'NOT linear'} (k = `
    + `${k.toFixed(2)})`;
};

// One line per shape and mode measured at both sizes. A failed build, run
// or checksum is reported as such, never judged.
const verdicts = results => {
  const pairs = new Map();
  for (const row of results) {
    const key = `${row.shape}:${row.mode}`;
    pairs.set(key, { ...pairs.get(key), [row.n]: row });
  }
  return [...pairs].filter(([, pair]) => pair[5000] && pair[20000])
    .map(([key, pair]) => {
      const failed = [pair[5000], pair[20000]].find(row =>
        row.build !== 'ok' || (row.run && row.run !== 'ok')
        || row.checksumOk === false);
      return failed ? `${key}: incomplete (${failed.n}: ${failed.build}`
        + `${failed.run ? `, run ${failed.run}` : ''}`
        + `${failed.checksumOk === false ? ', checksum wrong' : ''})`
        : `${key}: build ${judged(pair[5000], pair[20000], 'buildSeconds')}`
          + `, run ${judged(pair[5000], pair[20000],
            'microsecondsPerApplication')}`;
    });
};

const checkOrder = (options, index) => {
  const { go, expected } = orderProgram(options);
  const { work, build } = built(`order-${index}`, go);
  const row = { order: options, build: outcome(build.result) };
  if (row.build !== 'ok') return row;
  const run = timed('./program', [], { cwd: work, timeout: runTimeoutMs });
  row.run = outcome(run.result);
  row.matches = run.result.stdout === expected;
  if (!row.matches) row.output = run.result.stdout.slice(0, 400);
  return row;
};

const argumentsGiven = process.argv.slice(2);
mkdirSync(root, { recursive: true });
if (argumentsGiven[0] === 'order') {
  for (const row of orderCases.map(checkOrder)) {
    console.log(JSON.stringify(row));
  }
} else {
  const requested = argumentsGiven.map(text => {
    const [shape, n, mode = 'full'] = text.split(':');
    return [shape, Number(n), mode];
  });
  const results = [];
  for (const [shape, n, mode] of requested.length ? requested : defaults) {
    const row = measure(shape, n, mode);
    results.push(row);
    console.log(JSON.stringify(row));
  }
  writeFileSync(join(root, 'results.json'),
    JSON.stringify(results, null, 2) + '\n');
  for (const line of verdicts(results)) console.log(line);
}
