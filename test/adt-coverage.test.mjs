import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { checked, rejected, rejectedAt } from './support.mjs';
import { runGoBatch } from './go-batch.mjs';

const list = 'type L = Nil | Cons(Int, L);';
const voidType = 'type Void = V(Void);';
const program = (declarations, parameter, body) =>
  `${declarations} fn f(x: ${parameter}): Int = ${body}; `
  + 'fn main(): Int = 0;';

test('non-exhaustive matches report the canonical witness', () => {
  const rows = [
    [list, 'L', 'match x { Nil => 0, Cons(_, Cons(_, _)) => 1 }',
      'Cons(_, Nil)'],
    ['', 'Bool', 'match x { true => 1 }', 'false'],
    ['', 'Int', 'match x { 0 => 1, 1 => 2 }', '2'],
    [list, 'L', 'match x { Cons(_, _) => 1 }', 'Nil'],
    ['type P = Pair(Bool, Int);', 'P', 'match x { Pair(true, _) => 1 }',
      'Pair(false, _)'],
    ['type P = Pair(Int, Bool);', 'P', 'match x { Pair(_, true) => 1 }',
      'Pair(_, false)'],
    [`${voidType} type U = Z(Void) | Y | X;`, 'U', 'match x { X => 1 }', 'Y']
  ];
  for (const [declarations, parameter, body, witness] of rows) {
    const source = program(declarations, parameter, body);
    const diagnostic = rejectedAt(source, 'E_NON_EXHAUSTIVE', body);
    assert.equal(diagnostic.message, `Missing pattern: ${witness}`, source);
  }
});

const optional = `${voidType} type T = A | C(Void);`;
// The file's one Go execution, through the per-file batch harness (T001).
const batch = runGoBatch(import.meta.url, [
  ['uninhabited', `${optional} fn f(x: T): Int = match x { A => 1 }; `
    + 'fn main(): Int = f(A);']
]);

test('uninhabited constructors need no arm', () => {
  assert.equal(batch.run('uninhabited').trim(), '1');
  checked(program(optional, 'T', 'match x { A => 1, C(v) => 2 }'));
});

test('a wildcard over only uninhabited constructors is redundant', () => {
  const source = program(optional, 'T', 'match x { A => 1, _ => 2 }');
  const diagnostic = rejectedAt(source, 'E_REDUNDANT', '_');
  assert.equal(diagnostic.message, 'Redundant match arm');
});

test('redundant arms are reported at their pattern', () => {
  const rows = [
    [program(list, 'L', 'match x { _ => 0, Nil => 1 }'), 'Nil', 1],
    [program('', 'Bool', 'match x { true => 1, true => 2 }'), 'true', 1]
  ];
  for (const [source, text, nth] of rows) {
    const diagnostic = rejectedAt(source, 'E_REDUNDANT', text, nth);
    assert.equal(diagnostic.message, 'Redundant match arm');
  }
});

test('coverage reports in declaration order and pre-order', () => {
  const outer = 'match x { Nil => match x { _ => 0, Nil => 1 } }';
  const nested = rejectedAt(program(list, 'L', outer),
    'E_NON_EXHAUSTIVE', outer);
  assert.equal(nested.message, 'Missing pattern: Cons(_, _)');
  const first = 'match x { true => 1 }';
  const twice = `fn f(x: Bool): Int = ${first}; `
    + 'fn g(x: Bool): Int = match x { false => 1 }; fn main(): Int = 0;';
  rejectedAt(twice, 'E_NON_EXHAUSTIVE', first);
  const typed = `fn f(x: Bool): Int = ${first}; `
    + 'fn g(): Int = true; fn main(): Int = 0;';
  rejectedAt(typed, 'E_TYPE', 'true', 1);
});

test('the CLI reports E_NON_EXHAUSTIVE on the wire', () => {
  const file = 'negative/non-exhaustive.bumpus';
  const diagnostic = rejected(readFileSync(file, 'utf8'), 'E_NON_EXHAUSTIVE');
  const result = spawnSync('node',
    ['scripts/bumpus.mjs', 'emit', file, '.build/rejected.go'],
    { encoding: 'utf8' });
  assert.equal(result.status, 1);
  const wire = JSON.parse(result.stderr);
  assert.equal(wire.code, 'E_NON_EXHAUSTIVE');
  assert.equal(wire.message, 'Missing pattern: Cons(_, _)');
  assert.deepEqual(wire.span, diagnostic.span);
});
