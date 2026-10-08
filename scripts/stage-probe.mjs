// FN001 Task 1: builds and runs the staged-value shapes of
// scripts/stage-shapes.mjs and reports build time, run time per full
// application, binary size and the linear-cost verdict for `linked`
// (docs/plans/2026-10-08-functions-plan.md, Task 1 Step 3).
//
//   node scripts/stage-probe.mjs                 the default matrix
//   node scripts/stage-probe.mjs linked:5000 …   chosen runs
//   node scripts/stage-probe.mjs linked:5000:idle  build-only attribution
//
// Every build and run has an explicit timeout, recorded as such. Rounds are
// chosen per shape so the timed phase dominates process start-up: about
// `stageBudget` stage applications for linear shapes, fewer for `copied`,
// whose stages each copy the whole environment. Raw files and results go
// to .build/fn001-task1/.
import { spawnSync } from 'node:child_process';
import { mkdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
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

const defaults = [
  ...[50, 300, 1000, 5000, 20000].map(n => ['linked', n, 'full']),
  ...[5000, 20000].map(n => ['linked', n, 'idle']),
  ...[5000, 20000].map(n => ['direct', n, 'full']),
  ...[50, 300, 1000, 5000].map(n => ['copied', n, 'full']),
  ...[50, 200].map(n => ['nested', n, 'full'])
];

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

const measure = (shape, n, mode) => {
  const count = rounds(shape, n);
  const work = join(root, `${shape}-${n}-${mode}`);
  rmSync(work, { recursive: true, force: true });
  mkdirSync(work, { recursive: true });
  writeFileSync(join(work, 'main.go'), program(shape, n, count, mode));
  writeFileSync(join(work, 'go.mod'), 'module stageprobe\n\ngo 1.26\n');
  const env = { ...process.env, GOCACHE: resolve('.build/go-cache') };
  const build = timed('go', ['build', '-o', 'program', '.'],
    { cwd: work, env, timeout: buildTimeoutMs });
  const row = { shape, n, mode, rounds: count, build: outcome(build.result),
    buildSeconds: seconds(build.ms) };
  if (row.build !== 'ok' || ['idle', 'bare'].includes(mode)) return row;
  row.binaryBytes = statSync(join(work, 'program')).size;
  const run = timed('./program', [], { cwd: work, timeout: runTimeoutMs });
  row.run = outcome(run.result);
  if (row.run !== 'ok') return row;
  const [nanoseconds, printed] = run.result.stdout.trim().split(' ')
    .map(Number);
  row.checksumOk = printed === checksum(n, count);
  row.runSeconds = seconds(nanoseconds / 1e6);
  row.microsecondsPerApplication =
    Number((nanoseconds / 1000 / count).toFixed(3));
  return row;
};

const exponent = (small, large) => Math.log(large / small) / Math.log(4);

const verdict = results => {
  const at = n => results.find(row =>
    row.shape === 'linked' && row.mode === 'full' && row.n === n);
  const small = at(5000);
  const large = at(20000);
  if (!small?.checksumOk || !large?.checksumOk) {
    return 'linked: incomplete (a 5,000 or 20,000 run failed or is missing)';
  }
  const judged = key => {
    const k = exponent(small[key], large[key]);
    return `${k <= linearExponent ? 'linear' : 'NOT linear'} (k = `
      + `${k.toFixed(2)})`;
  };
  return `linked: build ${judged('buildSeconds')}, run `
    + `${judged('microsecondsPerApplication')}`;
};

const requested = process.argv.slice(2).map(text => {
  const [shape, n, mode = 'full'] = text.split(':');
  return [shape, Number(n), mode];
});

mkdirSync(root, { recursive: true });
const results = [];
for (const [shape, n, mode] of requested.length ? requested : defaults) {
  const row = measure(shape, n, mode);
  results.push(row);
  console.log(JSON.stringify(row));
}
writeFileSync(join(root, 'results.json'),
  JSON.stringify(results, null, 2) + '\n');
console.log(verdict(results));
