import test from 'node:test';
import assert from 'node:assert/strict';
import { wire } from '../output/Format.Diagnostic/index.js';
import { nestingLimit } from '../output/Format.Parse.Grammar/index.js';
import { compile } from '../output/Program.Compile/index.js';
import { checkFailure } from './fn-checked.mjs';
import { nestedBlocks, orderProbes, orders, runs, silent }
  from './fx-block-programs.mjs';
import { runGoBatch } from './go-batch.mjs';
import { interpret, run } from './poly-oracle.mjs';
import { checked, panicOnEntry, rejectedAt, runGo, spanAt }
  from './support.mjs';

// FX001 Task 2: Unit, blocks and monomorphic `let` (design §1, FN002),
// through the CLI pipeline (Program.Compile) and Go, and the independent
// interpreter (test/poly-oracle.mjs).
const probed = go => orderProbes.reduce(
  (text, [index, label]) => panicOnEntry(text, index, label), go);
const batch = runGoBatch(import.meta.url, [
  ...runs.map(([name, source]) => [name, source]),
  ...orders.map(([name, source]) => [name, { source, transform: probed }]),
  ['nested at the limit', nestedBlocks(nestingLimit)]
]);

for (const [name, source, expected] of runs) {
  test(`block runs: ${name}`, () => {
    assert.equal(batch.run(name), `${expected}\n`);
  });
  test(`interpreter agrees: ${name}`, () => {
    assert.equal(interpret(source), expected);
  });
}

for (const [name, source] of silent) {
  test(`entry: ${name}`, () => {
    assert.equal(runGo(source), '');
  });
}

for (const [name, source, label] of orders) {
  test(`evaluation order: ${name} enters ${label} first`, () => {
    const result = batch.result(name);
    assert.ifError(result.error);
    assert.notEqual(result.status, 0, `exit status: ${result.stdout}`);
    const output = result.stdout + result.stderr;
    assert.deepEqual([...output.matchAll(/waxwing-probe: (\w+)/g)]
      .map(match => match[1]), [label], output);
    assert.equal(run(source, orderProbes.map(([, probe]) => probe)).probe,
      label);
  });
}

// The trailing-`;` hint (design §1): the problem checking reports anyway,
// with the suffix; nothing else changes.
const trailing = 'fn main(): Int = { 1; };';
test('a trailing ; that causes Expected Int, found Unit is hinted', () => {
  const diagnostic = rejectedAt(trailing, 'E_TYPE', '{ 1; }');
  assert.equal(diagnostic.message,
    'Expected Int, found Unit; remove the trailing ;?');
  const failure = checkFailure(trailing);
  assert.equal(failure.problem.constructor.name, 'Hinted');
  const plain = wire({ problem: failure.problem.value0, span: failure.span });
  assert.equal(plain.message, 'Expected Int, found Unit');
  assert.deepEqual(plain.span, wire(failure).span);
});

test('the hint needs the trailing ;, not just a Unit value', () => {
  for (const [source, text, nth] of [
    ['fn main(): Int = { 1; () };', '{ 1; () }', 0],
    ['fn main(): Int = ();', '()', 1], ['fn main(): Int = {};', '{}', 0],
    ['fn f(): Unit = (); fn main(): Int = f();', 'f()', 1]]) {
    assert.equal(rejectedAt(source, 'E_TYPE', text, nth).message,
      'Expected Int, found Unit', source);
  }
});

test('a trailing ; inside an argument is hinted at that block', () => {
  const source = 'fn add(x: Int, y: Int): Int = x + y; '
    + 'fn main(): Int = add({ 1; }, 2);';
  assert.equal(rejectedAt(source, 'E_TYPE', '{ 1; }').message,
    'Expected Int, found Unit; remove the trailing ;?');
});

// [source, code, text at the reported span, its occurrence, message]
const rows = [
  ['fn main(): Int = { let x = 1 };', 'E_SYNTAX', '}', 0, 'Expected ;'],
  ['fn main(): Int = { let _ = 1 };', 'E_SYNTAX', '}', 0, 'Expected ;'],
  ['fn main(): Int = { 1 2 };', 'E_SYNTAX', '2', 0, "Expected '}'"],
  ['fn main(): Int = { let 1 = 2; 3 };', 'E_SYNTAX', '1', 0,
    'Expected an identifier'],
  ['fn main(): Int = 1 + { 2 };', 'E_SYNTAX', '{', 0,
    'Expected an expression'],
  ['fn main(): Int = { let y = x; let x = 1; y };', 'E_UNBOUND', 'x', 0,
    'Unbound local x'],
  ['fn main(): Int = ({ let x = 1; x }) + x;', 'E_UNBOUND', 'x', 2,
    'Unbound local x'],
  ['fn main(): Int = { let x = x; x };', 'E_UNBOUND', 'x', 1,
    'Unbound local x'],
  ['fn main(): Int = { let f = fn(x) => x; f(1) + f(true) };', 'E_TYPE',
    'true', 0, 'Expected Int, found Bool'],
  ['fn main(): Unit = { 1 };', 'E_TYPE', '{ 1 }', 0,
    'Expected Unit, found Int'],
  ['fn f(u: Unit): Int = u; fn main(): Int = 0;', 'E_TYPE', 'u', 1,
    'Expected Int, found Unit'],
  ['type Unit = U; fn main(): Int = 0;', 'E_SYNTAX', 'Unit', 0,
    'Expected a capitalized name']
];
for (const [source, code, text, nth, message] of rows) {
  test(`rejected: ${source}`, () => {
    assert.equal(rejectedAt(source, code, text, nth).message, message);
  });
}

// The FX001 words are reserved at once (Global Constraints); `pure` is
// not (it is contextual after `with`, from a later task).
const words = ['effect', 'handler', 'handle', 'with', 'let', 'defer', 'Unit',
  'ctl', 'resume'];
for (const word of words) {
  test(`${word} is reserved`, () => {
    assert.equal(rejectedAt(`fn ${word}(): Int = 1; fn main(): Int = 0;`,
      'E_SYNTAX', word).message, 'Expected an identifier');
  });
}

test(`${nestingLimit} nested blocks build and run; one more is E_NESTING`,
  () => {
    assert.equal(batch.run('nested at the limit'), '1\n');
    const over = nestedBlocks(nestingLimit + 1);
    assert.deepEqual(wire(compile(over).value0), {
      code: 'E_NESTING', message: `Nesting exceeds ${nestingLimit} levels`,
      span: spanAt(over, '0', nestingLimit)
    });
  });

// Each block is a lifted helper numbered in pre-order with matches
// (design §4): main's block is Block0, the match inside it Match1, the
// block in that arm Block2.
test('blocks are lifted and numbered with matches', () => {
  const go = checked('type Box(a) = Box(a); fn main(): Int = '
    + '{ let b = Box(1); match b { Box(n) => { let m = n; m } } };');
  assert.match(go, /^func waxwingFn0Block0\(\) int32 \{$/m);
  assert.match(go, /^func waxwingFn0Match1\(waxwingScrutinee waxwingTy0\) int32/m);
  assert.match(go, /^func waxwingFn0Block2\(waxwingLocal1 int32\) int32 \{$/m);
});
