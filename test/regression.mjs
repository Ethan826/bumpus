// Usage: node test/regression.mjs <compiler index.js> <output dir> <probe>.
// Each probe uses only the compiler it is given, never the healthy build.
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
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
  assert.equal(result.value0.code.constructor.name, 'TypeMismatch');
  console.log('branch mismatch regression detects the defect');
};

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
  const code = result instanceof Left && result.value0.code.constructor.name;
  assert.ok(code === 'NonExhaustive', 'non-exhaustive match was accepted');
  console.log('exhaustive regression detects the defect');
};

const probes = { branch, 'nil-guard': nilGuard, exhaustive };
assert.ok(probe in probes, `unknown probe: ${probe}`);
probes[probe]();
