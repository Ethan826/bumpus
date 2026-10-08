import test from 'node:test';
import assert from 'node:assert/strict';
import * as problem from '../output/Domain.Problem/index.js';
import { wire } from '../output/Format.Diagnostic/index.js';
import * as unifier from '../output/Features.Check.Unify/index.js';
import { choose, generator } from './coverage-oracle.mjs';
import { canonical, oracleUnify } from './unify-oracle.mjs';
import {
  bindingsOf, bool, fromTy, fun, int, list, meta, pair, resolve, rigid,
  substOf, substitute, toTy, unify
} from './unify-support.mjs';

const cases = 500;
const metaCount = 4;

// Reference readings of the brief's definitions, over plain types.
// Data types and arrows both carry their parts in `args`.
const mapType = (t, leaf) => t.args
  ? { ...t, args: t.args.map(arg => mapType(arg, leaf)) } : leaf(t);
const once = (s, t) => mapType(t, v => v.k === 'meta' && s.has(v.n) ? s.get(v.n) : v);
const metasOf = t => t.args ? t.args.flatMap(metasOf) : t.k === 'meta' ? [t.n] : [];
const acyclic = s => {
  const reaches = (from, seen) => metasOf(s.get(from) ?? int).some(n =>
    seen.has(n) || reaches(n, new Set([...seen, n])));
  return [...s.keys()].every(n => !reaches(n, new Set([n])));
};

const leafType = (next, metas) => {
  const leaves = [int, bool, rigid(0), rigid(1), ...metas.map(meta)];
  return leaves[choose(next, leaves.length)];
};
const genType = (next, depth, metas = [0, 1, 2, 3]) => {
  const shape = depth === 0 ? 0 : choose(next, 4);
  if (shape === 0) return leafType(next, metas);
  if (shape === 1) return list(genType(next, depth - 1, metas));
  const two = shape === 2 ? pair : fun;
  return two(genType(next, depth - 1, metas), genType(next, depth - 1, metas));
};
const maximumDepth = 4;
// Each meta's binding is drawn before deciding whether to keep it: drawing
// the decision first correlates with the next draw (an LCG) and never left
// a bare variable as a binding, which hid meta-to-meta chains.
const genSubst = (next, bindsOnly = () => [0, 1, 2, 3]) => new Map(
  [0, 1, 2, 3].map(n => [n, genType(next, 2, bindsOnly(n))])
    .filter(() => choose(next, 2) === 0));
const above = n => [0, 1, 2, 3].filter(m => m > n);

// Replace some subterms of a meta-free type by metas, recording in sigma the
// subterm each meta stands for, so sigma(result) is the original type.
const abstracted = (next, t, sigma) => {
  if (choose(next, 3) === 0) {
    const known = [...sigma].find(([, image]) =>
      JSON.stringify(image) === JSON.stringify(t));
    if (known) return meta(known[0]);
    if (sigma.size < metaCount) { sigma.set(sigma.size, t); return meta(sigma.size - 1); }
  }
  return t.args ? { ...t, args: t.args.map(arg => abstracted(next, arg, sigma)) } : t;
};
const sigmaPair = next => {
  const ground = genType(next, maximumDepth, []);
  const sigma = new Map();
  return { sigma, ground, left: abstracted(next, ground, sigma), right: abstracted(next, ground, sigma) };
};

test('rigid variables unify only with themselves', () => {
  assert.equal(unify(new Map(), rigid(0), int).constructor.name, 'Mismatch');
  assert.equal(unify(new Map(), rigid(0), rigid(1)).constructor.name, 'Mismatch');
  assert.deepEqual(unify(new Map(), rigid(0), rigid(0)), new Map());
});

test('isEmpty holds exactly until a meta is bound', () => {
  assert.equal(unifier.isEmpty(unifier.empty), true);
  const bound = unifier.unify(unifier.empty)(toTy(meta(0)))(toTy(int));
  assert.equal(unifier.isEmpty(bound.value0), false);
  const same = unifier.unify(unifier.empty)(toTy(int))(toTy(int));
  assert.equal(unifier.isEmpty(same.value0), true);
});

test('a meta binds to any type that does not contain it', () => {
  for (const type of [int, rigid(0), list(rigid(0))]) {
    assert.deepEqual(resolve(unify(new Map(), meta(0), type), meta(0)), type);
  }
  const failure = unify(new Map(), meta(0), list(meta(0)));
  assert.equal(failure.constructor.name, 'Occurs');
  assert.deepEqual([failure.value0, fromTy(failure.value1)], [0, list(meta(0))]);
  assert.deepEqual(unify(new Map(), meta(0), meta(0)), new Map());
});

test('arguments unify left to right and stop at the first failure', () => {
  const occurs = unify(new Map(), pair(meta(0), int), pair(list(meta(0)), bool));
  assert.equal(occurs.constructor.name, 'Occurs');
  const mismatch = unify(new Map(), pair(meta(0), int), pair(bool, meta(0)));
  assert.deepEqual([mismatch.constructor.name, fromTy(mismatch.value0),
    fromTy(mismatch.value1)], ['Mismatch', int, bool]);
});

test('substitute is one pass; resolve follows bindings to the end', () => {
  const s = new Map([[0, list(meta(1))], [1, int]]);
  assert.deepEqual(substitute(s, meta(0)), list(meta(1)));
  assert.deepEqual(resolve(s, meta(0)), list(int));
});

test('substitute matches its one-pass reading and the composition law', () => {
  const next = generator(0x5b5);
  for (let index = 0; index < cases; index += 1) {
    const [s1, s2, t] = [genSubst(next), genSubst(next), genType(next, maximumDepth)];
    assert.deepEqual(substitute(s1, t), once(s1, t));
    const composed = bindingsOf(unifier.compose(substOf(s2))(substOf(s1)));
    assert.deepEqual(substitute(composed, t), substitute(s2, substitute(s1, t)));
  }
});

test('resolve on acyclic substitutions is idempotent and total', () => {
  const next = generator(0x7e3);
  for (let index = 0; index < cases; index += 1) {
    const [s, t] = [genSubst(next, above), genType(next, maximumDepth)];
    const resolved = resolve(s, t);
    assert.deepEqual(resolve(s, resolved), resolved);
    assert.ok(metasOf(resolved).every(n => !s.has(n)), JSON.stringify(resolved));
  }
});

const checkUnifier = (s, left, right) => {
  assert.ok(acyclic(s), JSON.stringify([...s]));
  assert.deepEqual(resolve(s, left), resolve(s, right));
};

test('unify is sound, acyclic and most general, and agrees with the oracle', () => {
  const next = generator(0x3a9);
  const outcomes = { succeeded: 0, failed: 0 };
  for (let index = 0; index < cases; index += 1) {
    const { sigma, ground, left, right } = sigmaPair(next);
    const general = unify(new Map(), left, right);
    assert.ok(general instanceof Map, JSON.stringify([left, right]));
    checkUnifier(general, left, right);
    for (const side of [left, right]) assert.deepEqual(once(sigma, resolve(general, side)), ground);
    const [l2, r2] = [genType(next, maximumDepth), genType(next, maximumDepth)];
    const pairs = [[[l2, r2]], [[left, right], [l2, r2]]];
    pairs.forEach(sequence => {
      const s = sequence.reduce((acc, [l, r]) => acc instanceof Map ? unify(acc, l, r) : acc, new Map());
      const expected = oracleUnify(sequence);
      assert.equal(s instanceof Map, expected !== null, JSON.stringify(sequence));
      if (expected === null) { outcomes.failed += 1; return; }
      outcomes.succeeded += 1;
      sequence.forEach(([l, r]) => checkUnifier(s, l, r));
      assert.deepEqual(canonical(sequence.map(([l]) => resolve(s, l))), canonical(expected));
    });
  }
  assert.ok(outcomes.succeeded > cases / 4 && outcomes.failed > cases / 4,
    JSON.stringify(outcomes));
});

const nested = (depth, inner) => depth === 0 ? inner : list(nested(depth - 1, inner));
const sourceNesting = 128;
const chainLength = 10000;

test('occurs check and resolve are stack-safe at the bounds', () => {
  const deep = nested(sourceNesting, meta(0));
  assert.equal(unify(new Map(), meta(0), deep).constructor.name, 'Occurs');
  const bound = unify(new Map(), meta(0), nested(sourceNesting, int));
  assert.deepEqual(resolve(bound, meta(0)), nested(sourceNesting, int));
  // m0 -> m1 -> ... -> m10000, built directly so the test does not depend
  // on which side unify binds.
  const chain = new Map(Array.from({ length: chainLength }, (_, n) => [n, meta(n + 1)]));
  const solved = unify(chain, meta(0), int);
  assert.ok(solved instanceof Map);
  assert.deepEqual(resolve(solved, meta(0)), int);
  assert.deepEqual(resolve(solved, meta(chainLength)), int);
  assert.equal(unify(solved, bool, meta(0)).constructor.name, 'Mismatch');
});

test('an infinite type is E_TYPE with both types named', () => {
  const span = { start: { line: 1, column: 1, offset: 0 }, end: { line: 1, column: 2, offset: 1 } };
  const infinite = problem.InfiniteType.create(problem.HoleName.value)(
    problem.AppliedName.create('List')([problem.HoleName.value]));
  assert.deepEqual(wire({ problem: infinite, span }),
    { code: 'E_TYPE', message: 'Infinite type: _ occurs in List(_)', span });
});

// Ruling R7: unification recurses by type level, so past the limit it fails
// with TooDeep rather than recursing (a level counts like resolved depth).
test('unification stops with TooDeep past the inferred type limit', () => {
  const nested = (depth, leaf) => depth === 1 ? leaf : list(nested(depth - 1, leaf));
  const deepest = unifier.inferredTypeLimit;
  assert.deepEqual(unify(new Map(), nested(deepest, int), nested(deepest, int)), new Map());
  const failure = unify(new Map(), nested(deepest + 1, int), nested(deepest + 1, int));
  assert.equal(failure.constructor.name, 'TooDeep');
});
