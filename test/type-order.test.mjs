// FN001 Task 2: Ty's hand-written Eq and Ord walk an arrow's result spine
// in a loop, and keep the derived order of every arrow-free type; arrow
// type names render right-associatively, also by a loop.
import test from 'node:test';
import assert from 'node:assert/strict';
import { eqInt } from '../output/Data.Eq/index.js';
import { ordInt } from '../output/Data.Ord/index.js';
import { Just } from '../output/Data.Maybe/index.js';
import { closedRow } from '../output/Domain.Row/index.js';
import { TBool, TData, TFun, TInt, TVar, eqTy, ordTy } from '../output/Domain.Type/index.js';
import { ground } from '../output/Domain.Type.Parts/index.js';
import * as problem from '../output/Domain.Problem/index.js';
import { wire } from '../output/Format.Diagnostic/index.js';
import { eqFlex } from '../output/Features.Check.Subst/index.js';
import * as unifier from '../output/Features.Check.Unify/index.js';
import { choose, generator } from './coverage-oracle.mjs';

const eq = eqTy(eqInt).eq;
const compare = ordTy(ordInt).compare;
const ordering = (left, right) => compare(left)(right).constructor.name;
const longSpine = 20000;

// `parameters` copies of TInt, then `last`, then the result, by a loop.
const longArrow = (parameters, last, result) => {
  let built = TFun.create(last)(closedRow)(result);
  for (let index = 0; index < parameters; index += 1) built = TFun.create(TInt.value)(closedRow)(built);
  return built;
};

test('equality and order on 20,000-long spines need no deep recursion', () => {
  const one = longArrow(longSpine, TInt.value, TBool.value);
  const same = longArrow(longSpine, TInt.value, TBool.value);
  const differs = longArrow(longSpine, TBool.value, TBool.value);
  assert.equal(eq(one)(same), true);
  assert.equal(ordering(one, same), 'EQ');
  assert.equal(eq(one)(differs), false);
  assert.equal(ordering(one, differs), 'LT');
  assert.equal(ordering(differs, one), 'GT');
  assert.equal(ordering(one, longArrow(longSpine, TInt.value, TInt.value)), 'GT');
  assert.equal(ordering(TFun.create(TInt.value)(closedRow)(TInt.value), one), 'LT');
});

test('substitution and grounding walk a 20,000-long spine by a loop', () => {
  const one = longArrow(longSpine, TInt.value, TBool.value);
  const substituted = unifier.substitute(unifier.empty)(one);
  assert.ok(eqTy(eqFlex).eq(substituted)(one));
  const grounded = ground(one);
  assert.ok(grounded instanceof Just);
  assert.equal(eq(grounded.value0)(one), true);
});

// The derived instance's order: constructors in declaration order, then
// fields left to right; arrays lexicographically, a proper prefix first.
const rank = ['TInt', 'TBool', 'TData', 'TVar'];
const sign = number => Math.sign(number);
const derived = (left, right) => {
  const [l, r] = [left.constructor.name, right.constructor.name];
  if (l !== r) return sign(rank.indexOf(l) - rank.indexOf(r));
  if (l === 'TVar') return sign(left.value0 - right.value0);
  if (l !== 'TData') return 0;
  if (left.value0 !== right.value0) return sign(left.value0 - right.value0);
  const [a, b] = [left.value1, right.value1];
  for (let index = 0; index < Math.min(a.length, b.length); index += 1) {
    const found = derived(a[index], b[index]);
    if (found !== 0) return found;
  }
  return sign(a.length - b.length);
};

// Small alphabets so that equal types and shared prefixes are common.
const arrowFree = (next, depth) => {
  const shape = depth === 0 ? choose(next, 3) : choose(next, 4);
  if (shape === 0) return TInt.value;
  if (shape === 1) return TBool.value;
  if (shape === 2) return TVar.create(choose(next, 2));
  const count = choose(next, 3);
  return TData.create(choose(next, 2))(Array.from({ length: count },
    () => arrowFree(next, depth - 1)))([]);
};
const generatedPairs = 2000;
const maximumDepth = 3;
const names = { [-1]: 'LT', 0: 'EQ', 1: 'GT' };

test('order and equality agree with the derived instances on arrow-free types', () => {
  const next = generator(0x0d3);
  const seen = { LT: 0, EQ: 0, GT: 0 };
  for (let index = 0; index < generatedPairs; index += 1) {
    const [left, right] = [arrowFree(next, maximumDepth), arrowFree(next, maximumDepth)];
    const expected = names[derived(left, right)];
    assert.equal(ordering(left, right), expected);
    assert.equal(eq(left)(right), expected === 'EQ');
    seen[expected] += 1;
  }
  assert.ok(Object.values(seen).every(count => count > generatedPairs / 10),
    JSON.stringify(seen));
});

const span = { start: { line: 1, column: 1, offset: 0 }, end: { line: 1, column: 2, offset: 1 } };
const name = { int: problem.IntName.value };
const arrow = (parameter, result) => problem.FunctionName.create(parameter)(result);
const listOf = argument => problem.AppliedName.create('List')([argument]);

test('arrow type names are right-associative, function parameters parenthesized', () => {
  const map = arrow(arrow(name.int, name.int),
    arrow(listOf(name.int), listOf(name.int)));
  assert.deepEqual(wire({ problem: problem.TypeMismatch.create(map)(name.int), span, related: [] }), {
    code: 'E_TYPE', span, related: [],
    message: 'Expected (Int -> Int) -> List(Int) -> List(Int), found Int'
  });
  const returned = arrow(name.int, arrow(name.int, name.int));
  const nestedResult = listOf(arrow(name.int, name.int));
  assert.equal(wire({ problem: problem.NotComparable.create(returned), span, related: [] }).message,
    'Type Int -> Int -> Int is not comparable');
  assert.equal(wire({ problem: problem.AmbiguousType.create(nestedResult), span, related: [] }).message,
    'Ambiguous type List(Int -> Int) in comparison');
});

test('a 20,000-long arrow type name renders without deep recursion', () => {
  let built = name.int;
  for (let index = 0; index < longSpine; index += 1) built = arrow(name.int, built);
  const text = wire({ problem: problem.NotComparable.create(built), span, related: [] }).message;
  assert.equal(text, `Type ${'Int -> '.repeat(longSpine)}Int is not comparable`);
});
