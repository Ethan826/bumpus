// Type-directed expressions for the generated polymorphic programs
// (test/poly-programs.mjs). `expression(scope, type, depth)` returns source
// text of exactly `type`, where the scope holds the locals in reach (each
// { name, type, decreasing, smaller }), the earlier functions it may call
// and, inside a function, that function's own signature. Matches cover each
// constructor once, so every match is exhaustive and none is redundant.
import { choose } from './coverage-oracle.mjs';
import {
  data, fieldsAt, hole, isData, matchType, same, substitute, variable
} from './poly-types.mjs';

const integers = ['0', '1', '-1', '7', '2147483647', '-2147483648'];
const operators = ['==', '!=', '<', '<=', '>', '>='];
const compared = ['Int', 'Int', data('List', ['Int']),
  data('Pair', ['Bool', 'Int'])];

const pick = (next, items) => items[choose(next, items.length)];
const lower = depth => Math.max(depth - 1, 0);

// Whether every variable in `type` has a local of that type; a list-only
// variable has none until a match binds one.
const producible = (scope, type) => typeof type === 'string'
  || ('variable' in type ? scope.locals.some(local => same(local.type, type))
    : type.args.every(arg => producible(scope, arg)));

// At depth 0 only a type's first constructor is built; generated types
// make it non-recursive (and `Nil` needs no element), so construction
// always bottoms out. Above it a later constructor is preferred, so values
// are deep enough to recurse on.
const construct = (scope, type, depth) => {
  const declared = scope.types.get(type.data);
  const later = declared.ctors.slice(1);
  const ctor = depth > 0 && later.length && producible(scope, type)
    && choose(scope.next, 3) ? pick(scope.next, later) : declared.ctors[0];
  if (ctor.fields.length === 0) return ctor.name;
  const fields = fieldsAt(scope.types, type, ctor).map(field =>
    expression(scope, field, lower(depth)));
  return `${ctor.name}(${fields.join(', ')})`;
};

// A variable no type fixes is a caller variable or a ground type, or, when
// it appears only as `List(v)`, sometimes a hole (the argument is `Nil`).
const call = (scope, callee, fixed, depth) => {
  const own = scope.bare.map(variable);
  const choices = [...own, ...own, ...scope.pool];
  const mapping = new Map(callee.variables.map(name => [name,
    fixed.get(name) ?? (callee.listOnly.includes(name)
      && choose(scope.next, 3) === 0 ? hole : pick(scope.next, choices))]));
  scope.calls.push({ caller: scope.self, callee, mapping });
  const args = callee.parameters.map(type =>
    expression(scope, substitute(type, mapping), depth - 1));
  return `${callee.name}(${args.join(', ')})`;
};

// A self call passes a part of the recursion parameter in its place.
const selfCall = (scope, smaller, depth) => {
  const self = scope.self;
  scope.calls.push({ caller: self, callee: self, mapping: new Map(
    self.variables.map(name => [name, variable(name)])) });
  const args = self.parameters.map((type, index) => index === self.recursion
    ? pick(scope.next, smaller).name : expression(scope, type, depth - 1));
  return `${self.name}(${args.join(', ')})`;
};

// One arm per constructor; a binder of the recursion parameter's type
// taken from the parameter (or from a part of it) is smaller than it. With
// `recurse`, an arm that binds one usually recurses on it at once.
const matchOn = (scope, type, depth, scrutinee = pick(scope.next,
  scope.locals.filter(local => isData(local.type))), recurse = false) => {
  const self = scope.self;
  const recursive = self && self.recursion >= 0
    ? self.parameters[self.recursion] : null;
  const arm = ctor => {
    const binders = fieldsAt(scope.types, scrutinee.type, ctor).map(field => {
      if (choose(scope.next, 4) === 0) return null;
      const smaller = scrutinee.decreasing && same(field, recursive);
      const name = `v${scope.counter.value++}`;
      return { name, type: field, decreasing: smaller, smaller };
    });
    const pattern = binders.length === 0 ? ctor.name : `${ctor.name}(`
      + `${binders.map(binder => binder ? binder.name : '_').join(', ')})`;
    const inner = { ...scope,
      locals: [...scope.locals, ...binders.filter(Boolean)] };
    const smaller = binders.filter(binder => binder && binder.smaller);
    const now = recurse && smaller.length && choose(scope.next, 3);
    return `${pattern} => ${now ? selfCall(inner, smaller, depth - 1)
      : expression(inner, type, depth - 1)}`;
  };
  const ctors = scope.types.get(scrutinee.type.data).ctors;
  return `(match ${scrutinee.name} { ${ctors.map(arm).join(', ')} })`;
};

// A comparison's operand type must be fixed (an open `Nil < Nil` is
// AmbiguousType), so a list's left operand is a `Cons`.
const comparison = (scope, depth) => {
  const type = pick(scope.next, compared);
  const left = isData(type) && type.data === 'List'
    ? `Cons(${expression(scope, 'Int', depth - 1)}, `
      + `${expression(scope, type, depth - 1)})`
    : expression(scope, type, depth - 1);
  const operator = pick(scope.next, operators);
  return `(${left} ${operator} ${expression(scope, type, depth - 1)})`;
};

const leaves = (scope, type, depth) => {
  const options = [];
  const locals = scope.locals.filter(local => same(local.type, type));
  if (locals.length) options.push(() => pick(scope.next, locals).name);
  if (type === 'Int') options.push(() => pick(scope.next, integers));
  if (type === 'Bool') options.push(() => pick(scope.next, ['true', 'false']));
  if (isData(type)) options.push(() => construct(scope, type, depth));
  return options;
};

const compound = (scope, type, depth) => {
  const options = [];
  const deeper = inner => expression(scope, inner, depth - 1);
  if (type === 'Int') {
    options.push(() => `(${deeper('Int')} + ${deeper('Int')})`);
  }
  if (type === 'Bool') options.push(() => comparison(scope, depth));
  options.push(() => `(if ${deeper('Bool')} then ${deeper(type)}`
    + ` else ${deeper(type)})`);
  if (scope.locals.some(local => isData(local.type))) {
    options.push(() => matchOn(scope, type, depth));
  }
  for (const callee of scope.functions) {
    const fixed = matchType(callee.result, type, new Map());
    if (fixed) options.push(() => call(scope, callee, fixed, depth));
  }
  const smaller = scope.locals.filter(local => local.smaller);
  if (smaller.length && same(type, scope.self.result)) {
    const recurse = () => selfCall(scope, smaller, depth);
    options.push(recurse, recurse, recurse);
  }
  return options;
};

export const expression = (scope, type, depth) => {
  // Only `List(_)` carries a hole: the argument that leaves it open.
  if (isData(type) && type.args.some(arg => same(arg, hole))) return 'Nil';
  const options = [...leaves(scope, type, depth),
    ...(depth > 0 ? compound(scope, type, depth) : [])];
  if (options.length === 0) throw new Error(`no expression of ${type}`);
  return pick(scope.next, options)();
};

// A recursive function's body matches on its recursion parameter first, so
// the arms have smaller parts to recurse on.
export const body = (scope, type, depth) => scope.self.recursion < 0
  ? expression(scope, type, depth)
  : matchOn(scope, type, depth, scope.locals[scope.self.recursion],
    same(type, scope.self.result));
