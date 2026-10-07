// Usage: node test/regression.mjs <compiler index.js> <output dir> <probe>.
// Each probe uses only the compiler it is given, never the healthy build.
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
const [compilerPath, outputDir, probe] = process.argv.slice(2);
const { compile } = await import(pathToFileURL(resolve(compilerPath)));
const load = name => import(pathToFileURL(resolve(outputDir, name, 'index.js')));
const { Left, Right } = await load('Data.Either');
const goTestTimeoutMs = 120_000;

const branch = () => {
  const result = compile('fn main(): Int = if true then 1 else false;');
  assert.ok(result instanceof Left, 'branch type mismatch was accepted');
  assert.equal(result.value0.problem.constructor.name, 'TypeMismatch');
  console.log('branch mismatch regression detects the defect');
};

// Duplicates `second` in test/adt-match.test.mjs on purpose: probes import
// only the compiler under test, so they cannot share the test's helpers.
const second = 'type IntList = Nil | Cons(Int, IntList); '
  + 'fn second(xs: IntList): Int = match xs '
  + '{ Nil => 0, Cons(_, Nil) => 1, Cons(_, Cons(y, _)) => y }; '
  + 'fn main(): Int = second(Nil);';
const recovering = `package main
import ("fmt"; "testing")
func TestNilField(t *testing.T) {
defer func() { fmt.Println("recovered:", recover()) }()
sprigFn0(sprigTy0{tag: 2})
}
`;

const nilGuard = () => {
  const result = compile(second);
  assert.ok(result instanceof Right, 'nil-guard probe program was rejected');
  const work = mkdtempSync(join(tmpdir(), 'sprig-regression-'));
  let output;
  let status;
  try {
    writeFileSync(join(work, 'main.go'), result.value0);
    writeFileSync(join(work, 'main_test.go'), recovering);
    const run = spawnSync('go', ['test', '-v', 'main.go', 'main_test.go'], {
      encoding: 'utf8', timeout: goTestTimeoutMs, cwd: work,
      env: { ...process.env, GOCACHE: resolve('.build/go-cache') }
    });
    assert.ifError(run.error);
    output = run.stdout + run.stderr;
    status = run.status;
  } finally { rmSync(work, { recursive: true, force: true }); }
  if (status !== 0 || !output.includes('recovered: sprig: unmatched value')) {
    console.error(`nil guard missing\n${output}`);
    process.exit(1);
  }
  console.log('nil-guard regression detects the defect');
};

const exhaustive = () => {
  const result = compile('fn main(): Int = 0; type L = N | K(Int, L); '
    + 'fn f(x: L): Int = match x { N => 0 };');
  const code = result instanceof Left && result.value0.problem.constructor.name;
  assert.ok(code === 'NonExhaustive', 'non-exhaustive match was accepted');
  console.log('exhaustive regression detects the defect');
};

// Runs `main` of the probe program and reports whether it printed true. The
// work directory sits under .build/regression, which scripts/regression.mjs
// clears before each run, so an interrupted probe leaves nothing in $TMPDIR.
const list = 'type L = Nil | Cons(Int, L);';
const printsTrue = body => {
  const result = compile(`${list} fn main(): Bool = ${body};`);
  assert.ok(result instanceof Right, 'order probe program was rejected');
  const work = resolve('.build/regression', probe, 'go-work');
  rmSync(work, { recursive: true, force: true });
  mkdirSync(work, { recursive: true });
  try {
    writeFileSync(join(work, 'main.go'), result.value0);
    const run = spawnSync('go', ['run', 'main.go'], {
      encoding: 'utf8', timeout: goTestTimeoutMs, cwd: work,
      env: { ...process.env, GOCACHE: resolve('.build/go-cache') }
    });
    assert.ifError(run.error);
    assert.equal(run.status, 0, run.stdout + run.stderr);
    return run.stdout === 'true\n';
  } finally { rmSync(work, { recursive: true, force: true }); }
};

const ordered = (body, message) => () => {
  if (!printsTrue(body)) {
    console.error(`${message}: ${body}`);
    process.exit(1);
  }
  console.log(`${probe} regression detects the defect`);
};

const probes = {
  branch, 'nil-guard': nilGuard, exhaustive,
  'ctor-order': ordered('Nil < Cons(0, Nil)', 'constructor order wrong'),
  'first-field': ordered('Cons(1, Nil) > Cons(0, Cons(5, Nil))',
    'first differing field ignored')
};
assert.ok(probe in probes, `unknown probe: ${probe}`);
probes[probe]();
