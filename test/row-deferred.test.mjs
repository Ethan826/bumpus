// Deferred Fail keys must preserve the entire row constraint until the
// body's ordinary type constraints identify the error family.
import test from 'node:test';
import assert from 'node:assert/strict';
import { Right } from '../output/Data.Either/index.js';
import { Just, Nothing } from '../output/Data.Maybe/index.js';
import { ground, groundErased } from '../output/Domain.Type.Parts/index.js';
import * as unifier from '../output/Features.Check.Unify/index.js';
import * as rows from '../output/Features.Check.UnifyRow/index.js';
import { label, row, rowMeta, resolveRow, unifyRows } from './row-support.mjs';
import { bindingsOf, bool, fromRow, fromTy, fun, int, list, meta,
  rowBindingsOf, substOf, toRow, toTy } from './unify-support.mjs';

const fail = type => label('fail', type);
const pending = result => {
  assert.ok(result.subst, result.failure?.constructor.name);
  assert.equal(result.subst.postponed.length, 1);
  return result.subst;
};
const bind = (subst, type) => {
  const result = unifier.unify(subst)(toTy(meta(0)))(toTy(type));
  assert.ok(result instanceof Right);
  return result.value0;
};
const settled = subst => {
  const result = unifier.settleRows(subst);
  assert.ok(result instanceof Right, result.value0?.constructor.name);
  assert.equal(result.value0.postponed.length, 0);
  return result.value0;
};

test('deferred Fail is reflexive with closed and open tails', () => {
  for (const tail of [null, rowMeta(10)]) {
    const same = row([fail(meta(0))], tail);
    const subst = pending(unifyRows(same, same));
    assert.deepEqual(subst.postponed.map(pair => [fromRow(pair.left), fromRow(pair.right)]),
      [[same, same]]);
    assert.deepEqual(bindingsOf(subst), new Map());
    assert.deepEqual(rowBindingsOf(subst), new Map());
  }
});

test('deferred Fail settles without creating a duplicate', () => {
  const left = row([fail(meta(0))], rowMeta(10));
  const right = row([fail(int)], rowMeta(11));
  const subst = pending(unifyRows(left, right));
  assert.deepEqual(rowBindingsOf(subst), new Map());
  const solution = settled(bind(subst, int));
  assert.deepEqual(resolveRow(solution, left).labels, [fail(int)]);
  assert.deepEqual(resolveRow(solution, right).labels, [fail(int)]);
  assert.deepEqual(resolveRow(solution, left), resolveRow(solution, right));
});

test('a closed deferred right entry postpones before matching or rejecting', () => {
  pending(unifyRows(row([fail(int)]), row([fail(meta(0))])));
  const left = row([fail(list(int))], rowMeta(10));
  const right = row([fail(meta(0)), fail(list(int))]);
  const subst = pending(unifyRows(left, right));
  assert.deepEqual(rowBindingsOf(subst), new Map());
  assert.equal(unifier.settleRows(bind(subst, list(bool))).constructor.name, 'Left');
});

test('a left-over deferred right entry also postpones', () => {
  for (const tail of [null, rowMeta(10)]) {
    pending(unifyRows(row([], tail), row([fail(meta(0))])));
  }
});

test('postponement rolls back earlier type bindings, extensions and events', () => {
  const start = substOf(new Map([[2, bool]]));
  const left = row([label(1, meta(1)), label(2), fail(meta(0))], rowMeta(10));
  const right = row([label(1, int)], rowMeta(11));
  const result = rows.unifyRowsTraced(unifier.unify)(rows.untraced)(start)(
    toRow(left))(toRow(right));
  assert.ok(result instanceof Right);
  assert.equal(result.value0.postponed, true);
  assert.deepEqual(result.value0.events, []);
  const subst = pending({ subst: result.value0.subst });
  assert.deepEqual(bindingsOf(subst), new Map([[2, bool]]));
  assert.deepEqual(rowBindingsOf(subst), new Map());
  assert.equal(subst.fresh, start.fresh);
});

test('settleRows distinguishes a solved pair, mismatch and still unknown key', () => {
  const left = row([fail(meta(0))]);
  const right = row([fail(int)]);
  const subst = pending(unifyRows(left, right));
  assert.deepEqual(resolveRow(settled(bind(subst, int)), left), right);
  const mismatch = unifier.settleRows(bind(subst, bool));
  assert.equal(mismatch.constructor.name, 'Left');
  assert.equal(mismatch.value0.constructor.name, 'RowMissing');
  const unknown = unifier.settleRows(subst);
  assert.ok(unknown instanceof Right);
  assert.deepEqual(unknown.value0, subst);
});

test('settleRows retries an earlier pair after a later pair solves its key', () => {
  const first = pending(unifyRows(row([fail(meta(0))]), row([fail(int)])));
  const second = pending(unifyRows(row([label(1, meta(0)), fail(meta(1))]),
    row([label(1, int), fail(bool)])));
  const combined = { ...first, postponed: [...first.postponed, ...second.postponed] };
  const result = unifier.unify(combined)(toTy(meta(1)))(toTy(bool));
  assert.ok(result instanceof Right);
  const solution = settled(result.value0);
  assert.deepEqual(bindingsOf(solution), new Map([[0, int], [1, bool]]));
});

test('surrounding arrow parameters and results continue while a row postpones', () => {
  const left = { ...fun(meta(1), meta(2)), row: row([fail(meta(0))]) };
  const right = { ...fun(bool, int), row: row([fail(int)]) };
  const result = unifier.unify(unifier.empty)(toTy(left))(toTy(right));
  assert.ok(result instanceof Right);
  const subst = pending({ subst: result.value0 });
  assert.deepEqual(bindingsOf(subst), new Map([[1, bool], [2, int]]));
  assert.deepEqual(fromTy(unifier.resolve(subst)(toTy(left))),
    { ...fun(bool, int), row: row([fail(meta(0))]) });
});

test('groundErased erases open rows while strict ground rejects them', () => {
  const effectOnly = { ...fun(int, int), row: row([fail(meta(0))], rowMeta(10)) };
  assert.ok(ground(toTy(effectOnly)) instanceof Nothing);
  const result = groundErased(toTy(effectOnly));
  assert.ok(result instanceof Just);
  assert.deepEqual(fromTy(result.value0), fun(int, int));
  assert.ok(groundErased(toTy({ ...effectOnly, args: [meta(1), int] })) instanceof Nothing);
  const applied = { k: 'data', id: 0, args: [int], rows: [row([], rowMeta(10))] };
  assert.ok(ground(toTy(applied)) instanceof Nothing);
  assert.deepEqual(fromTy(groundErased(toTy(applied)).value0),
    { ...applied, rows: [row([])] });
});

test('extending a row rejects an arrow argument containing that same row', () => {
  const recursive = { ...fun(int, int), row: row([], rowMeta(10)) };
  const outcome = unifyRows(row([label(1, recursive)]), row([], rowMeta(10)));
  assert.equal(outcome.failure?.constructor.name, 'RowOccurs');
});
