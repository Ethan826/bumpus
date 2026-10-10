// The cleanup policy of the FX001 reference interpreter (design §3): a
// block's deferred expressions run LIFO, once, in their registration
// context; a pending abort reaches its `handle` only if every cleanup on
// the way completes normally; a cleanup defect turns a pending abort into
// the head of the report. Shares no code with the compiler.
import { printable, show, typeOfValue, typeText } from './fx-oracle-values.mjs';

export class Abort {
  constructor(marker, payload, ctx) { Object.assign(this, { marker, payload, ctx }); }
}
export class Defect {}
export class OracleError extends Error {}

const escaped = text => text.replaceAll('\n', '\\n');

// `fail(T): V`, or `<not printable>` when T has a function or handler.
export const abortLine = (program, abort) => {
  const type = typeOfValue(program, abort.payload);
  const text = printable(program, type) ? show(abort.payload)
    : '<not printable>';
  return escaped(`fail(${typeText(type)}): ${text}`);
};

export const crashLine = value => escaped(`crash: ${show(value)}`);

// Runs `defers` (registration order) for a block that exited with
// `outcome` ({ value } or { thrown }); returns the value or throws what
// is still pending. `state` is the interpreter's { program, causes, events,
// caught, evaluate }.
export const runCleanups = (state, items, defers, outcome) => {
  const { program, causes, events, evaluate } = state;
  if (defers.length < items.filter(item => item.tag === 'defer').length) {
    events.add('unreached-defer');
  }
  if (defers.length === 0) {
    if (outcome.thrown) throw outcome.thrown;
    return outcome.value;
  }
  let pending = outcome.thrown ?? null;
  const origin = pending instanceof Abort ? 'abort'
    : pending instanceof Defect ? 'defect' : 'normal';
  let crashes = 0;
  for (const deferred of [...defers].reverse()) {
    const before = causes.length;
    const caught = state.caught;
    state.pendingAbort.push(pending instanceof Abort ? pending : null);
    try {
      evaluate(deferred.expression, deferred.env, deferred.ctx);
    } catch (thrown) {
      if (thrown instanceof Abort) {
        throw new OracleError('typed abort escaped cleanup');
      }
      if (!(thrown instanceof Defect)) throw thrown;
      crashes++;
      if (pending instanceof Abort) {
        causes.splice(before, 0, abortLine(program, pending));
        events.add('cleanup-crash-abort');
      }
      pending = thrown;
      continue;
    } finally { state.pendingAbort.pop(); }
    if (pending instanceof Abort && state.caught > caught) {
      events.add('cleanup-own-fail-during-abort');
    }
  }
  if (crashes >= 2) events.add('cleanup-multi-crash');
  if (origin === 'normal' && crashes > 0) events.add('cleanup-crash-normal');
  else events.add(`cleanup-exit-${origin}`);
  if (pending) throw pending;
  return outcome.value;
};
