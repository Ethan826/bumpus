// Shared by test/unify.test.mjs, test/unify-arrow.test.mjs and
// test/unify-row.test.mjs: plain JS types (as in test/unify-oracle.mjs)
// and the unifier called on them.
// Type 0 is List(a), 1 Pair(a, b); an arrow is { k: 'fun', args: [p, r] },
// with an optional effect row `row` (FX001; absent means closed and empty,
// as every arrow before rows was). A row is { labels, tail }: each label
// { e, args } names a user effect by number, or 'fail' or 'console'; the
// tail is null (closed) or a rigid or meta variable.
import { Right } from '../output/Data.Either/index.js';
import { insert, toUnfoldable } from '../output/Data.Map.Internal/index.js';
import { Just, Nothing } from '../output/Data.Maybe/index.js';
import { ordInt } from '../output/Data.Ord/index.js';
import { unfoldableArray } from '../output/Data.Unfoldable/index.js';
import {
  ConsoleEffect, FailEffect, Label, Row, UserEffect
} from '../output/Domain.Row/index.js';
import { TBool, TData, TFun, TInt, TVar } from '../output/Domain.Type/index.js';
import * as unifier from '../output/Features.Check.Unify/index.js';

export const int = { k: 'int' };
export const bool = { k: 'bool' };
export const rigid = n => ({ k: 'rigid', n });
export const meta = n => ({ k: 'meta', n });
export const list = t => ({ k: 'data', id: 0, args: [t] });
export const pair = (a, b) => ({ k: 'data', id: 1, args: [a, b] });
export const fun = (p, r) => ({ k: 'fun', args: [p, r] });
export const closed = { labels: [], tail: null };

// `parameters[0] -> … -> result`, built by a loop.
export const spine = (parameters, result) =>
  parameters.reduceRight((rest, parameter) => fun(parameter, rest), result);

const flexOf = v => (v.k === 'rigid' ? unifier.Rigid : unifier.Meta).create(v.n);
const plainFlex = flex =>
  (flex.constructor.name === 'Rigid' ? rigid : meta)(flex.value0);
const effectOf = e => typeof e === 'number' ? UserEffect.create(e)
  : e === 'fail' ? FailEffect.value : ConsoleEffect.value;
const plainEffect = ref => ref instanceof UserEffect ? ref.value0
  : ref instanceof FailEffect ? 'fail' : 'console';

export const toRow = r => Row.create(r.labels.map(toLabel))(
  r.tail === null ? Nothing.value : Just.create(flexOf(r.tail)));
export const toLabel = l => Label.create(effectOf(l.e))(l.args.map(toTy));
export const fromLabel = l => ({ e: plainEffect(l.value0), args: l.value1.map(fromTy) });
export const fromRow = row => ({
  labels: row.value0.map(fromLabel),
  tail: row.value1 instanceof Just ? plainFlex(row.value1.value0) : null
});
const isClosedEmpty = r => r.labels.length === 0 && r.tail === null;

// Arrow spines are walked by loops here too, so a 5,000-long spine costs
// the test no recursion depth either.
export const toTy = t => {
  if (t.k === 'int') return TInt.value;
  if (t.k === 'bool') return TBool.value;
  if (t.k === 'data') return TData.create(t.id)(t.args.map(toTy))((t.rows ?? []).map(toRow));
  if (t.k === 'fun') {
    const stages = [];
    let rest = t;
    while (rest.k === 'fun') { stages.push(rest); rest = rest.args[1]; }
    return stages.reduceRight((built, stage) => TFun.create(toTy(stage.args[0]))(
      toRow(stage.row ?? closed))(built), toTy(rest));
  }
  return TVar.create(flexOf(t));
};

export const fromTy = ty => {
  const tag = ty.constructor.name;
  if (tag === 'TInt') return int;
  if (tag === 'TBool') return bool;
  if (tag === 'TData') {
    const plain = { k: 'data', id: ty.value0, args: ty.value1.map(fromTy) };
    return ty.value2.length === 0 ? plain : { ...plain, rows: ty.value2.map(fromRow) };
  }
  if (tag === 'TFun') {
    const stages = [];
    let rest = ty;
    while (rest.constructor.name === 'TFun') { stages.push(rest); rest = rest.value2; }
    return stages.reduceRight((built, stage) => {
      const row = fromRow(stage.value1);
      const arrow = fun(fromTy(stage.value0), built);
      return isClosedEmpty(row) ? arrow : { ...arrow, row };
    }, fromTy(rest));
  }
  return plainFlex(ty.value0);
};

const mapOf = (bindings, convert) => [...bindings].reduce((map, [n, t]) =>
  insert(ordInt)(n)(convert(t))(map), unifier.empty.types);
const plainMap = (map, convert) => new Map(toUnfoldable(unfoldableArray)(map)
  .map(entry => [entry.value0, convert(entry.value1)]));

// A substitution with these type bindings and, optionally, row bindings.
export const substOf = (bindings, rowBindings = new Map()) => ({
  ...unifier.empty, types: mapOf(bindings, toTy), rows: mapOf(rowBindings, toRow)
});
export const bindingsOf = subst => plainMap(subst.types, fromTy);
export const rowBindingsOf = subst => plainMap(subst.rows, fromRow);
export const substitute = (s, t) => fromTy(unifier.substitute(substOf(s))(toTy(t)));
export const resolve = (s, t) => fromTy(unifier.resolve(substOf(s))(toTy(t)));
export const unify = (s, l, r) => {
  const result = unifier.unify(substOf(s))(toTy(l))(toTy(r));
  return result instanceof Right ? bindingsOf(result.value0) : result.value0;
};
