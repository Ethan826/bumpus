// FX001 Task 1: checks and measures the Go runtime shapes of
// docs/plans/2026-10-09-effects-design.md §4 before any lowering exists
// (docs/plans/2026-10-09-effects-plan.md, Task 1). No compiler code.
//
//   node scripts/effect-probe.mjs            semantic checks, then measurements
//   node scripts/effect-probe.mjs semantics  Step 2 only
//
// Step 2 compares each semantic program's stdout, stderr and exit status
// with scripts/effect-semantics.mjs. Step 3 runs every configuration five
// times (build 300 s, run 120 s timeouts), verifies each printed checksum
// and records load averages before and after each batch. Step 4's rule:
// adopt only if every check passes and the median 4,000-helper `go build`
// is at most 10 s. Raw files and results.json go to .build/fx001-task1/.
import { spawnSync } from 'node:child_process';
import { mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { loadavg } from 'node:os';
import { expected, expectedHelpers, helperProgram, measureProgram }
  from './effect-programs.mjs';
import { semanticCases, semanticProgram } from './effect-semantics.mjs';

const root = '.build/fx001-task1';
const buildTimeoutMs = 300_000;
const runTimeoutMs = 120_000;
const repetitions = 5;
const buildBoundSeconds = 10;
const helperSizes = [1000, 2000, 4000];
const configs = [['install'], ['lookup', '1'], ['lookup', '100'],
  ['lookup', '10000'], ['unwindHandles'], ['unwindCleanups'], ['caught']];

const timed = (command, args, options) => {
  const started = performance.now();
  const result = spawnSync(command, args, { encoding: 'utf8', ...options });
  return { result, ms: performance.now() - started };
};

const load = () => loadavg().map(value => Number(value.toFixed(2)));

const built = (name, go) => {
  const work = join(root, name);
  rmSync(work, { recursive: true, force: true });
  mkdirSync(work, { recursive: true });
  writeFileSync(join(work, 'main.go'), go);
  writeFileSync(join(work, 'go.mod'), 'module effectprobe\n\ngo 1.26\n');
  const env = { ...process.env, GOCACHE: resolve('.build/go-cache') };
  const build = timed('go', ['build', '-o', 'program', '.'],
    { cwd: work, env, timeout: buildTimeoutMs });
  return { work, build };
};

const ok = timedRun => timedRun.result.status === 0;

const checkCase = (work, testCase) => {
  const { result } = timed('./program', [testCase.mode],
    { cwd: work, timeout: runTimeoutMs });
  const pass = result.status === testCase.status
    && result.stdout === testCase.stdout
    && result.stderr === testCase.stderr;
  return { mode: testCase.mode, pass, status: result.status,
    stdout: result.stdout, stderr: result.stderr };
};

const semantics = () => {
  const { work, build } = built('semantics', semanticProgram);
  if (!ok(build)) return [{ mode: 'build', pass: false,
    stderr: build.result.stderr }];
  return semanticCases.map(testCase => checkCase(work, testCase));
};

const median = values => [...values].sort((a, b) => a - b)[2];
const summary = values => ({ median: median(values), min: Math.min(...values),
  max: Math.max(...values) });
const seconds = milliseconds => Number((milliseconds / 1000).toFixed(2));

const wanted = ([name, depth]) => name === 'lookup'
  ? expected.lookup(Number(depth)) : expected[name];

const measureConfig = (work, config) => {
  const runs = Array.from({ length: repetitions }, () => timed('./program',
    config, { cwd: work, timeout: runTimeoutMs }));
  const parsed = runs.map(run => run.result.stdout.trim().split(' ')
    .map(Number));
  const checksumOk = runs.every(ok)
    && parsed.every(([, sum]) => sum === wanted(config));
  return { config: config.join(':'), checksumOk,
    milliseconds: summary(parsed.map(([ns]) => Number((ns / 1e6).toFixed(3)))) };
};

const buildSizes = () => helperSizes.map(count => {
  const times = [];
  let checksumOk = true;
  for (let rep = 0; rep < repetitions; rep++) {
    const { work, build } = built(`helpers-${count}`,
      helperProgram(count, `${Date.now()}-${rep}`));
    times.push(seconds(build.ms));
    const run = timed('./program', [], { cwd: work, timeout: runTimeoutMs });
    checksumOk &&= ok(build) && ok(run)
      && Number(run.result.stdout) === expectedHelpers(count);
  }
  return { helpers: count, checksumOk, seconds: summary(times), times };
});

const batch = (name, work) => {
  const before = { load: load(), uptime: timed('uptime', []).result.stdout.trim() };
  const rows = work();
  const after = { load: load(), uptime: timed('uptime', []).result.stdout.trim() };
  return { name, before, after, rows };
};

const measurements = () => {
  const { work, build } = built('measure', measureProgram);
  const runtimeBatch = batch('runtime', () => ok(build)
    ? configs.map(config => measureConfig(work, config))
    : [{ error: build.result.stderr }]);
  return [runtimeBatch, batch('go build', buildSizes)];
};

mkdirSync(root, { recursive: true });
const checks = semantics();
for (const check of checks) console.log(JSON.stringify(check));
const results = { checks };
if (process.argv[2] !== 'semantics') {
  results.batches = measurements();
  for (const group of results.batches) console.log(JSON.stringify(group));
  const bigBuild = results.batches[1].rows.find(row => row.helpers === 4000);
  const adopt = checks.every(check => check.pass)
    && results.batches[1].rows.every(row => row.checksumOk)
    && results.batches[0].rows.every(row => row.checksumOk)
    && bigBuild.seconds.median <= buildBoundSeconds;
  results.decision = adopt ? 'ADOPT' : 'BLOCKED';
  console.log(`decision: ${results.decision}`);
}
writeFileSync(join(root, 'results.json'), JSON.stringify(results, null, 2) + '\n');
