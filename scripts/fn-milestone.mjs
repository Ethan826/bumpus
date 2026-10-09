// FN001 Task 8 Step 4: the milestone tier of the scale rule (plan, Global
// Constraints). Generates each Task 8 program at 20,000 parameters as
// Bumpus source, compiles it with the CLI, builds the Go with `go build`
// under an explicit 100 s timeout, runs it and checks its output. Prints
// one line per program; exits non-zero on any failure. Not part of
// verify (it takes minutes). Bodies are bounded (test/fn-scale-programs.mjs;
// user decision B, 2026-10-09): a 2n-term `+` tree in one Go expression
// does not build at this width at all (BACKLOG G003).
// Usage: node scripts/fn-milestone.mjs [width]
import { spawnSync } from 'node:child_process';
import { writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { chain, curried, generic, wide } from '../test/fn-scale-programs.mjs';
import { forms } from '../test/fn-linear-forms.mjs';
import { timedBuild } from '../test/go-timed.mjs';

const width = Number(process.argv[2] ?? 20000);
const buildBoundMs = 100_000;
const emitTimeoutMs = 300_000;

// Step 1b's forms that reach Go (all but the rejected mismatch), with the
// output each prints: f returns p0 + p<last>; the pipe's left operand
// becomes the last argument.
const formOutputs = { value: 0, over: 1 + width, lambda: 1, partialFirst: 0,
  partialAll: 1 + 5, parenthesized: 1 + width, pipe: 2 + 1 };
const programs = [['wide', wide(width)], ['chain', chain(width)],
  ['curried', curried(width)], ['generic', generic(width)],
  ...Object.entries(formOutputs).map(([name, output]) =>
    [name, { source: forms[name](width), expected: `${output}\n` }])];

// The CLI's emit time, set by `emitted` for the line printed after it.
let emitMs = 0;
const emitted = (source, dir) => {
  const input = join(dir, 'input.bumpus');
  const go = join(dir, 'main.go');
  writeFileSync(input, source);
  const started = performance.now();
  const result = spawnSync('node', ['scripts/bumpus.mjs', 'emit', input, go],
    { encoding: 'utf8', timeout: emitTimeoutMs });
  if (result.status !== 0) {
    throw new Error(`emit failed: ${result.error ?? result.stderr}`);
  }
  emitMs = performance.now() - started;
  return go;
};

let failures = 0;
for (const [name, { source, expected }] of programs) {
  let line;
  try {
    const built = await timedBuild(dir => emitted(source, dir), buildBoundMs);
    const ok = !built.killed && built.status === 0
      && built.buildMs <= buildBoundMs && built.stdout === expected;
    line = `${ok ? 'ok  ' : 'FAIL'} ${name} n=${width}: emit `
      + `${(emitMs / 1000).toFixed(1)} s, go build `
      + `${(built.buildMs / 1000).toFixed(1)} s${built.killed ? ' (killed)'
        : ''}, output ${JSON.stringify(built.stdout)}`
      + `${ok ? '' : ` expected ${JSON.stringify(expected)} `
        + built.errors.slice(0, 300)}`;
    if (!ok) failures += 1;
  } catch (error) {
    failures += 1;
    line = `FAIL ${name} n=${width}: ${String(error).slice(0, 300)}`;
  }
  console.log(line);
}
process.exitCode = failures === 0 ? 0 : 1;
