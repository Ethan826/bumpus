// Types as the polymorphic program generator (test/poly-programs.mjs) sees
// them: 'Int', 'Bool', { variable }, { data, args } and the hole, a type
// argument left for checking to leave open. Only generation uses them; the
// reference interpreter (test/poly-oracle.mjs) evaluates without types.
import { choose } from './coverage-oracle.mjs';

export const variable = name => ({ variable: name });
export const data = (name, args = []) => ({ data: name, args });
export const hole = { hole: true };

export const typeText = type => typeof type === 'string' ? type
  : 'variable' in type ? type.variable
    : 'hole' in type ? '_'
      : type.args.length === 0 ? type.data
        : `${type.data}(${type.args.map(typeText).join(', ')})`;
export const same = (left, right) => typeText(left) === typeText(right);
export const isData = type => typeof type === 'object' && 'data' in type;

export const substitute = (type, mapping) => {
  if (typeof type === 'string' || 'hole' in type) return type;
  if ('variable' in type) return mapping.get(type.variable) ?? type;
  return data(type.data, type.args.map(arg => substitute(arg, mapping)));
};

// Extends `mapping` (callee variable → caller type) so that the callee's
// `pattern` becomes `target`; null when it cannot.
export const matchType = (pattern, target, mapping) => {
  if (typeof pattern === 'object' && 'variable' in pattern) {
    const bound = mapping.get(pattern.variable);
    if (bound) return same(bound, target) ? mapping : null;
    return new Map([...mapping, [pattern.variable, target]]);
  }
  if (typeof pattern === 'string' || typeof target === 'string') {
    return pattern === target ? mapping : null;
  }
  if (!isData(target) || pattern.data !== target.data) return null;
  return pattern.args.reduce((found, arg, index) => found
    && matchType(arg, target.args[index], found), mapping);
};

// Int and Bool exchanged at every leaf: `List(List(Int))` becomes
// `List(List(Bool))` and `Pair(Int, Bool)` becomes `Pair(Bool, Int)`.
export const swapLeaves = type => type === 'Int' ? 'Bool'
  : type === 'Bool' ? 'Int'
    : isData(type) ? data(type.data, type.args.map(swapLeaves)) : type;

const list = {
  name: 'List', parameters: ['a'],
  ctors: [{ name: 'Nil', fields: [] },
    { name: 'Cons', fields: [variable('a'), data('List', [variable('a')])] }]
};
const pair = {
  name: 'Pair', parameters: ['a', 'b'],
  ctors: [{ name: 'Pair', fields: [variable('a'), variable('b')] }]
};

// A generated parameterized type G. Constructor G0 has only parameters,
// Int and Bool as fields, so every application is inhabited and a value of
// it can always be built; later constructors may recurse into G with its
// parameters in order or swapped (design §4.1 accepts both) and wrap a
// parameter in List or Pair (another component, so wrapping is allowed).
const drawTree = next => {
  const parameters = ['a', 'b'].slice(0, 1 + choose(next, 2));
  const leaves = [...parameters.map(variable), 'Int', 'Bool'];
  const leaf = () => leaves[choose(next, leaves.length)];
  const own = () => data('G', (parameters.length === 2 && choose(next, 2)
    ? [...parameters].reverse() : parameters).map(variable));
  const field = () => [own, leaf, () => data('List', [leaf()]),
    () => data('Pair', [leaf(), 'Int'])][choose(next, 4)]();
  const fields = (count, draw) => Array.from({ length: count }, draw);
  const extra = 1 + choose(next, 2);
  const ctors = [{ name: 'G0', fields: fields(choose(next, 3), leaf) },
    ...Array.from({ length: extra }, (_, index) => ({
      name: `G${index + 1}`, fields: fields(1 + choose(next, 3), field)
    }))];
  return { name: 'G', parameters, ctors };
};

export const drawTypes = next => {
  const tree = drawTree(next);
  return new Map([list, pair, tree].map(type => [type.name, type]));
};

const fieldText = type => typeText(type);
export const declarationText = type => {
  const head = `type ${type.name}(${type.parameters.join(', ')})`;
  const ctor = each => each.fields.length === 0 ? each.name
    : `${each.name}(${each.fields.map(fieldText).join(', ')})`;
  return `${head} = ${type.ctors.map(ctor).join(' | ')};`;
};

// The constructor's field types at the applied type `type`.
export const fieldsAt = (types, type, ctor) => {
  const declared = types.get(type.data);
  const mapping = new Map(declared.parameters.map(
    (parameter, index) => [parameter, type.args[index]]));
  return ctor.fields.map(field => substitute(field, mapping));
};

// The ground types used to instantiate a variable no type fixes.
export const groundPool = types => [
  'Int', 'Bool', data('List', ['Int']), data('List', ['Bool']),
  data('List', [data('List', ['Int'])]),
  data('List', [data('List', ['Bool'])]),
  data('Pair', ['Int', 'Bool']), data('Pair', ['Bool', 'Int']),
  data('G', types.get('G').parameters.map(
    (_, index) => index ? 'Bool' : 'Int'))
];
