// An independent reference interpreter for Bumpus programs (P001 Task 8,
// design §8 execution oracle). It reads the source with its own parser
// (test/poly-parse.mjs) and evaluates without types: a value is an Int (a
// JS number kept in int32, so `+` wraps modulo 2^32), a Bool, or
// { ctor, fields }. Evaluation is strict and left to right. Comparison is
// the structural order of ADR 005: constructor declaration position, then
// fields left to right; false < true. It shares no code with the compiler.
import { isUpper, parseProgram } from './poly-parse.mjs';

const maximumSteps = 5_000_000;

const sign = difference => Math.sign(difference);
const compareValues = (program, left, right) => {
  if (typeof left !== 'object') return sign(Number(left) - Number(right));
  const order = program.ctors.get(left.ctor) - program.ctors.get(right.ctor);
  if (order !== 0) return sign(order);
  for (const [index, field] of left.fields.entries()) {
    const result = compareValues(program, field, right.fields[index]);
    if (result !== 0) return result;
  }
  return 0;
};
const comparisons = {
  '==': order => order === 0, '!=': order => order !== 0,
  '<': order => order < 0, '<=': order => order <= 0,
  '>': order => order > 0, '>=': order => order >= 0
};

// Binds the pattern's names into `bound`, or returns false.
const matches = (pattern, value, bound) => {
  if (pattern.tag === 'wildcard') return true;
  if (pattern.tag === 'bind') { bound.set(pattern.name, value); return true; }
  if (pattern.tag === 'literal') return pattern.value === value;
  return pattern.name === value.ctor && pattern.fields.every(
    (field, index) => matches(field, value.fields[index], bound));
};

const interpreter = program => {
  let steps = 0;
  const evaluate = (node, locals) => {
    if (++steps > maximumSteps) throw new Error('oracle: step limit');
    switch (node.tag) {
      case 'value': return node.value;
      case 'local': return locals.get(node.name);
      case 'add': {
        const left = evaluate(node.left, locals);
        return (left + evaluate(node.right, locals)) | 0;
      }
      case 'compare': {
        const left = evaluate(node.left, locals);
        const right = evaluate(node.right, locals);
        return comparisons[node.operator](compareValues(program, left, right));
      }
      case 'if': return evaluate(node.condition, locals)
        ? evaluate(node.yes, locals) : evaluate(node.no, locals);
      case 'match': return evaluateMatch(node, locals);
      default: return apply(node.name, node.args.map(
        argument => evaluate(argument, locals)));
    }
  };
  const evaluateMatch = (node, locals) => {
    const value = evaluate(node.scrutinee, locals);
    for (const arm of node.arms) {
      const bound = new Map(locals);
      if (matches(arm.pattern, value, bound)) return evaluate(arm.body, bound);
    }
    throw new Error('oracle: no arm matched');
  };
  // The functions being applied, innermost last, to count self calls.
  const active = [];
  const counts = { recursive: 0 };
  const apply = (name, values) => {
    if (isUpper(name)) return { ctor: name, fields: values };
    if (active.at(-1) === name) counts.recursive++;
    const definition = program.functions.get(name);
    active.push(name);
    try {
      return evaluate(definition.body, new Map(definition.parameters.map(
        (parameter, index) => [parameter, values[index]])));
    } finally { active.pop(); }
  };
  return { apply, counts };
};

export const show = value => typeof value !== 'object' ? String(value)
  : value.fields.length === 0 ? value.ctor
    : `${value.ctor}(${value.fields.map(show).join(', ')})`;

// What the compiled program prints for `main` (without the newline), and
// how many calls a function made to itself on the way.
export const run = source => {
  const { apply, counts } = interpreter(parseProgram(source));
  return { printed: show(apply('main', [])), recursive: counts.recursive };
};

export const interpret = source => run(source).printed;
