import test from 'node:test';
import assert from 'node:assert/strict';
import { TBool, TData, TInt, TVar } from '../output/Domain.Type/index.js';
import { Hole, Rigid } from '../output/Domain.Checked.Internal/index.js';
import { checkRejectedAt, checkedPoly } from './phases.mjs';
import { rejectedAt } from './support.mjs';

// P001 Task 4: rank-1 polymorphic checking. Each rejection row runs twice:
// through Parse, Resolve and Check, as Task 4 wrote it, and through the
// whole `compile` the CLI runs, which since Task 7 also specializes and
// emits polymorphic programs (design §8 asks typing rows of the CLI). Both
// must report the same code, span and text.
const prelude = 'type List(a) = Nil | Cons(a, List(a));'
  + ' type Pair(a, b) = Pair(a, b); type Maybe(a) = Nothing | Just(a);'
  + ' type Proxy(a) = Proxy; ';
const main = ' fn main(): Int = 0;';

// The occurrence of `text` that is the first at or after `marker`.
const after = (source, marker, text) => {
  const from = source.indexOf(marker);
  assert.notEqual(from, -1, `${marker} not found`);
  return source.slice(0, from).split(text).length - 1;
};

// [program after the prelude, marker, text, message]
const rows = [
  ['fn f(x: a): Int = x;' + main, '= x', 'x', 'Expected Int, found a'],
  ['fn g(x: a, y: b): a = y;' + main, '= y', 'y', 'Expected a, found b'],
  ['fn same(x: a, y: a): Int = 0; fn main(): Int = match Nil {'
    + ' Cons(h, t) => same(h, t), Nil => 0 };', 'same(h, t)', 't',
  'Infinite type: _ occurs in List(_)'],
  ['fn same(x: a, y: a): Bool = x == y;' + main, '= x', 'x',
    'Type a is not comparable'],
  ['fn same(x: List(a), y: List(a)): Bool = x == y;' + main, '= x', 'x',
    'Type List(a) is not comparable'],
  ['fn main(): Bool = Nil == Nil;', 'Bool = Nil', 'Nil',
    'Ambiguous type List(_) in comparison'],
  ['fn main(): Bool = Proxy == Proxy;', 'Bool = Proxy', 'Proxy',
    'Ambiguous type Proxy(_) in comparison'],
  ['fn f(x: a): Int = match x { 1 => 0, _ => 1 };' + main, '{ 1', '1',
    'Expected a, found Int'],
  ['fn f(x: a): Int = match x { Nothing => 0, _ => 1 };' + main,
    '{ Nothing', 'Nothing', 'Expected a, found Maybe(_)'],
  // A mismatch names the whole types, not only the differing arguments.
  ['fn main(): Pair(Int, Int) = Pair(1, true);', '= Pair', 'Pair(1, true)',
    'Expected Pair(Int, Int), found Pair(Int, Bool)'],
  ['fn f(x: a): Maybe(a) = Nothing; fn main(): Int = f(Nil);', '= f',
    'f(Nil)', 'Expected Int, found Maybe(List(_))'],
  // Arguments unify left to right: the first fixes `a`, the second fails.
  ['fn g(x: a, y: a): Int = 0; fn main(): Int = g(1, true);', 'g(1, true)',
    'true', 'Expected Int, found Bool'],
  // A rigid variable is still not comparable when a hole sits beside it.
  ['fn f(x: a): Bool = Pair(x, Nil) == Pair(x, Nil);' + main, '= Pair',
    'Pair(x, Nil)', 'Type Pair(a, List(_)) is not comparable']
];

for (const [program, marker, text, expected] of rows) {
  const source = prelude + program;
  const nth = after(source, marker, text);
  test(`E_TYPE ${expected}: ${program}`, () => {
    const diagnostic = checkRejectedAt(source, 'E_TYPE', text, nth);
    assert.equal(diagnostic.message, expected);
  });
  test(`compile: E_TYPE ${expected}: ${program}`, () => {
    const diagnostic = rejectedAt(source, 'E_TYPE', text, nth);
    assert.equal(diagnostic.message, expected);
  });
}

const hole = k => TVar.create(Hole.create(k));
const rigid = i => TVar.create(Rigid.create(i));
const body = (program, index) => program.functions[index].body.value0;
const node = (program, index) => body(program, index).node;

test('generic calls check at each use: pair(id(1), id(true))', () => {
  const program = checkedPoly(prelude + 'fn id(x: a): a = x;'
    + ' fn pair(x: a, y: b): Pair(a, b) = Pair(x, y);'
    + ' fn main(): Pair(Int, Bool) = pair(id(1), id(true));');
  const call = node(program, 2);
  assert.deepEqual(call.value1, [TInt.value, TBool.value]);
  assert.deepEqual(call.value2.map(argument => argument.value0.node.value1),
    [[TInt.value], [TBool.value]]);
  assert.deepEqual(body(program, 2).ty,
    TData.create(1)([TInt.value, TBool.value])([]));
  // Inside its own declaration a variable is rigid.
  assert.deepEqual(node(program, 1).value1, [rigid(0), rigid(1)]);
});

test('one constructor is used at two types in one function', () => {
  const program = checkedPoly(prelude + 'fn main(): Pair(Maybe(Int),'
    + ' Maybe(Bool)) = Pair(Just(1), Just(true));');
  const [first, second] = node(program, 0).value2;
  assert.deepEqual(first.value0.node.value1, [TInt.value]);
  assert.deepEqual(second.value0.node.value1, [TBool.value]);
});

test('an undetermined type argument becomes a hole: length(Nil)', () => {
  const program = checkedPoly(prelude + 'fn length(xs: List(a)): Int = 0;'
    + ' fn main(): Int = length(Nil);');
  const call = node(program, 1);
  assert.deepEqual(call.value1, [hole(0)]);
  assert.deepEqual(call.value2[0].value0.node.value1, [hole(0)]);
  assert.deepEqual(call.value2[0].value0.ty, TData.create(0)([hole(0)])([]));
});

test('holes are numbered densely per function, first occurrence first',
  () => {
    const program = checkedPoly(prelude + 'fn f(x: a, y: b): Int = 0;'
      + ' fn g(): Int = f(Nothing, Nil); fn main(): Int = f(Nil, Proxy);');
    assert.deepEqual(node(program, 1).value1,
      [TData.create(2)([hole(0)])([]), TData.create(0)([hole(1)])([])]);
    assert.deepEqual(node(program, 2).value1,
      [TData.create(0)([hole(0)])([]), TData.create(3)([hole(1)])([])]);
  });

// Coverage of a constructor's fields at an applied type is Task 6, so the
// second arm is a wildcard, which coverage settles without the fields.
test('a pattern carries its instantiated type', () => {
  const program = checkedPoly(prelude + 'fn f(m: Maybe(Int)): Int ='
    + ' match m { Just(n) => n, _ => 0 };' + main);
  const [arm] = node(program, 0).value1;
  const pattern = arm.pattern.value0;
  assert.deepEqual(pattern.ty, TData.create(2)([TInt.value])([]));
  assert.deepEqual(pattern.shape.value1[0].value0.ty, TInt.value);
});
