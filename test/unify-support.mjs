// Shared by test/unify.test.mjs and test/unify-arrow.test.mjs: plain JS
// types (as in test/unify-oracle.mjs) and the unifier called on them.
// Type 0 is List(a), 1 Pair(a, b); an arrow is { k: 'fun', args: [p, r] }.
import { Right } from '../output/Data.Either/index.js';
import { insert, toUnfoldable } from '../output/Data.Map.Internal/index.js';
import { ordInt } from '../output/Data.Ord/index.js';
import { unfoldableArray } from '../output/Data.Unfoldable/index.js';
import { TBool, TData, TFun, TInt, TVar } from '../output/Domain.Type/index.js';
import * as unifier from '../output/Features.Check.Unify/index.js';

export const int = { k: 'int' };
export const bool = { k: 'bool' };
export const rigid = n => ({ k: 'rigid', n });
export const meta = n => ({ k: 'meta', n });
export const list = t => ({ k: 'data', id: 0, args: [t] });
export const pair = (a, b) => ({ k: 'data', id: 1, args: [a, b] });
export const fun = (p, r) => ({ k: 'fun', args: [p, r] });

// `parameters[0] -> … -> result`, built by a loop.
export const spine = (parameters, result) =>
  parameters.reduceRight((rest, parameter) => fun(parameter, rest), result);

// Arrow spines are walked by loops here too, so a 5,000-long spine costs
// the test no recursion depth either.
const spineOf = t => {
  const parameters = [];
  let rest = t;
  while (rest.k === 'fun') { parameters.push(rest.args[0]); rest = rest.args[1]; }
  return { parameters, result: rest };
};

export const toTy = t => {
  if (t.k === 'int') return TInt.value;
  if (t.k === 'bool') return TBool.value;
  if (t.k === 'data') return TData.create(t.id)(t.args.map(toTy));
  if (t.k === 'fun') {
    const { parameters, result } = spineOf(t);
    return parameters.reduceRight((rest, parameter) =>
      TFun.create(toTy(parameter))(rest), toTy(result));
  }
  return TVar.create((t.k === 'rigid' ? unifier.Rigid : unifier.Meta).create(t.n));
};

export const fromTy = ty => {
  const tag = ty.constructor.name;
  if (tag === 'TInt') return int;
  if (tag === 'TBool') return bool;
  if (tag === 'TData') return { k: 'data', id: ty.value0, args: ty.value1.map(fromTy) };
  if (tag === 'TFun') {
    const parameters = [];
    let rest = ty;
    while (rest.constructor.name === 'TFun') { parameters.push(fromTy(rest.value0)); rest = rest.value1; }
    return spine(parameters, fromTy(rest));
  }
  return (ty.value0.constructor.name === 'Rigid' ? rigid : meta)(ty.value0.value0);
};

export const substOf = bindings => [...bindings].reduce((map, [n, t]) =>
  insert(ordInt)(n)(toTy(t))(map), unifier.empty);
export const bindingsOf = subst => new Map(toUnfoldable(unfoldableArray)(subst)
  .map(entry => [entry.value0, fromTy(entry.value1)]));
export const substitute = (s, t) => fromTy(unifier.substitute(substOf(s))(toTy(t)));
export const resolve = (s, t) => fromTy(unifier.resolve(substOf(s))(toTy(t)));
export const unify = (s, l, r) => {
  const result = unifier.unify(substOf(s))(toTy(l))(toTy(r));
  return result instanceof Right ? bindingsOf(result.value0) : result.value0;
};
