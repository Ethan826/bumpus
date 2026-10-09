// FX001 Task 3: effect rows and scoped-label unification (design §2,
// Leijen 2005 §7). No syntax writes a row yet, so rows are built directly.
import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { Right } from '../output/Data.Either/index.js';
import { Just, Nothing } from '../output/Data.Maybe/index.js';
import { HeadData, labelKey } from '../output/Domain.Row/index.js';
import { typeHead } from '../output/Domain.Type.Parts/index.js';
import * as unifier from '../output/Features.Check.Unify/index.js';
import * as rows from '../output/Features.Check.UnifyRow/index.js';
import { generator } from './coverage-oracle.mjs';
import { canonicalRows, normalRow, oracleUnifyRows } from './row-oracle.mjs';
import {
  acyclic, anyPair, kind, label, resolveRow, row, rowMeta, scopedEqual,
  unifiablePair, unifyRows
} from './row-support.mjs';
import {
  bool, fromLabel, fromRow, fromTy, fun, int, list, meta, rigid, toLabel, toRow,
  toTy, unify
} from './unify-support.mjs';

const state = (n, arg) => label(n, arg);
const [clock, log, db] = [label(0), label(3), label(4)];
const solved = outcome => outcome.subst;

test('distinct keys commute; one key\'s entries keep their order', () => {
  assert.equal(kind(unifyRows(row([clock, log]), row([log, clock]))), 'Subst');
  const failure = unifyRows(row([state(1, int), state(1, bool)]),
    row([state(1, bool), state(1, int)])).failure;
  assert.deepEqual([failure.constructor.name, fromTy(failure.value0),
    fromTy(failure.value1)], ['Mismatch', int, bool]);
});

test('a label matches the first entry with its key, never a later one', () => {
  const outcome = unifyRows(row([state(1, meta(0))], rowMeta(10)),
    row([state(1, int), state(1, bool)]));
  assert.deepEqual(resolveRow(solved(outcome), row([state(1, meta(0))], rowMeta(10))),
    row([state(1, int), state(1, bool)]));
  for (const tail of [null, rowMeta(11)]) {
    const failure = unifyRows(row([state(1, bool)]), row([state(1, int), state(1, bool)], tail));
    assert.equal(kind(failure), 'Mismatch');
  }
});

test('Fail labels are keyed by their payload\'s type identity', () => {
  const key = l => labelKey(typeHead)(toLabel(l));
  const [ints, bools] = [key(label('fail', list(int))), key(label('fail', list(bool)))];
  assert.ok(ints instanceof Just && ints.value0.value0 instanceof HeadData);
  assert.deepEqual(ints, bools);
  assert.notDeepEqual(key(label('fail', int)), key(label('fail', bool)));
  assert.ok(key(label('fail', meta(0))) instanceof Nothing);
  assert.ok(key(label('fail', rigid(0))) instanceof Nothing);
  const payload = unifyRows(row([label('fail', list(int))]), row([label('fail', list(bool))]));
  assert.equal(kind(payload), 'Mismatch');
  // Deferred keys retain their row equality for later constraints.
  const deferred = unifyRows(row([label('fail', meta(0))]), row([label('fail', int)]));
  assert.equal(deferred.subst.postponed.length, 1);
  const known = unifyRows(row([label('fail', meta(0))]), row([label('fail', int)]),
    solved(unifyRows(row([state(1, meta(0))]), row([state(1, int)]))));
  assert.equal(kind(known), 'Subst');
});

// Without `tail(r1) ∉ dom(θ)` these pairs rewrite forever, so they run in
// a child process that a timeout kills: a label the right row lacks, and
// (after the left's labels) an entry the left row lacks.
const sideConditionTimeout = 20000;
let sideConditionHolds = false;
test('Clock + ...r against Log + ...r fails with RowSharedTail', () => {
  const support = new URL('./row-support.mjs', import.meta.url).href;
  const script = `const s = await import(${JSON.stringify(support)});
    const r = s.rowMeta(10);
    const shown = failure => [failure.constructor.name,
      s.fromRow(failure.value0), s.fromRow(failure.value1)];
    console.log(JSON.stringify([
      [s.row([s.label(0)], r), s.row([s.label(3)], r)],
      [s.row([], r), s.row([s.label(0)], r)]
    ].map(([left, right]) => shown(s.unifyRows(left, right).failure))));`;
  const child = spawnSync(process.execPath, ['--input-type=module', '-e', script],
    { encoding: 'utf8', timeout: sideConditionTimeout });
  assert.equal(child.signal, null, 'timed out: the side condition is missing');
  assert.equal(child.stderr, '');
  assert.deepEqual(JSON.parse(child.stdout), [
    ['RowSharedTail', row([clock], rowMeta(10)), row([log], rowMeta(10))],
    ['RowSharedTail', row([], rowMeta(10)), row([clock], rowMeta(10))]
  ]);
  sideConditionHolds = true;
});

test('missing, extra and mismatched tails are row failures', () => {
  const missing = unifyRows(row([db]), row([clock], rigid(5))).failure;
  assert.equal(missing.constructor.name, 'RowMissing');
  assert.deepEqual([fromLabel(missing.value0), fromRow(missing.value1)],
    [db, row([clock], rigid(5))]);
  assert.equal(kind(unifyRows(row([db]), row([]))), 'RowMissing');
  for (const tail of [null, rigid(5)]) {
    const extra = unifyRows(row([], tail), row([clock, db])).failure;
    assert.equal(extra.constructor.name, 'RowExtra');
    assert.deepEqual(fromLabel(extra.value0), clock);
  }
  for (const [left, right] of [[null, rigid(5)], [rigid(5), rigid(6)]]) {
    assert.equal(kind(unifyRows(row([], left), row([], right))), 'RowMismatch');
  }
  assert.equal(kind(unifyRows(row([clock], rigid(5)), row([clock], rigid(5)))), 'Subst');
});

const cases = 1500;
test('generated pairs: sound, symmetric, acyclic, and as the oracle decides', () => {
  const next = generator(0x2f1);
  // Shared tails are generated: without the side condition this loop
  // would not end, so it fails at once instead (tests run in order).
  assert.ok(sideConditionHolds, 'the side condition test failed');
  const seen = { succeeded: 0, failed: 0, shared: 0 };
  for (let index = 0; index < cases; index += 1) {
    const [left, right] = index % 2 === 0 ? unifiablePair(next, false) : anyPair(next, false);
    const context = JSON.stringify([left, right]);
    const outcome = unifyRows(left, right);
    const expected = oracleUnifyRows(left, right);
    if (index % 2 === 0) assert.equal(kind(outcome), 'Subst', context);
    assert.equal(outcome.subst !== undefined, expected !== null, context);
    assert.equal(kind(unifyRows(right, left)) === 'Subst', expected !== null, context);
    if (expected === null) {
      seen.failed += 1;
      if (kind(outcome) === 'RowSharedTail') seen.shared += 1;
      continue;
    }
    seen.succeeded += 1;
    assert.ok(acyclic(outcome.subst), context);
    const resolved = [left, right].map(side => resolveRow(outcome.subst, side));
    assert.ok(scopedEqual(resolved[0], resolved[1]), context);
    assert.deepEqual(canonicalRows(resolved.map(normalRow)),
      canonicalRows(expected.map(normalRow)), context);
  }
  assert.ok(seen.succeeded > cases / 4 && seen.failed > cases / 4 && seen.shared > 0,
    JSON.stringify(seen));
});

const many = 1000;
test('1,000-label rows unify and resolve without stack failure', () => {
  const labels = Array.from({ length: many }, (_, n) => label(n + 10, int));
  assert.equal(kind(unifyRows(row(labels), row(labels))), 'Subst');
  assert.equal(kind(unifyRows(row(labels), row([...labels].reverse()))), 'Subst');
  const open = row([], rowMeta(10));
  const extended = unifyRows(open, row(labels));
  assert.deepEqual(resolveRow(solved(extended), open), row(labels));
  const metas = row(labels.map((_, n) => label(n + 10, meta(0))), rowMeta(11));
  const together = unifyRows(metas, row([...labels].reverse(), rowMeta(12)));
  assert.deepEqual(resolveRow(solved(together), metas).labels.length, many);
  const arrow = fun(int, int);
  arrow.row = row(labels);
  assert.equal(unifier.exceedsLimit(unifier.empty)(toTy(arrow)), false);
});

test('an arrow\'s row unifies with its parameter and result', () => {
  const left = { ...fun(meta(0), int), row: row([clock], rowMeta(10)) };
  const right = { ...fun(bool, int), row: row([log, clock]) };
  const s = unifier.unify(unifier.empty)(toTy(left))(toTy(right));
  assert.ok(s instanceof Right);
  assert.deepEqual(fromTy(unifier.resolve(s.value0)(toTy(left))),
    { ...fun(bool, int), row: row([clock, log]) });
  const pure = unify(new Map(), fun(int, int), { ...fun(int, int), row: row([clock]) });
  assert.equal(pure.constructor.name, 'RowExtra');
  const inLabel = { ...fun(int, int), row: row([state(1, meta(0))]) };
  assert.equal(unify(new Map(), meta(0), inLabel).constructor.name, 'Occurs');
  const limit = unifier.inferredTypeLimit;
  const nest = depth => depth === 1 ? int : list(nest(depth - 1));
  const deep = depth => ({ ...fun(int, int), row: row([state(1, nest(depth))]) });
  assert.equal(unifier.exceedsLimit(unifier.empty)(toTy(deep(limit - 1))), false);
  assert.equal(unifier.exceedsLimit(unifier.empty)(toTy(deep(limit))), true);
});

test('traced unification reports matches and extensions by occurrence', () => {
  const at = n => ({ start: { line: 1, column: n, offset: n - 1 },
    end: { line: 1, column: n + 1, offset: n } });
  const sides = { left: at(1), right: at(9) };
  const traced = (start, left, right) => rows.unifyRowsTraced(unifier.unify)(sides)(start)(
    toRow(left))(toRow(right)).value0;
  const show = event => event.constructor.name === 'Matched'
    ? ['Matched', occurrence(event.value0), occurrence(event.value1)]
    : ['Extended', event.value0, occurrence(event.value1)];
  const occurrence = id => id.constructor.name === 'Written'
    ? ['Written', id.value0.start.column, id.value1] : ['Extended', id.value0];
  const first = traced(unifier.empty, row([clock, log]), row([log], rowMeta(10)));
  assert.deepEqual(first.events.map(show), [
    ['Extended', 10, ['Written', 1, 0]],
    ['Matched', ['Written', 1, 1], ['Written', 9, 0]]
  ]);
  const second = traced(first.subst, row([clock]), row([], rowMeta(10)));
  assert.deepEqual(second.events.map(show), [['Matched', ['Written', 1, 0], ['Extended', 10]]]);
});
