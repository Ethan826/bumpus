// The FX001 reference interpreter (design §2-§5): an untyped, strict, left
// to right evaluator of Waxwing programs with effects, written from the
// spec and sharing no code with the compiler. A context is an immutable
// chain of frames, `with` frames keyed by effect identity and `fail`
// frames keyed by the payload's declared head; an operation goes to the
// innermost frame with its key and its clause runs in the context outside
// that frame (option `clauseContext: 'inner'` runs it where the operation
// was performed instead, for the sensitivity check). `handle` makes one
// frame per clause, the first clause innermost. `observed` collects the
// feature events the generator's census counts.
import { parseProgram } from './fx-oracle-parse.mjs';
import { Abort, crashLine, Defect, OracleError } from './fx-oracle-cleanup.mjs';
import {
  evaluateBlock, evaluateHandle, evaluateWith, perform
} from './fx-oracle-frames.mjs';
import { isUpper, unit } from './poly-parse.mjs';
import {
  builtins, comparisons, find, matches
} from './fx-oracle-context.mjs';
import { compareValues, show, typeOfValue } from './fx-oracle-values.mjs';

const maximumSteps = 3_000_000;

export const interpret = (source, options = {}) => {
  const program = parseProgram(source);
  const state = { program, options, causes: [], events: new Set(), caught: 0,
    pendingAbort: [], lambdas: [], clauses: [], evaluate: null };
  const { causes, events, lambdas } = state;
  const stdout = [];
  let steps = 0;

  const arityOf = callee => callee.parameters?.length ?? callee.arity;
  const lookup = (name, env) => {
    if (!isUpper(name) && env.has(name)) return env.get(name);
    if (isUpper(name)) {
      return { kind: 'ctor', name, arity: program.fields.get(name), args: [] };
    }
    if (program.functions.has(name)) {
      return { kind: 'fn', name, args: [],
        arity: program.functions.get(name).parameters.length };
    }
    if (program.ops.has(name)) {
      const { effect, arity } = program.ops.get(name);
      return { kind: 'op', name, effect, arity, args: [] };
    }
    if (builtins.has(name)) return { kind: 'builtin', name, arity: 1, args: [] };
    throw new OracleError(`unknown name ${name}`);
  };
  const complete = (value, ctx) => (value?.args?.length === 0
    && arityOf(value) === 0 ? saturate(value, ctx) : value);
  const applyOne = (callee, argument, ctx) => {
    if (typeof callee !== 'object' || !callee.args) {
      throw new OracleError('applied a non-function');
    }
    const applied = { ...callee, args: [...callee.args, argument] };
    return applied.args.length < arityOf(applied) ? applied
      : saturate(applied, ctx);
  };
  const applyAll = (callee, nodes, env, ctx) => {
    let value = complete(callee, ctx);
    const declared = arityOf(callee);
    nodes.forEach((node, index) => {
      if (index >= declared && declared > 0) events.add('over-application');
      value = applyOne(value, evaluate(node, env, ctx), ctx);
    });
    return value;
  };
  const evaluatePipe = (node, env, ctx) => {
    const operand = evaluate(node.left, env, ctx);
    const right = node.right;
    const called = right.tag === 'applyValue'
      || (right.tag === 'apply' && right.args.length > 0);
    if (!called) return applyOne(evaluate(right, env, ctx), operand, ctx);
    const callee = right.tag === 'apply' ? lookup(right.name, env)
      : evaluate(right.callee, env, ctx);
    return applyOne(applyAll(callee, right.args, env, ctx), operand, ctx);
  };

  const saturate = (callee, ctx) => {
    const { args } = callee;
    if (callee.kind === 'ctor') return { ctor: callee.name, fields: args };
    if (callee.kind === 'op') return perform(state, callee, args, ctx);
    if (callee.kind === 'builtin') return builtin(callee.name, args[0], ctx);
    const bound = new Map(callee.kind === 'lambda' ? callee.env : []);
    const names = callee.kind === 'lambda' ? callee.parameters
      : program.functions.get(callee.name).parameters;
    names.forEach((name, index) => { if (name !== null) bound.set(name, args[index]); });
    if (callee.kind === 'fn') {
      return evaluate(program.functions.get(callee.name).body, bound, ctx);
    }
    lambdas.push(callee.ctx);
    try { return evaluate(callee.body, bound, ctx); } finally { lambdas.pop(); }
  };

  const builtin = (name, argument, ctx) => {
    if (name === 'print') { stdout.push(`${show(argument)}\n`); return unit; }
    if (name === 'crash') {
      causes.push(crashLine(argument));
      throw new Defect();
    }
    const type = typeOfValue(program, argument);
    const frame = find(ctx, 'fail', type.head);
    if (!frame) throw new OracleError(`no handle for ${type.head}`);
    throw new Abort(frame.marker, argument, ctx);
  };

  const evaluate = (node, env, ctx) => {
    if (++steps > maximumSteps) throw new OracleError('step limit');
    switch (node.tag) {
      case 'value': return node.value;
      case 'local': return complete(lookup(node.name, env), ctx);
      case 'lambda': return { ...node, kind: 'lambda', env, ctx, args: [] };
      case 'add': {
        const left = evaluate(node.left, env, ctx);
        return (left + evaluate(node.right, env, ctx)) | 0;
      }
      case 'compare': {
        const left = evaluate(node.left, env, ctx);
        const right = evaluate(node.right, env, ctx);
        return comparisons[node.operator](compareValues(program, left, right));
      }
      case 'if': return evaluate(node.condition, env, ctx)
        ? evaluate(node.yes, env, ctx) : evaluate(node.no, env, ctx);
      case 'match': return evaluateMatch(node, env, ctx);
      case 'block': return evaluateBlock(state, node, env, ctx);
      case 'pipe': return evaluatePipe(node, env, ctx);
      case 'handler': return { kind: 'handler', effect: node.effect,
        clauses: new Map(node.clauses.map(c => [c.name, c])), env };
      case 'with': return evaluateWith(state, node, env, ctx);
      case 'handle': return evaluateHandle(state, node, env, ctx);
      case 'applyValue':
        return applyAll(evaluate(node.callee, env, ctx), node.args, env, ctx);
      default: return applyAll(lookup(node.name, env), node.args, env, ctx);
    }
  };
  const evaluateMatch = (node, env, ctx) => {
    const value = evaluate(node.scrutinee, env, ctx);
    for (const arm of node.arms) {
      const bound = new Map(env);
      if (matches(arm.pattern, value, bound)) return evaluate(arm.body, bound, ctx);
    }
    throw new OracleError('no arm matched');
  };
  state.evaluate = evaluate;

  const finish = () => {
    try {
      const value = saturate(lookup('main', new Map()), null);
      if (value !== unit) stdout.push(`${show(value)}\n`);
      return { stdout: stdout.join(''), stderr: '', status: 0 };
    } catch (thrown) {
      if (!(thrown instanceof Defect)) throw thrown;
      const lines = causes.map((line, index) =>
        (index === 0 ? line : `cleanup failed: ${line}`));
      return { stdout: stdout.join(''), stderr: `${lines.join('\n')}\n`, status: 1 };
    }
  };
  return { ...finish(), events };
};

// The outcome as the differential test compares it. An interpreter error
// (such as "typed abort escaped cleanup", a hole in the strict `defer` rule)
// is itself an outcome with status -1, so Go cannot agree with it and it is
// reported as a difference.
export const outcome = (source, options) => {
  try { return interpret(source, options); } catch (thrown) {
    if (!(thrown instanceof OracleError || thrown instanceof RangeError)) throw thrown;
    return { stdout: '', stderr: `oracle error: ${thrown.message}\n`, status: -1,
      events: new Set() };
  }
};
