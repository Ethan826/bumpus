// Preserve the original solved laws in unify-row.test; broaden the domain
// here so pending acceptance can never masquerade as solved row equality.
import test from 'node:test';
import assert from 'node:assert/strict';
import { Right } from '../output/Data.Either/index.js';
import * as unifier from '../output/Features.Check.Unify/index.js';
import { generator } from './coverage-oracle.mjs';
import { applyRow, canonicalRows, normalRow, oracleAttempt, oracleSettle } from './row-oracle.mjs';
import { acyclic, anyPair, label, resolveRow, row, scopedEqual, startingSubst,
  unifiablePair, unifyRows } from './row-support.mjs';
import { bindingsOf, bool, int, list, meta, rowBindingsOf, toTy } from './unify-support.mjs';

const fail = type => label('fail', type);
const compare = (outcome, expected, sides, context, seen) => {
  assert.equal(outcome.subst !== undefined, expected !== null, context);
  if (expected === null) { seen.failed += 1; return; }
  assert.ok(acyclic(outcome.subst), context);
  const pending = outcome.subst.postponed.length;
  assert.equal(pending, expected.state.pending.length, context);
  if (pending > 0) { seen.pending += 1; return; }
  seen.solved += 1;
  const resolved = sides.map(side => resolveRow(outcome.subst, side));
  assert.ok(scopedEqual(...resolved), context);
  assert.deepEqual(canonicalRows(resolved.map(normalRow)),
    canonicalRows(expected.rows.map(normalRow)), context);
};

test('generated deferred rows agree with the independent transactional oracle', () => {
  const next = generator(0x2f2);
  const seen = { solved: 0, failed: 0, pending: 0, seeded: 0, settled: 0 };
  for (let index = 0; index < 2000; index += 1) {
    const pair = index % 2 === 0 ? unifiablePair(next) : anyPair(next);
    const initial = index % 3 === 0 ? startingSubst(next)
      : { subst: unifier.empty, seed: {} };
    if (index % 3 === 0) seen.seeded += 1;
    for (const sides of [pair, [...pair].reverse()]) {
      const context = JSON.stringify({ sides, seed: [...(initial.seed.types ?? [])] });
      const expected = oracleAttempt(...sides, initial.seed);
      const outcome = unifyRows(...sides, initial.subst);
      compare(outcome, expected, sides, context, seen);
      if (!outcome.subst) continue;
      // Solving a body constraint may settle, contradict or leave pending
      // the original pair; compare all three outcomes independently.
      const assignment = index % 2 === 0 ? int : list(bool);
      const ordinary = unifier.unify(outcome.subst)(toTy(meta(1)))(toTy(assignment));
      const reference = oracleSettle(expected.state, new Map([[1, assignment]]));
      const result = ordinary instanceof Right ? unifier.settleRows(ordinary.value0) : ordinary;
      assert.equal(result instanceof Right, reference !== null, context);
      if (!(result instanceof Right)) continue;
      seen.settled += 1;
      compare({ subst: result.value0 }, { state: reference,
        rows: sides.map(side => applyRow(reference, side)) }, sides, context, seen);
    }
  }
  assert.ok(seen.pending > 100 && seen.failed > 100 && seen.solved > 100
    && seen.seeded > 100 && seen.settled > 100, JSON.stringify(seen));
});

test('oracle postpones with rollback and independently settles or rejects', () => {
  const left = row([label(1, meta(1)), fail(meta(0))]);
  const right = row([label(1, int), fail(int)]);
  const seed = { types: new Map([[2, bool]]) };
  const attempt = oracleAttempt(left, right, seed);
  assert.deepEqual(attempt.state.types, seed.types);
  assert.equal(attempt.state.pending.length, 1);
  const unknown = oracleSettle(attempt.state);
  assert.equal(unknown.pending.length, 1);
  const solution = oracleSettle(attempt.state, new Map([[0, int]]));
  assert.equal(solution.pending.length, 0);
  assert.deepEqual(applyRow(solution, left), right);
  assert.equal(oracleSettle(attempt.state, new Map([[0, bool]])), null);
  assert.deepEqual(seed.types, new Map([[2, bool]]));
  const subst = unifyRows(left, right).subst;
  assert.deepEqual(bindingsOf(subst), new Map());
  assert.deepEqual(rowBindingsOf(subst), new Map());
});
