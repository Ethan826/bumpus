// Handler frames, aborts and blocks of the FX001 reference interpreter
// (design §3). `state` is the interpreter's shared record: { program,
// events, causes, caught, evaluate, lambdas (creation contexts of the
// running closures), clauses (effects whose clause is running),
// pendingAbort, options }.
import { Abort, Defect, OracleError, runCleanups } from './fx-oracle-cleanup.mjs';
import { count, find } from './fx-oracle-context.mjs';
import { isHandler } from './fx-oracle-values.mjs';

// What the census counts about an operation: scoped same-key frames, a
// clause performing its own effect, a callback whose handler comes from
// where it is called and differs from the one in force where it was made,
// and a cleanup whose handler comes from its registration context and
// differs from the one in force where the abort was raised.
const note = (state, effect, frame, ctx) => {
  const { events, lambdas, clauses } = state;
  if (count(ctx, effect) >= 2) events.add('nested-same-key');
  if (clauses.includes(effect)) events.add('forward');
  const callback = lambdas.at(-1);
  if (callback && find(callback.called, 'with', effect) === frame
    && find(callback.created, 'with', effect) !== frame) {
    events.add('escaped-callback');
  }
  const unwinding = state.pendingAbort.findLast(Boolean);
  if (unwinding && find(unwinding.registered, 'with', effect) === frame
    && find(unwinding.abort.ctx, 'with', effect) !== frame) {
    events.add('cleanup-registration-context');
  }
};

// The clause runs in the context outside its `with` (clause context).
export const perform = (state, callee, args, ctx) => {
  const frame = find(ctx, 'with', callee.effect);
  if (!frame) throw new OracleError(`no handler for ${callee.effect}`);
  note(state, callee.effect, frame, ctx);
  const clause = frame.handler.clauses.get(callee.name);
  const bound = new Map(frame.handler.env);
  clause.parameters.forEach((name, index) => {
    if (name !== null) bound.set(name, args[index]);
  });
  state.clauses.push(callee.effect);
  try {
    return state.evaluate(clause.body, bound,
      state.options.clauseContext === 'inner' ? ctx : frame.outer);
  } finally { state.clauses.pop(); }
};

export const evaluateWith = (state, node, env, ctx) => {
  const handler = state.evaluate(node.handler, env, ctx);
  if (!isHandler(handler)) throw new OracleError('with needs a handler');
  return state.evaluate(node.body, env,
    { kind: 'with', key: handler.effect, handler, outer: ctx });
};

// One frame per clause, the first innermost; fresh markers per activation.
export const evaluateHandle = (state, node, env, ctx) => {
  const markers = node.clauses.map(() => ({}));
  let inner = ctx;
  for (let index = node.clauses.length - 1; index >= 0; index--) {
    inner = { kind: 'fail', key: node.clauses[index].head,
      marker: markers[index], outer: inner };
  }
  try {
    return state.evaluate(node.body, env, inner);
  } catch (thrown) {
    if (!(thrown instanceof Abort)) throw thrown;
    const index = markers.indexOf(thrown.marker);
    if (index < 0) { state.events.add('abort-crosses-handle'); throw thrown; }
    state.caught++;
    const bound = new Map(env).set(node.clauses[index].name, thrown.payload);
    return state.evaluate(node.clauses[index].body, bound, ctx);
  }
};

export const evaluateBlock = (state, node, env, ctx) => {
  const defers = [];
  let scope = env;
  let outcome;
  try {
    for (const item of node.items) {
      if (item.tag === 'defer') {
        defers.push({ expression: item.value, env: scope, ctx });
        continue;
      }
      const value = state.evaluate(item.value, scope, ctx);
      if (item.tag === 'let' && item.name !== null) {
        scope = new Map(scope).set(item.name, value);
      }
    }
    outcome = { value: state.evaluate(node.value, scope, ctx) };
  } catch (thrown) {
    if (!(thrown instanceof Abort || thrown instanceof Defect)) throw thrown;
    outcome = { thrown };
  }
  return runCleanups(state, node.items, defers, outcome);
};
