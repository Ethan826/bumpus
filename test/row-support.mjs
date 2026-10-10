// Generators and wrappers for test/unify-row.test.mjs (FX001 Task 3).
// Rows are plain JS (test/unify-support.mjs). Type metas are 0..2, row
// metas 10..12, so each variable has one sort, as in the checker.
import { Right } from '../output/Data.Either/index.js';
import * as unifier from '../output/Features.Check.Unify/index.js';
import * as rows from '../output/Features.Check.UnifyRow/index.js';
import { choose } from './coverage-oracle.mjs';
import { keyOf, normalRow } from './row-oracle.mjs';
import {
  bool, fromRow, fun, int, list, meta, rigid, rowBindingsOf, bindingsOf, substOf, toRow
} from './unify-support.mjs';

export { fromRow };
export const label = (e, ...args) => ({ e, args });
export const row = (labels, tail = null) => ({ labels, tail });
export const rowMeta = n => meta(n);

// Unifies two rows from the empty substitution: the Subst, or the Failure.
export const unifyRows = (left, right, start = unifier.empty) => {
  const result = rows.unifyRows(unifier.unify)(start)(toRow(left))(toRow(right));
  return result instanceof Right ? { subst: result.value0 } : { failure: result.value0 };
};
export const resolveRow = (subst, r) => fromRow(unifier.resolveRow(subst)(toRow(r)));
export const kind = outcome => outcome.failure?.constructor.name ?? 'Subst';

// Rows equal under scoped-label equality: their normal forms coincide.
export const scopedEqual = (left, right) =>
  JSON.stringify(normalRow(left)) === JSON.stringify(normalRow(right));

// Every meta a binding mentions, types and rows apart.
const typeParts = t => {
  const nested = [...(t.args ?? []).map(typeParts),
    ...(t.rows ?? []).map(rowParts), ...(t.row ? [rowParts(t.row)] : [])];
  return { types: [...(t.k === 'meta' ? [t.n] : []), ...nested.flatMap(p => p.types)],
    rows: nested.flatMap(p => p.rows) };
};
const rowParts = r => {
  const nested = r.labels.flatMap(l => l.args.map(typeParts));
  return { types: nested.flatMap(p => p.types),
    rows: [...(r.tail?.k === 'meta' ? [r.tail.n] : []), ...nested.flatMap(p => p.rows)] };
};

// No meta reaches itself through bindings of either sort.
export const acyclic = subst => {
  const [types, rowMap] = [bindingsOf(subst), rowBindingsOf(subst)];
  const edges = node => {
    const [sort, n] = node;
    if (sort === 't') {
      if (!types.has(n)) return [];
      const parts = typeParts(types.get(n));
      return [...parts.types.map(m => ['t', m]), ...parts.rows.map(m => ['r', m])];
    }
    if (!rowMap.has(n)) return [];
    const parts = rowParts(rowMap.get(n));
    return [...parts.types.map(m => ['t', m]), ...parts.rows.map(m => ['r', m])];
  };
  const name = ([sort, n]) => `${sort}${n}`;
  const state = new Map();
  const visit = node => {
    const key = name(node);
    if (state.get(key) === 'done') return true;
    if (state.get(key) === 'active') return false;
    state.set(key, 'active');
    const ok = edges(node).every(visit);
    state.set(key, 'done');
    return ok;
  };
  return [...types.keys()].every(n => visit(['t', n]))
    && [...rowMap.keys()].every(n => visit(['r', n]));
};

// Label arguments: small alphabets, so repeated keys and shared metas are
// common. Error(Int)/Error(Bool) share the Error family key; arrows
// appear as ordinary label arguments (and as indefinitely deferred Fail).
const error = arg => ({ k: 'data', id: 2, args: [arg] });
const groundArgument = next => [int, bool, rigid(0), list(int), list(bool),
  error(int), error(bool), fun(int, bool)][choose(next, 8)];
// Rigid row variables are 5 and 6, apart from the rigid type variable 0.
const groundLabel = (next, deferred) => {
  const which = choose(next, 5);
  if (which === 0) return label(0);
  if (which === 3) return label('console');
  if (which === 4) return label('fail', [int, bool, list(int), list(bool),
    error(int), error(bool), ...(deferred ? [fun(int, bool)] : [])][choose(next, deferred ? 7 : 6)]);
  return label(which, groundArgument(next));
};
const anyArgument = next => choose(next, 3) === 0 ? meta(choose(next, 3)) : groundArgument(next);
const anyLabel = (next, deferred) => {
  const ground = groundLabel(next, deferred);
  return ground.e === 1 || ground.e === 2 || deferred && ground.e === 'fail'
    ? label(ground.e, anyArgument(next)) : ground;
};
const anyTail = next => [null, rigid(5), rigid(6), rowMeta(10), rowMeta(11), rowMeta(12)][choose(next, 6)];
const count = (next, most) => choose(next, most + 1);

// An arbitrary pair: often failing, often sharing a tail.
export const anyPair = (next, deferred = true) => [
  row(Array.from({ length: count(next, 4) }, () => anyLabel(next, deferred)), anyTail(next)),
  row(Array.from({ length: count(next, 4) }, () => anyLabel(next, deferred)), anyTail(next))
];

// A scoped permutation of `labels`: repeatedly take the first remaining
// entry of a randomly chosen key, so one key's entries keep their order.
const scopedShuffle = (next, labels) => {
  const pending = labels.map((l, index) => ({ l, index }));
  const out = [];
  while (pending.length > 0) {
    const firsts = pending.filter(entry => !pending.some(other =>
      other.index < entry.index && keyOf(other.l) === keyOf(entry.l)));
    const chosen = firsts[choose(next, firsts.length)];
    out.push(chosen.l);
    pending.splice(pending.indexOf(chosen), 1);
  }
  return out;
};

// Drops the last occurrences of some keys, so the rest is a per-key prefix.
const keyPrefix = (next, labels) => {
  const keep = new Map();
  for (const key of new Set(labels.map(keyOf))) {
    const total = labels.filter(l => keyOf(l) === key).length;
    keep.set(key, count(next, total));
  }
  const seen = new Map();
  return labels.filter(l => {
    const key = keyOf(l);
    seen.set(key, (seen.get(key) ?? 0) + 1);
    return seen.get(key) <= keep.get(key);
  });
};

// A view of `ground` that unifies with any other view: a scoped permutation,
// some arguments replaced by type metas (the same meta for the same ground
// argument), and, if it drops entries, an open tail standing for them.
const view = (next, ground, tailMeta, sigma, deferred) => {
  const dropping = choose(next, 2) === 0;
  const kept = dropping ? keyPrefix(next, ground.labels) : ground.labels;
  const abstracted = scopedShuffle(next, kept).map(l => !deferred && l.e === 'fail' ? l : {
    ...l, args: l.args.map(arg => abstractArgument(next, arg, sigma))
  });
  return row(abstracted, dropping ? rowMeta(tailMeta) : ground.tail);
};
const abstractArgument = (next, arg, sigma) => {
  if (choose(next, 3) !== 0) return arg;
  const text = JSON.stringify(arg);
  if (!sigma.has(text)) {
    if (sigma.size >= 3) return arg;
    sigma.set(text, sigma.size);
  }
  return meta(sigma.get(text));
};

// A pair that must unify: two views of one ground row.
export const unifiablePair = (next, deferred = true) => {
  const ground = row(Array.from({ length: count(next, 5) }, () => groundLabel(next, deferred)),
    [null, rigid(5)][choose(next, 2)]);
  const sigma = new Map();
  return [view(next, ground, 10, sigma, deferred), view(next, ground, 11, sigma, deferred)];
};

// Acyclic, nonempty starting substitutions, including an already extended
// row. These seeds deliberately constrain arbitrary generated pairs.
export const startingSubst = next => {
  const types = new Map([[0, choose(next, 2) === 0 ? int : bool]]);
  const rows = new Map([[12, row([label('console')], rowMeta(13))]]);
  return { subst: substOf(types, rows), seed: { types, rows } };
};
