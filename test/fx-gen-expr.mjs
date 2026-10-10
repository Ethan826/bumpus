// Random well-typed expressions, items and blocks for the FX001 corpus.
// The context tracks what is typed here: `labels` (the effects performable
// at this point: 'Log', 'Tick' and the failure families 'Err' and 'Oops'),
// the Int locals, and the named functions callable (their rows must be
// within `labels`). `safe` drops the failure families: cleanup and the
// filler of designed scenarios never fail by accident (strict `defer`).
import {
  add, block, call, deferItem, doItem, err, fail, handle, handler, letItem,
  lit, local, log, match, oops, print, tick, unit, withHandler
} from './fx-gen-ast.mjs';

export const families = ['Err', 'Oops'];
export const payload = (ctx, family) => (family === 'Err'
  ? err(ctx.r.number()) : oops(ctx.r.number()));
export const fresh = (ctx, prefix) => `${prefix}${ctx.shared.counter++}`;
export const extend = (ctx, ...labels) =>
  ({ ...ctx, labels: new Set([...ctx.labels, ...labels]) });
export const safe = ctx => ({ ...ctx,
  labels: new Set([...ctx.labels].filter(label => !families.includes(label))) });
export const bind = (ctx, ...names) =>
  ({ ...ctx, locals: [...ctx.locals, ...names] });

const callable = (ctx, ret) => ctx.fns.filter(fn => fn.ret === ret
  && [...fn.row].every(label => ctx.labels.has(label)));

export const intExpr = (ctx, depth) => {
  const options = [() => lit(ctx.r.number())];
  if (ctx.locals.length) options.push(() => local(ctx.r.pick(ctx.locals)));
  if (depth > 0) options.push(() => add(intExpr(ctx, depth - 1), intExpr(ctx, depth - 1)));
  if (depth > 0 && ctx.labels.has('Tick')) {
    options.push(() => tick(intExpr(ctx, depth - 1)));
  }
  const fns = callable(ctx, 'Int');
  if (depth > 0 && fns.length) {
    options.push(() => applyFn(ctx, ctx.r.pick(fns), depth - 1));
  }
  return ctx.r.pick(options)();
};

export const applyFn = (ctx, fn, depth) => call(fn.name,
  fn.params.map(() => intExpr(ctx, depth)), fn.ret);

export const unitExpr = (ctx, depth) => {
  const options = [() => print(intExpr(ctx, depth)), () => unit];
  if (ctx.labels.has('Log')) options.push(() => log(intExpr(ctx, depth)));
  const fns = callable(ctx, 'Unit');
  if (fns.length) options.push(() => applyFn(ctx, ctx.r.pick(fns), depth));
  return ctx.r.pick(options)();
};

// handler Log/Tick with a random clause; the clause runs in the outer
// context, so it sees `ctx.labels` only. A random clause never fails: a
// cleanup performing the operation would otherwise end in a typed abort
// (the hole in the strict `defer` rule, see the Task 10 report).
export const logHandler = (ctx, depth, clauseBody) => handler('Log', [{
  op: 'log', params: ['n'], body: clauseBody ?? unitExpr(bind(safe(ctx), 'n'), depth)
}]);
export const tickHandler = (ctx, depth, clauseBody) => handler('Tick', [{
  op: 'tick', params: ['n'], body: clauseBody ?? intExpr(bind(safe(ctx), 'n'), depth)
}]);

export const wrapLog = (ctx, depth) => withHandler(logHandler(ctx, 1),
  genBlock(extend(ctx, 'Log'), depth - 1, 'Unit'));
export const wrapTick = (ctx, depth) => withHandler(tickHandler(ctx, 1),
  genBlock(extend(ctx, 'Tick'), depth - 1, 'Unit'));

// `handle` of a family F around a block that may fail with F; the clause
// reads the payload sometimes.
export const wrapHandle = (ctx, depth) => {
  const family = ctx.r.pick(families);
  const inner = extend(ctx, family);
  const body = genBlock(inner, depth - 1, 'Unit');
  return handle(body, [failureClause(ctx, family, depth)]);
};

export const failureClause = (ctx, family, depth) => {
  const reader = ctx.r.chance(50);
  const arms = family === 'Err'
    ? [{ pattern: 'Err1(m)', body: print(add(local('m'), lit(ctx.r.number()))) },
      { pattern: 'Err2', body: print(lit(ctx.r.number())) }]
    : [{ pattern: 'Oops(m)', body: print(local('m')) }];
  const body = reader ? match(local('error', family), arms, 'Unit')
    : unitExpr(ctx, depth - 1);
  return { family, name: 'error', body };
};

// An abort of an installed family; the rest of the block is then dead code.
const failItem = ctx => {
  const family = ctx.r.pick(families.filter(name => ctx.labels.has(name)));
  return doItem(fail(payload(ctx, family)));
};

export const cleanupExpr = (ctx, depth) => {
  const quiet = safe(ctx);
  const options = [() => print(intExpr(quiet, 1)), () => unitExpr(quiet, 1),
    () => genBlock(quiet, depth - 1, 'Unit')];
  if (quiet.labels.has('Log')) options.push(() => log(intExpr(quiet, 1)));
  if (depth > 0) options.push(() => ownFailure(quiet, depth));
  return ctx.r.pick(options)();
};

// A cleanup that fails and handles its own failure: `handle fail(P) {..}`.
export const ownFailure = (ctx, depth) => {
  const family = ctx.r.pick(families);
  return handle(call('fail', [payload(ctx, family)], 'Unit'),
    [failureClause(ctx, family, depth)]);
};

const item = (ctx, depth) => {
  const options = [() => doItem(unitExpr(ctx, 2)),
    () => doItem(intExpr(ctx, 1))];
  if (depth > 0) {
    options.push(() => doItem(wrapLog(ctx, depth)),
      () => doItem(wrapTick(ctx, depth)), () => doItem(wrapHandle(ctx, depth)),
      () => deferItem(cleanupExpr(ctx, depth)));
  }
  if (families.some(name => ctx.labels.has(name)) && ctx.r.chance(10)) {
    options.push(() => failItem(ctx));
  }
  return ctx.r.pick(options)();
};

export const genBlock = (ctx, depth, ty) => {
  const items = [];
  let scope = ctx;
  for (let count = ctx.r.int(4); count > 0; count--) {
    if (ctx.r.chance(25)) {
      const name = fresh(ctx, 'v');
      items.push(letItem(name, intExpr(scope, 1)));
      scope = bind(scope, name);
    } else items.push(item(scope, depth));
  }
  return block(items, ty === 'Int' ? intExpr(scope, 2) : null);
};
