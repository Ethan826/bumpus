// FN001 Task 2: the arrow type in unification (design §1 measure, §3).
// No syntax produces an arrow yet, so these tests build arrows directly.
import test from 'node:test';
import assert from 'node:assert/strict';
import { Right } from '../output/Data.Either/index.js';
import { eqTy } from '../output/Domain.Type/index.js';
import * as unifier from '../output/Features.Check.Unify/index.js';
import {
  bool, fromTy, fun, int, list, meta, pair, resolve, rigid, spine, substOf,
  toTy, unify
} from './unify-support.mjs';

const kind = failure => failure.constructor.name;
const pairOf = failure => [kind(failure), fromTy(failure.value0), fromTy(failure.value1)];
const eqFlex = eqTy(unifier.eqFlex);
const limit = unifier.inferredTypeLimit;
const longSpine = 5000;

test('arrows unify parameter with parameter and result with result', () => {
  const s = unify(new Map(), fun(meta(0), int), fun(bool, meta(1)));
  assert.deepEqual([resolve(s, meta(0)), resolve(s, meta(1))], [bool, int]);
  const curried = unify(new Map(), fun(int, meta(0)), spine([int, bool], list(int)));
  assert.deepEqual(resolve(curried, meta(0)), fun(bool, list(int)));
});

test('a mismatch names the first differing subterms, left to right', () => {
  assert.deepEqual(pairOf(unify(new Map(), fun(int, int), fun(bool, int))),
    ['Mismatch', int, bool]);
  assert.deepEqual(pairOf(unify(new Map(), fun(int, int), fun(int, bool))),
    ['Mismatch', int, bool]);
  assert.deepEqual(pairOf(unify(new Map(), fun(list(int), bool), fun(list(bool), int))),
    ['Mismatch', int, bool]);
  assert.deepEqual(pairOf(unify(new Map(), fun(int, int), list(int))),
    ['Mismatch', fun(int, int), list(int)]);
  assert.deepEqual(pairOf(unify(new Map(), pair(int, fun(int, int)), pair(int, int))),
    ['Mismatch', fun(int, int), int]);
});

test('a meta binds to an arrow; an arrow containing it is infinite', () => {
  const arrow = fun(int, rigid(0));
  assert.deepEqual(resolve(unify(new Map(), meta(0), arrow), meta(0)), arrow);
  assert.deepEqual(resolve(unify(new Map(), arrow, meta(0)), meta(0)), arrow);
  for (const whole of [fun(meta(0), int), fun(int, meta(0)), fun(int, list(meta(0)))]) {
    const failure = unify(new Map(), meta(0), whole);
    assert.equal(kind(failure), 'Occurs');
    assert.deepEqual([failure.value0, fromTy(failure.value1)], [0, whole]);
  }
  const through = unify(new Map([[1, fun(int, meta(0))]]), meta(0), fun(bool, meta(1)));
  assert.equal(kind(through), 'Occurs');
});

test('a rigid variable does not unify with an arrow', () => {
  assert.deepEqual(pairOf(unify(new Map(), rigid(0), fun(rigid(0), int))),
    ['Mismatch', rigid(0), fun(rigid(0), int)]);
  assert.deepEqual(pairOf(unify(new Map(), fun(int, int), rigid(1))),
    ['Mismatch', fun(int, int), rigid(1)]);
});

const range = length => Array.from({ length }, (_, n) => n);

test('a 5,000-long spine unifies and resolves without stack failure', () => {
  const metas = spine(range(longSpine).map(meta), meta(longSpine));
  const ground = spine(range(longSpine).map(() => int), bool);
  const solved = unifier.unify(unifier.empty)(toTy(metas))(toTy(ground));
  assert.ok(solved instanceof Right);
  const resolved = unifier.resolve(solved.value0)(toTy(metas));
  assert.ok(eqFlex.eq(resolved)(toTy(ground)));
  const last = spine(range(longSpine).map(() => int), int);
  const failure = unifier.unify(solved.value0)(toTy(metas))(toTy(last)).value0;
  assert.deepEqual(pairOf(failure), ['Mismatch', bool, int]);
});

// Design §1: an arrow's parameter side is one level deeper, its result side
// is not, so a spine of any length is one level.
const parameterNest = depth => depth === 1 ? int : fun(parameterNest(depth - 1), int);
const listNest = (depth, leaf) => depth === 1 ? leaf : list(listNest(depth - 1, leaf));

test('parameter nesting counts toward the inferred type limit; spines do not', () => {
  const within = parameterNest(limit);
  const beyond = parameterNest(limit + 1);
  assert.deepEqual(unify(new Map(), within, within), new Map());
  assert.equal(kind(unify(new Map(), beyond, beyond)), 'TooDeep');
  assert.equal(unifier.exceedsLimit(unifier.empty)(toTy(within)), false);
  assert.equal(unifier.exceedsLimit(unifier.empty)(toTy(beyond)), true);
  const longWithin = spine(range(longSpine).map(() => int), listNest(limit, int));
  const longBeyond = spine(range(longSpine).map(() => int), listNest(limit + 1, int));
  assert.equal(unifier.exceedsLimit(unifier.empty)(toTy(longWithin)), false);
  assert.equal(unifier.exceedsLimit(unifier.empty)(toTy(longBeyond)), true);
  const within2 = unifier.unify(unifier.empty)(toTy(longWithin))(toTy(longWithin));
  assert.ok(within2 instanceof Right);
  const beyond2 = unifier.unify(unifier.empty)(toTy(longBeyond))(toTy(longBeyond));
  assert.equal(kind(beyond2.value0), 'TooDeep');
});

test('a meta bound to deep parameter nesting counts at its own position', () => {
  // Compared by Ty's own Eq: assert.deepEqual recurses too deeply here.
  const deeper = substOf(new Map([[0, parameterNest(limit)]]));
  const same = unifier.unify(deeper)(toTy(meta(0)))(toTy(parameterNest(limit)));
  assert.ok(same instanceof Right);
  assert.ok(eqFlex.eq(unifier.resolve(same.value0)(toTy(meta(0))))(toTy(parameterNest(limit))));
  assert.equal(unifier.exceedsLimit(deeper)(toTy(fun(int, meta(0)))), false);
  assert.equal(unifier.exceedsLimit(deeper)(toTy(fun(meta(0), int))), true);
});
