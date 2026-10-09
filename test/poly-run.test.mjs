import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { Right } from '../output/Data.Either/index.js';
import { TBool, TData, TInt } from '../output/Domain.Type/index.js';
import { specializationKeys } from '../output/Features.Specialize/index.js';
import { checked, rejectedAt } from './support.mjs';
import { checkedPoly } from './phases.mjs';
import { runGoBatch } from './go-batch.mjs';

// P001 Task 7: polymorphic programs compile through the whole pipeline
// (Specialize included) and run. Every execution here is one Go batch.
const lists = readFileSync('examples/lists.bumpus', 'utf8');
const library = lists.slice(0, lists.indexOf('fn main()'));
const withMain = (result, body) => `${library}fn main(): ${result} = ${body};`;
const xs = 'Cons(1, Cons(2, Cons(3, Nil)))';
const boolTree = 'Node(Node(Node(Leaf, true, Leaf), false, Leaf), true,'
  + ' Node(Leaf, false, Leaf))';
const doubled = Array.from({ length: 13 }).reduce(inner => `double(${inner})`,
  'Cons(1, Nil)');
const zipped = 'Cons(Pair(1, true), Nil)';

// [name, source, printed output]
const runs = [
  ['lists', lists, 'Pair(Cons(Pair(3, true), Cons(Pair(2, false), Nil)),'
    + ' Just(6))'],
  ['length', withMain('Int', `length(${xs})`), '3'],
  ['append', withMain('List(Int)', 'append(Cons(1, Nil), Cons(2, Cons(3,'
    + ' Nil)))'), 'Cons(1, Cons(2, Cons(3, Nil)))'],
  ['reverse', withMain('List(Bool)', 'reverse(Cons(true, Cons(false, Nil)))'),
    'Cons(false, Cons(true, Nil))'],
  ['zip', withMain('List(Pair(Int, Maybe(Bool)))',
    'zip(Cons(1, Cons(2, Nil)), Cons(Just(true), Nil))'),
  'Cons(Pair(1, Just(true)), Nil)'],
  ['headOr', withMain('Pair(Int, Bool)',
    'Pair(headOr(Nil, 7), headOr(Cons(false, Nil), true))'), 'Pair(7, false)'],
  ['last', withMain('Pair(Maybe(Int), Maybe(Bool))',
    'Pair(last(Cons(1, Cons(2, Nil))), last(Nil))'), 'Pair(Just(2), Nothing)'],
  ['take', withMain('List(Int)', `take(2, ${xs})`), 'Cons(1, Cons(2, Nil))'],
  ['drop', withMain('Pair(List(Int), List(Int))',
    `Pair(drop(2, ${xs}), drop(5, ${xs}))`), 'Pair(Cons(3, Nil), Nil)'],
  ['fromMaybe', withMain('Int', 'fromMaybe(Nothing, 4) + fromMaybe(Just(5), 0)'),
    '9'],
  ['fstSnd', withMain('Pair(Int, Bool)',
    'Pair(fst(Pair(1, true)), snd(Pair(1, true)))'), 'Pair(1, true)'],
  ['swap', withMain('Pair(List(Bool), Int)', 'swap(Pair(1, Cons(true, Nil)))'),
    'Pair(Cons(true, Nil), 1)'],
  ['sizeDepth', withMain('Pair(Int, Int)',
    `Pair(size(${boolTree}), depth(${boolTree}))`), 'Pair(4, 3)'],
  ['flatten', withMain('List(Int)',
    'flatten(Node(Node(Leaf, 1, Leaf), 2, Node(Leaf, 3, Leaf)))'),
  'Cons(1, Cons(2, Cons(3, Nil)))'],
  ['leftOr', withMain('Pair(Int, Int)',
    'Pair(leftOr(Left(1), 0), leftOr(Right(true), 9))'), 'Pair(1, 9)'],
  // Review Focus 1–5 (plan).
  ['namespaces', 'fn a(a: a): a = a; fn main(): Int = a(5);', '5'],
  ['contextOnly', 'fn loop(): a = loop();'
    + ' fn main(): Int = if true then 1 else loop();', '1'],
  ['zipPrinted', withMain('List(Pair(Int, Bool))',
    'zip(Cons(1, Nil), Cons(true, Nil))'), zipped],
  ['zipReread', withMain('List(Pair(Int, Bool))', zipped), zipped],
  ['deepList', `${library}fn double(xs: List(a)): List(a) = append(xs, xs);`
    + ` fn main(): Int = length(${doubled});`, '8192'],
  ['groundCompare', `${library}fn f(x: a, xs: List(Int)): Bool =`
    + ' xs < Cons(2, Nil); fn main(): Bool = f(true, Cons(1, Nil));', 'true'],
  ['twoInstantiations', withMain('Pair(Int, Int)',
    'Pair(length(Cons(1, Nil)), length(Cons(true, Cons(false, Nil))))'),
  'Pair(1, 2)'],
  ['lengthNil', withMain('Int', 'length(Nil)'), '0']
];
const batch = runGoBatch(import.meta.url,
  runs.map(([name, source]) => [name, source]));

for (const [name, , printed] of runs) {
  test(`polymorphic program runs: ${name}`, () => {
    assert.equal(batch.run(name), `${printed}\n`);
  });
}

const keysOf = source => {
  const result = specializationKeys(checkedPoly(source));
  assert.ok(result instanceof Right, JSON.stringify(result));
  return result.value0;
};
const listOf = argument => TData.create(0)([argument])([]);
const typeKey = (declaration, args) =>
  ({ declaration, function: false, arguments: args });
const functionKey = (declaration, args) =>
  ({ declaration, function: true, arguments: args });

// List is type 0, length function 0 and main function 1 in `library`.
test('length(Nil) shares the length key at Int', () => {
  const keys = keysOf(withMain('Int', 'length(Nil) + length(Cons(1, Nil))'));
  const lengths = keys.filter(key => key.function && key.declaration === 0);
  assert.deepEqual(lengths, [functionKey(0, [TInt.value])]);
});

// Types, then functions, each in output-id order: monomorphic seeds first,
// then keys in pre-order discovery order (a call's instantiation before its
// callee, the callee before its arguments).
test('keys are numbered in worklist discovery order', () => {
  const source = 'type List(a) = Nil | Cons(a, List(a));'
    + ' fn length(xs: List(a)): Int = match xs { Nil => 0,'
    + ' Cons(_, rest) => 1 + length(rest) };'
    + ' fn main(): Int = length(Cons(true, Nil))'
    + ' + length(Cons(Cons(1, Nil), Nil));';
  assert.deepEqual(keysOf(source), [
    typeKey(0, [TBool.value]), typeKey(0, [TInt.value]),
    typeKey(0, [listOf(TInt.value)]), functionKey(1, []),
    functionKey(0, [TBool.value]), functionKey(0, [listOf(TInt.value)])
  ]);
});

test('a polymorphic declaration never instantiated is not emitted', () => {
  const source = 'type Box(a) = Box(a); fn id(x: a): a = x;'
    + ' fn main(): Int = 0;';
  assert.deepEqual(keysOf(source), [functionKey(1, [])]);
  const go = checked(source);
  assert.ok(!go.includes('bumpusFn1'), 'id was emitted');
  assert.ok(!go.includes('bumpusTy0'), 'Box was emitted');
});

// The limit counts only keys of polymorphic declarations (global
// constraints): 6,000 function keys and 4,000 type keys reach it exactly;
// 500 monomorphic functions and 500 monomorphic types do not count.
const functionKeys = 6000;
const typeKeys = 4000;
const monomorphic = 500;
const callsPer = functionKeys / monomorphic;
const buildsPer = typeKeys / monomorphic;
const range = (count, from = 0) =>
  Array.from({ length: count }, (_, index) => from + index);
const call = index => `g${index}(1)`;
const build = index => `(match Q${index}(1) { Q${index}(v) => v })`;
const user = index => `fn u${index}(): Int = ${[
  ...range(callsPer, index * callsPer).map(call),
  ...range(buildsPer, index * buildsPer).map(build)].join(' + ')};`;
const atLimit = [
  ...range(typeKeys).map(index => `type P${index}(a) = Q${index}(a);`),
  ...range(monomorphic).map(index => `type M${index} = N${index};`),
  ...range(functionKeys).map(index => `fn g${index}(x: a): a = x;`),
  ...range(monomorphic).map(user), 'fn main(): Int = 0;'].join(' ');

test('ten thousand polymorphic keys compile; one more of each kind fails', () => {
  assert.match(checked(atLimit), /func main\(\)/);
  const message = 'More than 10000 specializations';
  const overByFunction = `${atLimit} fn gx(x: a): a = x;`
    + ' fn extra(): Int = gx(1);';
  assert.equal(rejectedAt(overByFunction, 'E_SPECIALIZATION', 'gx(1)').message,
    message);
  const overByType = `${atLimit} type PX(a) = QX(a);`
    + ' fn extra(): Int = match QX(1) { QX(v) => v };';
  assert.equal(rejectedAt(overByType, 'E_SPECIALIZATION', 'QX(1)').message,
    message);
});
