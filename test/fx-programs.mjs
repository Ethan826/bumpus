// Generator of well-typed FX001 programs over two user effects (Log and
// Tick), two failure families (Err and Oops) and Console traces. A program
// is a random main block of designed scenarios (test/fx-gen-fragments.mjs,
// test/fx-gen-cleanup.mjs) among random items (test/fx-gen-expr.mjs); the
// scenarios guarantee the census. `generate(seed)` returns { seed, source,
// tree } and is a pure function of the seed.
import { block, doItem, text } from './fx-gen-ast.mjs';
import { cleanupFragments } from './fx-gen-cleanup.mjs';
import { genBlock, intExpr, unitExpr } from './fx-gen-expr.mjs';
import { crossing, escaping, nested, stages } from './fx-gen-fragments.mjs';
import { rng } from './fx-gen-rng.mjs';

export const fragments = [
  { name: 'nested', make: nested }, { name: 'crossing', make: crossing },
  { name: 'stages', make: stages }, { name: 'escaping', make: escaping },
  ...cleanupFragments
];
const regular = fragments.filter(fragment => !fragment.terminal);

export const prelude = 'type Err = Err1(Int) | Err2; type Oops = Oops(Int); '
  + 'effect Log { fn log(n: Int): Unit; }; '
  + 'effect Tick { fn tick(n: Int): Int; }; '
  + 'fn arg(n: Int): Int with Console = { print(n); n }; '
  + 'fn risky(n: Int): Int with Fail(Err) + Console = '
  + '{ print(n); fail(Err1(n)); n };';
const known = [
  { name: 'arg', params: [['n', 'Int']], ret: 'Int', row: new Set() },
  { name: 'risky', params: [['n', 'Int']], ret: 'Int', row: new Set(['Err']) }
];

const rowTexts = { Log: 'Log', Tick: 'Tick', Err: 'Fail(Err)', Oops: 'Fail(Oops)' };
const rowText = labels => ['Console', ...[...labels].map(label => rowTexts[label])]
  .join(' + ');

const randomFn = (ctx, index) => {
  const row = new Set(ctx.r.shuffle(['Log', 'Tick', 'Err', 'Oops'])
    .filter(() => ctx.r.chance(35)));
  const params = ['a', 'b'].slice(0, ctx.r.int(3)).map(name => [name, 'Int']);
  const ret = ctx.r.pick(['Int', 'Unit']);
  const inner = { ...ctx, labels: row, locals: params.map(([name]) => name) };
  return { name: `f${index}`, params, ret, retText: ret, row,
    rowText: rowText(row), body: genBlock(inner, 2, ret) };
};

const fnText = fn => `fn ${fn.name}(${fn.params.map(([name, type]) =>
  `${name}: ${type}`).join(', ')}): ${fn.retText}`
  + `${fn.rowText ? ` with ${fn.rowText}` : ''} = ${text(fn.body)};`;

// The program text: the fixed prelude, then the functions, then main.
export const render = ({ fns, main }) =>
  [prelude, ...fns.map(fnText), fnText(main)].join(' ');

// Focus scenarios by index: every scenario recurs, and a terminal one
// (it ends the program with a defect) is paired with a regular one.
const focusOf = index => {
  const first = fragments[index % fragments.length];
  const second = regular[(index * 5 + 3) % regular.length];
  return first.terminal ? [second, first] : [first, second];
};

const mainItems = (ctx, focus, extras) => {
  const regulars = ctx.r.shuffle([...focus.filter(f => !f.terminal), ...extras]);
  const items = regulars.map(fragment => doItem(fragment.make(ctx)));
  const noise = Array.from({ length: ctx.r.int(3) }, () => doItem(unitExpr(ctx, 2)));
  return ctx.r.shuffle([...items, ...noise]);
};

export const generate = (seed, index = seed) => {
  const r = rng(seed);
  const shared = { counter: 0, extra: [] };
  let ctx = { r, shared, labels: new Set(), locals: [], fns: [...known] };
  const own = [];
  for (let count = r.int(3), position = 0; position < count; position++) {
    const fn = randomFn(ctx, position);
    own.push(fn);
    ctx = { ...ctx, fns: [...ctx.fns, fn] };
  }
  const focus = focusOf(index);
  const extras = r.chance(40) ? [r.pick(regular)] : [];
  const items = mainItems(ctx, focus, extras);
  const terminal = focus.find(fragment => fragment.terminal);
  const ret = !terminal && r.chance(25) ? 'Int' : 'Unit';
  const ending = terminal ? [doItem(terminal.make(ctx))] : [];
  const value = ret === 'Int' ? intExpr(ctx, 2) : null;
  const body = block([...items, ...ending], value);
  const main = { name: 'main', params: [], retText: ret, rowText: 'Console',
    body };
  const program = { fns: [...own, ...shared.extra], main };
  return { seed, program, source: render(program),
    focus: focus.map(fragment => fragment.name) };
};
