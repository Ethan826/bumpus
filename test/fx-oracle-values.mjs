// Values of the FX001 reference interpreter: structural comparison and
// printing (ADR 005), and the type of a value as a failure report names it
// (`Error(Int)`, design §5). Shares no code with the compiler.
import { unit } from './poly-parse.mjs';

export const isFunction = value => value?.kind === 'fn' || value?.kind === 'op'
  || value?.kind === 'ctor' || value?.kind === 'builtin'
  || value?.kind === 'lambda';
export const isHandler = value => value?.kind === 'handler';

export const show = value => value === unit ? '()'
  : typeof value !== 'object' ? String(value)
  : value.fields.length === 0 ? value.ctor
    : `${value.ctor}(${value.fields.map(show).join(', ')})`;

const sign = difference => Math.sign(difference);
export const compareValues = (program, left, right) => {
  if (left === unit) return 0;
  if (typeof left !== 'object') return sign(Number(left) - Number(right));
  const order = program.ctors.get(left.ctor) - program.ctors.get(right.ctor);
  if (order !== 0) return sign(order);
  for (const [index, field] of left.fields.entries()) {
    const result = compareValues(program, field, right.fields[index]);
    if (result !== 0) return result;
  }
  return 0;
};

// The type of a runtime value as { head, args }. A type parameter no field
// determines is shown as Int, the representative of an unsolved hole.
export const typeOfValue = (program, value) => {
  if (value === unit) return { head: 'Unit', args: [] };
  if (typeof value === 'number') return { head: 'Int', args: [] };
  if (typeof value === 'boolean') return { head: 'Bool', args: [] };
  if (isHandler(value)) return { head: 'Handler', args: [] };
  if (isFunction(value)) return { head: '->', args: [] };
  const type = program.owner.get(value.ctor);
  const found = new Map();
  const declared = type.ctors.find(ctor => ctor.name === value.ctor);
  declared.fields.forEach((tree, index) =>
    bind(program, found, tree, typeOfValue(program, value.fields[index])));
  return { head: type.name, args: type.params.map(name =>
    found.get(name) ?? { head: 'Int', args: [] }) };
};

const bind = (program, found, tree, actual) => {
  if (tree.args.length === 0 && !program.types.has(tree.head)
    && /^[a-z]/.test(tree.head)) {
    if (!found.has(tree.head)) found.set(tree.head, actual);
    return;
  }
  tree.args.forEach((arg, index) => {
    if (actual.args[index]) bind(program, found, arg, actual.args[index]);
  });
};

export const typeText = type => (type.args.length === 0 ? type.head
  : `${type.head}(${type.args.map(typeText).join(', ')})`);

// A type is printable unless a function or handler occurs in it, through
// its declaration's fields or its arguments.
export const printable = (program, type, seen = new Set()) => {
  if (type.head === '->' || type.head === 'Handler') return false;
  if (!type.args.every(arg => printable(program, arg, seen))) return false;
  const declared = program.types.get(type.head);
  if (!declared || seen.has(declared.name)) return true;
  seen.add(declared.name);
  return declared.ctors.every(ctor => ctor.fields.every(tree =>
    printableField(program, declared, tree, seen)));
};

// Field trees mention the declaration's parameters, which are printable
// when the instance's argument is (checked above).
const printableField = (program, declared, tree, seen) => {
  if (declared.params.includes(tree.head)) return true;
  if (tree.head === '->' || tree.head === 'Handler') return false;
  return printable(program, tree, seen);
};
