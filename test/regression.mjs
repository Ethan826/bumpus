// Usage: node test/regression.mjs <compiler index.js> <output dir> <probe>.
// Each probe uses only the compiler it is given, never the healthy build.
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { polyProbes } from './regression-poly.mjs';
import { fnProbes } from './regression-fn.mjs';
const [compilerPath, outputDir, probe] = process.argv.slice(2);
const { compile } = await import(pathToFileURL(resolve(compilerPath)));
const load = name => import(pathToFileURL(resolve(outputDir, name, 'index.js')));
const { Left, Right } = await load('Data.Either');
const { wire } = await load('Format.Diagnostic');
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
waxwingFn0(waxwingTy0{tag: 2})
}
`;

const nilGuard = () => {
  const result = compile(second);
  assert.ok(result instanceof Right, 'nil-guard probe program was rejected');
  const work = mkdtempSync(join(tmpdir(), 'waxwing-regression-'));
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
  if (status !== 0 || !output.includes('recovered: waxwing: unmatched value')) {
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

// Runs the probe program's `main` and returns what it printed. The work
// directory sits under .build/regression, which scripts/regression.mjs
// clears before each run, so an interrupted probe leaves nothing in $TMPDIR.
const list = 'type L = Nil | Cons(Int, L);';
// `go run` of generated Go source; the status and everything printed.
const ran = goSource => {
  const work = resolve('.build/regression', probe, 'go-work');
  rmSync(work, { recursive: true, force: true });
  mkdirSync(work, { recursive: true });
  try {
    writeFileSync(join(work, 'main.go'), goSource);
    const run = spawnSync('go', ['run', 'main.go'], {
      encoding: 'utf8', timeout: goTestTimeoutMs, cwd: work,
      env: { ...process.env, GOCACHE: resolve('.build/go-cache') }
    });
    assert.ifError(run.error);
    return { status: run.status, output: run.stdout + run.stderr,
      stdout: run.stdout };
  } finally { rmSync(work, { recursive: true, force: true }); }
};
const printed = source => {
  const result = compile(source);
  assert.ok(result instanceof Right, 'probe program was rejected');
  const run = ran(result.value0);
  assert.equal(run.status, 0, run.output);
  return run.stdout;
};

const prints = (source, expected, message) => () => {
  const output = printed(source);
  if (output !== expected) {
    console.error(`${message}: ${output}`);
    process.exit(1);
  }
  console.log(`${probe} regression detects the defect`);
};

const ordered = (body, message) =>
  prints(`${list} fn main(): Bool = ${body};`, 'true\n', `${message}: ${body}`);

// Duplicates `capturing` in test/match-lift.test.mjs (probes import only
// the compiler under test): t reaches the middle match only through inner
// scrutinees, and k and h are captured two and three matches down (E005).
const capturing = `${list} fn f(xs: L, k: Int): Int = match xs { `
  + 'Nil => k, Cons(h, t) => match h { '
  + '0 => match t { Nil => k, Cons(g, _) => g + h + k }, '
  + '_ => match k { 0 => h, _ => match t { Nil => h + k, '
  + 'Cons(g2, u) => match u { Nil => g2 + h, Cons(z, _) => z + k } } } } }; '
  + 'fn main(): Int = f(Cons(0, Cons(5, Nil)), 100) '
  + '+ f(Cons(3, Cons(4, Cons(6, Nil))), 1000) + f(Cons(2, Nil), 10) '
  + '+ f(Nil, 1);';

// A lost capture leaves an undefined Go variable, so the build itself fails.
const capture = () => {
  let output;
  try { output = printed(capturing); } catch (error) { output = error.message; }
  if (output !== '1124\n') {
    console.error(`captured local lost: ${output}`);
    process.exit(1);
  }
  console.log('capture regression detects the defect');
};

// Grammar's apply is the only place the remaining input is threaded; if the
// second parser restarts from the first's state, no program parses as written.
const stateThread = () => {
  const result = compile(readFileSync('examples/answer.wxw', 'utf8'));
  const expected = readFileSync('bootstrap/answer.go', 'utf8');
  if (!(result instanceof Right) || result.value0 !== expected) {
    console.error(`parser state not threaded: ${JSON.stringify(result.value0)}`);
    process.exit(1);
  }
  console.log('state-thread regression detects the defect');
};

const probes = {
  branch, 'nil-guard': nilGuard, exhaustive,
  'ctor-order': ordered('Nil < Cons(0, Nil)', 'constructor order wrong'),
  'first-field': ordered('Cons(1, Nil) > Cons(0, Cons(5, Nil))',
    'first differing field ignored'),
  'show-fields': prints(`${list} fn main(): L = Cons(1, Cons(2, Nil));`,
    'Cons(1, Cons(2, Nil))\n', 'printed value lost fields'),
  'state-thread': stateThread, capture
};
const context = { compile, Left, Right, wire, printed, ran, probe };
const external = { ...polyProbes, ...fnProbes };
const delegated = name => () => external[name](context);
for (const name of Object.keys(external)) probes[name] = delegated(name);
assert.ok(probe in probes, `unknown probe: ${probe}`);
probes[probe]();
