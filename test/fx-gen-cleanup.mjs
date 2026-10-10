// Designed cleanup scenarios of the FX001 corpus (spec §3 and §5 probe 6):
// every way a block with `defer` exits, and every combination of cleanup
// outcomes. A scenario marked `terminal` ends the program with a defect
// report, so the generator places it last. Cleanup expressions come from
// `cleanupExpr` (strict `defer`: they never fail unhandled); handlers in
// these scenarios have fail-free clauses, so the only abort is the one the
// scenario raises.
import {
  add, block, call, crash, deferItem, doItem, fail, handle, lit, local, log,
  print, tick, withHandler
} from './fx-gen-ast.mjs';
import {
  cleanupExpr, extend, families, failureClause, fresh, genBlock, logHandler,
  ownFailure, payload, safe, tickHandler
} from './fx-gen-expr.mjs';

const number = ctx => lit(ctx.r.number());
const defers = (ctx, count) => Array.from({ length: count },
  () => deferItem(cleanupExpr(ctx, 1)));
const filler = ctx => doItem(genBlock(safe(ctx), 1, 'Unit'));
const tidy = (ctx, items) => ctx.r.shuffle(items);
const guard = (ctx, family, body) =>
  handle(body, [failureClause(safe(ctx), family, 1)]);

// Nested blocks, each registering cleanups, around `core`.
const layers = (ctx, depth, core) => {
  const here = [...defers(ctx, 1 + ctx.r.int(2)), filler(ctx)];
  if (depth === 0) return block([...here, ...core]);
  return block([...here, doItem(layers(ctx, depth - 1, core))]);
};

const normal = ctx => layers(safe(ctx), ctx.r.int(3), []);

// The fail either sits in the body or in a function called under the handle
// (a block activation of its own).
const aborting = (ctx, items, family) => {
  const quiet = extend(safe(ctx), family);
  const raise = [filler(quiet), doItem(fail(payload(ctx, family))), filler(quiet)];
  const inner = layers(quiet, ctx.r.int(3), [...items, ...raise]);
  if (ctx.r.chance(50)) return guard(ctx, family, inner);
  const name = fresh(ctx, 'work');
  ctx.shared.extra.push({ name, params: [], ret: 'Unit', retText: 'Unit',
    row: new Set([family]), rowText: `Fail(${family}) + Console`, body: inner });
  return guard(ctx, family, call(name, [], 'Unit'));
};
const abort = ctx => aborting(ctx, [], ctx.r.pick(families));

// A cleanup that fails and handles it inside, even for the family whose
// abort is pending; or a named function failing under its own `handle`.
const ownCleanup = (ctx, family) => {
  const quiet = safe(ctx);
  if (family === 'Err' && ctx.r.chance(30)) {
    return deferItem(handle(block([doItem(call('risky', [number(ctx)], 'Int'))]),
      [failureClause(quiet, 'Err', 0)]));
  }
  return deferItem(ownFailure(quiet, 1));
};
const ownFailureDuringAbort = ctx => {
  const family = ctx.r.pick(families);
  const mine = ctx.r.chance(60) ? family : families.find(name => name !== family);
  return aborting(ctx, tidy(ctx, [ownCleanup(ctx, mine), ...defers(ctx, 1)]), family);
};

// Cleanups registered under different handlers while an abort comes from
// inside the innermost one.
const level = (ctx, index, family, last) => {
  const log0 = ctx.r.chance(50);
  const base = number(ctx);
  const sum = add(local('n'), base);
  const handler = log0 ? logHandler(ctx, 0, print(sum))
    : tickHandler(ctx, 0, sum);
  const use = log0 ? log(lit(index)) : print(tick(lit(index)));
  const inside = extend(ctx, log0 ? 'Log' : 'Tick');
  const next = index < last ? doItem(level(inside, index + 1, family, last))
    : doItem(fail(payload(ctx, family)));
  return withHandler(handler, block([deferItem(use), next]));
};
const registration = ctx => {
  const family = ctx.r.pick(families);
  const quiet = extend(safe(ctx), family);
  return guard(ctx, family, level(quiet, 0, family, 1 + ctx.r.int(2)));
};

// `defer`s after the raise never register.
const unreached = ctx => {
  const family = ctx.r.pick(families);
  const quiet = extend(safe(ctx), family);
  const late = defers(quiet, 2);
  const inner = block([...defers(quiet, 1), filler(quiet),
    doItem(fail(payload(ctx, family))), ...late]);
  return guard(ctx, family, ctx.r.chance(50) ? inner
    : block([deferItem(cleanupExpr(quiet, 1)), doItem(inner)]));
};

// Terminal scenarios: the report is the program's last act.
const crashing = ctx => deferItem(crash(number(ctx)));
const defect = ctx => {
  const quiet = safe(ctx);
  const body = layers(quiet, ctx.r.int(3),
    [filler(quiet), doItem(crash(number(ctx)))]);
  return ctx.r.chance(50) ? body : guard(ctx, ctx.r.pick(families), body);
};
const crashOnNormalExit = ctx => layers(safe(ctx), ctx.r.int(2),
  tidy(ctx, [crashing(ctx), ...defers(ctx, 1)]));
const crashWithAbort = ctx => aborting(ctx,
  tidy(ctx, [crashing(ctx), ...defers(ctx, 1)]), ctx.r.pick(families));
const severalCrashes = ctx => {
  const quiet = safe(ctx);
  const ends = ctx.r.chance(40) ? [doItem(crash(number(ctx)))] : [];
  const inner = block([crashing(ctx), crashing(ctx), filler(quiet), ...ends]);
  return block([crashing(ctx), ...defers(quiet, 1), doItem(inner),
    crashing(ctx)]);
};

export const cleanupFragments = [
  { name: 'cleanup-normal', make: normal },
  { name: 'cleanup-abort', make: abort },
  { name: 'cleanup-own-failure', make: ownFailureDuringAbort },
  { name: 'cleanup-registration', make: registration },
  { name: 'cleanup-unreached', make: unreached },
  { name: 'cleanup-defect', make: defect, terminal: true },
  { name: 'cleanup-crash-normal', make: crashOnNormalExit, terminal: true },
  { name: 'cleanup-crash-abort', make: crashWithAbort, terminal: true },
  { name: 'cleanup-several-crashes', make: severalCrashes, terminal: true }
];
