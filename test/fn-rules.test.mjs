import test from 'node:test';
import assert from 'node:assert/strict';
import { checkedPoly, resolveRejectedAt, resolved } from './phases.mjs';
import { shape } from './fn-shape.mjs';
import { failsAt } from './fn-checked.mjs';
import { rejectedAt } from './support.mjs';

// FN001 Task 4: bare names (design §2), comparison, patterns on functions,
// printable `main` and type rendering (§3). Through Parse, Resolve, Check.
const prelude = 'type List(a) = Nil | Cons(a, List(a)); '
  + 'type Box(a) = Box(a -> a); '
  + 'fn add(x: Int, y: Int): Int = x + y; fn zero(): Int = 0; ';
const main = ' fn main(): Int = 0;';

const resolvedBody = (definition, index) =>
  shape(resolved(prelude + definition + main).functions[index].body);

test('a bare name is a local, a function, a constructor or nullary', () => {
  assert.equal(resolvedBody('fn f(add: Int): Int = add;', 2), 'Local(0)');
  assert.equal(resolvedBody('fn f(): Int -> Int -> Int = add;', 2),
    'FunctionRef(0)');
  assert.equal(resolvedBody('fn f(): Int -> List(Int) -> List(Int) = Cons;',
    2), 'CtorRef(1)');
  assert.equal(resolvedBody('fn f(): List(Int) = Nil;', 2),
    'Construct(0, [])');
  assert.equal(resolvedBody('fn f(g: Int -> Int): Int = g(1);', 2),
    'Apply(Local(0), [Integer(1)])');
});

test('a bare zero-parameter function needs its call', () => {
  const source = prelude + 'fn f(): Int = zero;' + main;
  assert.equal(resolveRejectedAt(source, 'E_ARITY', 'zero', 1).message,
    'Expected zero()');
  assert.equal(resolveRejectedAt(prelude + 'fn f(): Int = nope;' + main,
    'E_UNBOUND', 'nope').message, 'Unbound local nope');
});

// [definition of f, marker, text, code, message]
const rejections = [
  ['fn f(g: Int -> Int): Bool = g == g;', '= g', 'g', 'E_TYPE',
    'Type Int -> Int is not comparable'],
  ['fn f(b: Box(Int)): Bool = b == b;', '= b', 'b', 'E_TYPE',
    'Type Box(Int) is not comparable'],
  ['fn f(): (Int -> Int) -> Bool = fn(g: Int -> Int) => g == g;', '=> g',
    'g', 'E_TYPE', 'Type Int -> Int is not comparable'],
  ['fn f(g: Int -> Int): Int = match g { 1 => 0, _ => 1 };', '{ 1', '1',
    'E_TYPE', 'Expected Int -> Int, found Int'],
  ['fn f(g: Int -> Int): Int = match g { true => 0, _ => 1 };', '{ true',
    'true', 'E_TYPE', 'Expected Int -> Int, found Bool'],
  ['fn f(g: Int -> Int): Int = match g { Nil => 0, _ => 1 };', '{ Nil',
    'Nil', 'E_TYPE', 'Expected Int -> Int, found List(_)'],
  ['fn f(g: Int -> Int): Int = match g { _ => 0, h => 1 };', ', h', 'h',
    'E_REDUNDANT', 'Redundant match arm'],
  ['fn f(): Bool -> Int = fn(b) => match b { true => 1 };', 'match b',
    'match b { true => 1 }', 'E_NON_EXHAUSTIVE', 'Missing pattern: false'],
  ['fn f(): Int = add;', '= add', 'add', 'E_TYPE',
    'Expected Int, found Int -> Int -> Int'],
  ['fn ap(g: Int -> Int, xs: List(Int)): List(Int) = xs; '
    + 'fn f(): Int = ap;', '= ap', 'ap', 'E_TYPE',
  'Expected Int, found (Int -> Int) -> List(Int) -> List(Int)'],
  ['fn h(g: (Int -> Int) -> Int): Int = 0; fn f(): Int = h;', '= h', 'h',
    'E_TYPE', 'Expected Int, found ((Int -> Int) -> Int) -> Int']
];

for (const [definition, marker, text, code, message] of rejections) {
  test(`${code} ${message}: ${definition}`, () => {
    const diagnostic = failsAt(prelude + definition + main, marker, text);
    assert.equal(diagnostic.code, code);
    assert.equal(diagnostic.message, message);
  });
}

test('only _ and binders match a function, and they cover it', () => {
  for (const definition of [
    'fn f(g: Int -> Int): Int = match g { h => h(1) };',
    'fn f(g: Int -> Int): Int = match g { _ => 0 };',
    'fn f(b: Box(Int)): Int = match b { Box(g) => g(1) };',
    'fn f(x: Int): Bool = (fn(y) => y == x)(1);'
  ]) checkedPoly(prelude + definition + main);
});

const printable = 'Expected fn main() with a printable result type';

test('main must have a printable result type', () => {
  for (const definition of [
    'fn main(): Int -> Int = add(1);',
    'fn main(): Box(Int) = Box(fn(x) => x);',
    'fn main(): List(Int -> Int) = Nil;',
    // Judged before the body.
    'fn main(): Int -> Int = true;'
  ]) {
    const source = prelude + definition;
    assert.equal(rejectedAt(source, 'E_ENTRY', definition).message,
      printable, definition);
  }
  checkedPoly(prelude + 'fn main(): List(Int) = Nil;');
});
