import test from 'node:test';
import assert from 'node:assert/strict';
import { checkRejectedAt, checkedPoly, resolveRejectedAt, resolved }
  from './phases.mjs';
import { shape } from './fn-shape.mjs';

// FN001 Task 3: lambda parameters, application and pipes through Resolve
// (design §2). Bare names and calls of locals keep their P001 resolution
// until Task 4, so no row here pins one of them.
const main = ' fn main(): Int = 0;';
const g = 'fn g(y: Int): Int = y; ';

// The last function's resolved body, after `g` and before `main`.
const resolvedBody = source => {
  const functions = resolved(source + main).functions;
  return shape(functions[functions.length - 2].body);
};

test('a lambda parameter is a local of its body', () => {
  assert.equal(resolvedBody('fn f(x: Int): Int = (fn(y) => y)(x);'),
    'Apply(Lambda([{local: Just(1), ty: Nothing}], Local(1)), [Local(0)])');
});

test('a lambda parameter shadows a parameter and a function', () => {
  assert.equal(resolvedBody('fn f(x: Int): Int = (fn(x) => x)(x);'),
    'Apply(Lambda([{local: Just(1), ty: Nothing}], Local(1)), [Local(0)])');
  assert.equal(resolvedBody(`${g}fn f(x: Int): Int = (fn(g) => g)(x);`),
    'Apply(Lambda([{local: Just(1), ty: Nothing}], Local(1)), [Local(0)])');
});

test('a match binder inside a lambda shadows its parameter in the arm',
  () => {
    assert.equal(resolvedBody('fn f(x: Int): Int = '
      + 'match x { a => (fn(a) => match a { a => a })(a) };'),
    'Match(Local(0), [{body: Apply(Lambda([{local: Just(2), ty: Nothing}], '
      + 'Match(Local(2), [{body: Local(3), pattern: Bind(3)}])), [Local(1)]),'
      + ' pattern: Bind(1)}])');
  });

test('_ binds nothing, may repeat and may carry an annotation', () => {
  assert.equal(resolvedBody('fn f(x: Int): Int = (fn(_: Int, _, z) => z)(x);'),
    'Apply(Lambda([{local: Nothing, ty: Just(TInt)}, '
    + '{local: Nothing, ty: Nothing}, {local: Just(1), ty: Nothing}], '
    + 'Local(1)), [Local(0)])');
});

test('an annotation may name the signature variables, rigidly', () => {
  assert.equal(resolvedBody('fn f(x: a, y: b): a = '
    + '(fn(z: b -> a, _: Int) => x)(y);'),
  'Apply(Lambda([{local: Just(2), ty: Just(TFun(TVar(1), TVar(0)))}, '
    + '{local: Nothing, ty: Just(TInt)}], Local(0)), [Local(1)])');
});

test('application of a call and pipes resolve their operands', () => {
  assert.equal(resolvedBody(
    `${g}fn f(x: Int): Int = g(1)(x) |> (fn(y) => y);`),
  'Pipe(Apply(Call(0, [Integer(1)]), [Local(0)]), '
    + 'Lambda([{local: Just(1), ty: Nothing}], Local(1)))');
  assert.equal(resolvedBody(`${g}fn f(x: Int): Int = x |> g(1) |> g(2);`),
    'Pipe(Pipe(Local(0), Call(0, [Integer(1)])), Call(0, [Integer(2)]))');
});

const rejections = [
  ['fn f(x: Int): Int = (fn(y, z, y) => y)(x);', 'E_DUPLICATE', 'y', 0,
    'Duplicate parameter y'],
  ['fn f(x: Int): Int = (fn(_, y, _, y) => 1)(x);', 'E_DUPLICATE', 'y', 0,
    'Duplicate parameter y'],
  // The first occurrence of the earliest repeated name, as for functions.
  ['fn f(x: Int): Int = (fn(b, a, a, b) => 1)(x);', 'E_DUPLICATE', 'b', 0,
    'Duplicate parameter b'],
  ['fn f(x: a): a = (fn(y: b) => x)(x);', 'E_UNBOUND', 'b', 0,
    'Unbound type variable b'],
  ['fn g(x: b): b = x; fn f(x: a): a = (fn(y: Int -> b) => x)(x);',
    'E_UNBOUND', 'b', 2, 'Unbound type variable b'],
  ['fn f(x: Int): Int = (fn(y: Q) => y)(x);', 'E_UNBOUND', 'Q', 0,
    'Unbound type Q'],
  ['fn f(x: Int): Int = (fn(y) => missing(y))(x);', 'E_UNBOUND',
    'missing(y)', 0, 'Unbound function missing']
];

for (const [source, code, text, nth, expected] of rejections) {
  test(`${code} ${expected}: ${source}`, () => {
    assert.equal(resolveRejectedAt(source + main, code, text, nth).message,
      expected);
  });
}

// The instantiation rule enters arrow fields (Nested): an arrow is a
// constructor of two arguments, reported at the nested reference.
const list = 'type List(a) = Nil | Cons(a, List(a)); ';
const nestedRows = [
  ['type T(a) = C(Int -> T(List(a))) | E;', 'T(List(a))'],
  ['type T(a) = C(T(List(a)) -> Int) | E;', 'T(List(a))'],
  ['type T(a) = C((Int, a) -> List(T(List(a)))) | E;', 'T(List(a))']
];

for (const [source, text] of nestedRows) {
  test(`E_SPECIALIZATION through an arrow field: ${source}`, () => {
    assert.equal(checkRejectedAt(list + source + main, 'E_SPECIALIZATION',
      text).message, 'Recursive use of T changes its type arguments');
  });
}

test('an arrow field with admissible references checks', () => {
  checkedPoly(`${list}type Box(a) = Box(a -> Box(a)) | Pair((a, List(a)) `
    + `-> Box(Int)) | Done;${main}`);
});
