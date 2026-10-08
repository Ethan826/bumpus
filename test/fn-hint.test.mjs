import test from 'node:test';
import assert from 'node:assert/strict';
import { wire } from '../output/Format.Diagnostic/index.js';
import { after, checkFailure, failsAt } from './fn-checked.mjs';
import { spanAt } from './support.mjs';

// FN001 Task 4: the under-application hint and its provenance rules
// (design §4, §8). Through Parse, Resolve and Check.
const prelude = 'type List(a) = Nil | Cons(a, List(a)); '
  + 'fn add(x: Int, y: Int): Int = x + y; '
  + 'fn add3(x: Int, y: Int, z: Int): Int = x; fn id(x: a): a = x; '
  + 'fn take(n: Int, xs: List(a)): List(a) = xs; '
  + 'fn same(x: a, y: a): Int = 0; fn ap(g: Int -> Int): Int = 0; ';
const main = ' fn main(): Int = 0;';

// [definition of f, marker, text, unhinted message, suffix]
const hinted = [
  ['fn f(): Int = add(1);', '= add', 'add(1)',
    'Expected Int, found Int -> Int', '; missing 1 argument to add?'],
  ['fn f(): Int = add3(1);', '= add3', 'add3(1)',
    'Expected Int, found Int -> Int -> Int',
    '; missing 2 arguments to add3?'],
  ['fn f(): Int = Cons(1);', '= Cons', 'Cons(1)',
    'Expected Int, found List(Int) -> List(Int)',
    '; missing 1 argument to Cons?'],
  ['fn f(): Int = ((add(1)));', '= ((', 'add(1)',
    'Expected Int, found Int -> Int', '; missing 1 argument to add?'],
  ['fn f(): Int = add(add(1), 2);', 'add(add', 'add(1)',
    'Expected Int, found Int -> Int', '; missing 1 argument to add?'],
  ['fn f(x: a): a = add(1);', '= add', 'add(1)',
    'Expected a, found Int -> Int', '; missing 1 argument to add?'],
  ['fn f(): Int = add(1) + 1;', '= add', 'add(1)',
    'Expected Int, found Int -> Int', '; missing 1 argument to add?'],
  ['fn f(): Int = if Cons(1) then 1 else 2;', 'if Cons', 'Cons(1)',
    'Expected Bool, found List(Int) -> List(Int)',
    '; missing 1 argument to Cons?'],
  ['fn f(): List(Int) = take(1);', '= take', 'take(1)',
    'Expected List(Int), found List(_) -> List(_)',
    '; missing 1 argument to take?']
];

for (const [definition, marker, text, message, suffix] of hinted) {
  test(`hint: ${definition}`, () => {
    const source = prelude + definition + main;
    const diagnostic = failsAt(source, marker, text);
    assert.equal(diagnostic.code, 'E_TYPE');
    assert.equal(diagnostic.message, message + suffix);
  });

  // The hint wraps the diagnostic checking reports anyway: without it the
  // code, span and text are the same, less the suffix.
  test(`the hint changes nothing else: ${definition}`, () => {
    const source = prelude + definition + main;
    const failure = checkFailure(source);
    assert.equal(failure.problem.constructor.name, 'Hinted');
    const plain = wire({ problem: failure.problem.value0, span: failure.span });
    const shown = wire(failure);
    assert.equal(plain.code, shown.code);
    assert.deepEqual(plain.span, shown.span);
    assert.deepEqual(plain.span, spanAt(source, text,
      after(source, marker, text)));
    assert.equal(plain.message, message);
    assert.equal(shown.message, plain.message + suffix);
  });
}

// [definition of f, marker, text, message]: no hint.
const unhinted = [
  // Through a local.
  ['fn f(g: Int -> Int): Int = g;', '= g', 'g',
    'Expected Int, found Int -> Int'],
  ['fn f(): Int = match add(1) { g => g + 1 };', '=> g', 'g',
    'Expected Int, found Int -> Int'],
  // Through a lambda.
  ['fn f(): Int = fn(x) => add(1, x);', '= fn', 'fn(x) => add(1, x)',
    'Expected Int, found Int -> Int'],
  ['fn f(): Int = (fn(x) => add(x))(1);', '= (', 'fn(x) => add(x))(1)',
    'Expected Int, found Int -> Int'],
  // Through a pipe.
  ['fn f(): Int = 1 |> add3(2);', '= 1', '1 |> add3(2)',
    'Expected Int, found Int -> Int'],
  // Through another call, and through a further application.
  ['fn f(): Int = id(add(1));', '= id', 'id(add(1))',
    'Expected Int, found Int -> Int'],
  ['fn f(): Int = add3(1)(2);', '= add3', 'add3(1)(2)',
    'Expected Int, found Int -> Int'],
  // No argument applied: a bare reference is not a partial application.
  ['fn f(): Int = add;', '= add', 'add',
    'Expected Int, found Int -> Int -> Int'],
  // The expected type is a function.
  ['fn f(): Int -> Int = add3(1);', '= add3', 'add3(1)',
    'Expected Int -> Int, found Int -> Int -> Int'],
  ['fn f(): Int = ap(add3(1));', 'ap(add3', 'add3(1)',
    'Expected Int -> Int, found Int -> Int -> Int'],
  // The expected type is a meta.
  ['fn f(): Int = match (fn(h) => same(h, Cons(h))) { _ => 0 };',
    'same(h', 'Cons(h)', 'Infinite type: _ occurs in List(_) -> List(_)']
];

for (const [definition, marker, text, message] of unhinted) {
  test(`no hint: ${definition}`, () => {
    const source = prelude + definition + main;
    const diagnostic = failsAt(source, marker, text);
    assert.equal(diagnostic.code, 'E_TYPE');
    assert.equal(diagnostic.message, message);
    assert.notEqual(checkFailure(source).problem.constructor.name, 'Hinted');
  });
}
