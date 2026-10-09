// An independent reference interpreter for Bumpus programs (P001 Task 8,
// design §8 execution oracle). It reads the source with its own parser
// (test/poly-parse.mjs) and evaluates without types: a value is an Int (a
// JS number kept in int32, so `+` wraps modulo 2^32), a Bool,
// { ctor, fields } or a function value (FN001 Task 7, below). Evaluation
// is strict and left to right; a block's items run in order, each `let`
// in scope for the items after it (FX001 Task 2). Comparison is
// the structural order of ADR 005: constructor declaration position, then
// fields left to right; false < true; `()` equals itself. It shares no
// code with the compiler.
import { isUpper, parseProgram, unit } from './poly-parse.mjs';

const maximumSteps = 5_000_000;

const sign = difference => Math.sign(difference);
const compareValues = (program, left, right) => {
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

// A function value: a named function or constructor ({ name, arity }) or
// a lambda's closure ({ parameters, body, locals }), with the arguments
// applied so far. Applying the argument that completes its stage boundary
// (declared arity, a lambda's last parameter) runs it; until then the
// argument is only recorded (design §5).
const arityOf = callee => callee.parameters?.length ?? callee.arity;

class Probe extends Error {}

const interpreter = (program, probes) => {
  let steps = 0;
  const enters = [];
  const named = name => (isUpper(name)
    ? { name, arity: program.fields.get(name), args: [] }
    : { name, arity: program.functions.get(name).parameters.length,
      args: [] });
  const lookup = (name, locals) => (!isUpper(name) && locals.has(name)
    ? locals.get(name) : named(name));
  const evaluate = (node, locals) => {
    if (++steps > maximumSteps) throw new Error('oracle: step limit');
    switch (node.tag) {
      case 'value': return node.value;
      case 'local': return complete(lookup(node.name, locals));
      case 'lambda': return { ...node, locals, args: [] };
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
      case 'block': return evaluateBlock(node, locals);
      case 'pipe': return evaluatePipe(node, locals);
      case 'applyValue':
        return applyAll(evaluate(node.callee, locals), node.args, locals);
      default:
        return applyAll(lookup(node.name, locals), node.args, locals);
    }
  };
  // `f()` and a bare nullary constructor run at once.
  const complete = value => (value?.args?.length === 0 && arityOf(value) === 0
    ? saturate(value) : value);
  // `e(a1, …, aj)` is `e(a1)…(aj)`: each argument, then its application.
  const applyAll = (callee, nodes, locals) => nodes.reduce(
    (value, node) => applyOne(value, evaluate(node, locals)),
    complete(callee));
  const applyOne = (callee, argument) => {
    const applied = { ...callee, args: [...callee.args, argument] };
    return applied.args.length < arityOf(applied) ? applied
      : saturate(applied);
  };
  // The left operand first, then `g`, `b1…bk`, then the operand applied.
  const evaluatePipe = (node, locals) => {
    const operand = evaluate(node.left, locals);
    const right = node.right;
    const called = right.tag === 'applyValue'
      || (right.tag === 'apply' && right.args.length > 0);
    if (!called) return applyOne(evaluate(right, locals), operand);
    const callee = right.tag === 'apply' ? lookup(right.name, locals)
      : evaluate(right.callee, locals);
    return applyOne(applyAll(callee, right.args, locals), operand);
  };
  const evaluateMatch = (node, locals) => {
    const value = evaluate(node.scrutinee, locals);
    for (const arm of node.arms) {
      const bound = new Map(locals);
      if (matches(arm.pattern, value, bound)) return evaluate(arm.body, bound);
    }
    throw new Error('oracle: no arm matched');
  };
  // Each let extends a copy of the scope, so a closure keeps the locals it
  // saw (capture by value) when a later let shadows one.
  const evaluateBlock = (node, locals) => {
    let scope = locals;
    for (const item of node.items) {
      const value = evaluate(item.value, scope);
      if (item.tag === 'let' && item.name !== null) {
        scope = new Map(scope).set(item.name, value);
      }
    }
    return evaluate(node.value, scope);
  };
  // The functions being applied, innermost last, to count self calls.
  const active = [];
  const counts = { recursive: 0 };
  const saturate = value => {
    if (value.body) {
      const bound = new Map(value.locals);
      value.parameters.forEach((parameter, index) => {
        if (parameter !== null) bound.set(parameter, value.args[index]);
      });
      return evaluate(value.body, bound);
    }
    if (isUpper(value.name)) return { ctor: value.name, fields: value.args };
    return enter(value.name, value.args);
  };
  const enter = (name, values) => {
    enters.push(name);
    if (probes.has(name)) throw new Probe(name);
    if (active.at(-1) === name) counts.recursive++;
    const definition = program.functions.get(name);
    active.push(name);
    try {
      return evaluate(definition.body, new Map(definition.parameters.map(
        (parameter, index) => [parameter, values[index]])));
    } finally { active.pop(); }
  };
  return { enter, counts, enters };
};

export const show = value => value === unit ? '()'
  : typeof value !== 'object' ? String(value)
  : value.fields.length === 0 ? value.ctor
    : `${value.ctor}(${value.fields.map(show).join(', ')})`;

// What the compiled program prints for `main` (without the newline), how
// many calls a function made to itself on the way, and the functions whose
// bodies were entered, in order, as declaration positions. Entering a
// function named in `probes` stops the run: `probe` is its name.
export const run = (source, probes = []) => {
  const program = parseProgram(source);
  const { enter, counts, enters } = interpreter(program, new Set(probes));
  const positions = () => {
    const names = [...program.functions.keys()];
    return enters.map(name => names.indexOf(name));
  };
  try {
    const printed = show(enter('main', []));
    return { printed, recursive: counts.recursive, enters: positions() };
  } catch (error) {
    if (!(error instanceof Probe)) throw error;
    return { probe: error.message, enters: positions() };
  }
};

export const interpret = source => run(source).printed;
