// Seeded programs over function values for the FN001 execution oracle
// (Task 7, test/fn-oracle.test.mjs): higher-order prelude functions,
// lambdas (some with `_` parameters, some capturing match binders),
// partial and over-application of named functions, constructors and
// lambdas, constructor values and pipes, over List and Pair. Six types:
// Int, Bool, List(Int), Pair(Int, Bool), Int -> Int and Int -> Int -> Int.
// Generated functions call only earlier ones and the prelude recurses only
// on finite lists, so every program terminates.
import { choose, generator } from './coverage-oracle.mjs';

const prelude = 'type List(a) = Nil | Cons(a, List(a)); '
  + 'type Pair(a, b) = Pair(a, b); '
  + 'fn add(x: Int, y: Int): Int = x + y; '
  + 'fn adder(n: Int): Int -> Int = fn(x) => x + n; '
  + 'fn map(f: a -> b, xs: List(a)): List(b) = match xs { Nil => Nil, '
  + 'Cons(x, rest) => Cons(f(x), map(f, rest)) }; '
  + 'fn fold(f: b -> a -> b, acc: b, xs: List(a)): b = match xs { '
  + 'Nil => acc, Cons(x, rest) => fold(f, f(acc, x), rest) }; '
  + 'fn compose(f: b -> c, g: a -> b): a -> c = fn(x) => f(g(x)); '
  + 'fn flip(f: a -> b -> c): b -> a -> c = fn(y, x) => f(x, y);';

const INT = 'Int';
const BOOL = 'Bool';
const LIST = 'List(Int)';
const PAIR = 'Pair(Int, Bool)';
const F1 = 'Int -> Int';
const F2 = 'Int -> Int -> Int';
const parameterTypes = [INT, LIST, PAIR, F1, F2];
const resultTypes = [INT, LIST, PAIR, F1];
const functionCount = 4;
const bodyDepth = 3;
const argumentDepth = 2;

const pick = (next, items) => items[choose(next, items.length)];

// A generated function's curried type, when it is all Int.
const curried = signature => (signature.parameters.every(type => type === INT)
  ? `${'Int -> '.repeat(signature.parameters.length)}${signature.result}`
  : null);

const fresh = (scope, prefix) => `${prefix}${scope.counter.value++}`;
const within = (scope, locals) => ({
  ...scope, locals: [...scope.locals, ...locals]
});
const mark = (scope, feature, text) => {
  scope.features.add(feature);
  return text;
};

const literal = scope => String(choose(scope.next, 10));
const leaves = {
  [INT]: scope => [literal(scope)],
  [BOOL]: scope => [pick(scope.next, ['true', 'false'])],
  [LIST]: scope => ['Nil',
    `Cons(${literal(scope)}, Cons(${literal(scope)}, Nil))`],
  [PAIR]: scope => [`Pair(${literal(scope)}, true)`],
  [F1]: scope => [`add(${literal(scope)})`, `adder(${literal(scope)})`],
  [F2]: () => ['add']
};

// A lambda; `capture` when its body reads a match binder.
const lambda = (scope, parameters, type) => {
  const bound = parameters.filter(name => name !== '_')
    .map(name => ({ name, type: INT }));
  const body = expression(within(scope, bound), type, scope.depth - 1);
  if (scope.locals.some(local => local.binder
    && new RegExp(`\\b${local.name}\\b`).test(body))) {
    scope.features.add('capture');
  }
  if (parameters.includes('_')) scope.features.add('wildcard');
  return mark(scope, 'lambda', `fn(${parameters.join(', ')}) => ${body}`);
};

const listMatch = (scope, type) => {
  const head = fresh(scope, 'h');
  const tail = fresh(scope, 't');
  const inner = within(scope, [{ name: head, type: INT, binder: true },
    { name: tail, type: LIST, binder: true }]);
  return `match ${expression(scope, LIST, scope.depth - 1)} { Nil => `
    + `${expression(scope, type, scope.depth - 1)}, Cons(${head}, ${tail}) => `
    + `${expression(inner, type, scope.depth - 1)} }`;
};

// A lambda over a match binder, always.
const capturing = scope => {
  const head = fresh(scope, 'h');
  const parameter = fresh(scope, 'x');
  return mark(scope, 'capture', `match ${e(scope, LIST)} { Nil => `
    + `${e(scope, INT)}, Cons(${head}, rest) => (map(fn(${parameter}) => `
    + `${parameter} + ${head}, rest) |> fold(add, ${e(scope, INT)})) }`);
};

// Calls of earlier generated functions that produce `type`.
const calls = (scope, type) => scope.functions.flatMap(signature => {
  const args = () => signature.parameters.map(each =>
    expression(scope, each, scope.depth - 1)).join(', ');
  const forms = [];
  if (signature.result === type) {
    forms.push(() => `${signature.name}(${args()})`);
  }
  if (signature.result === F1 && type === INT) {
    forms.push(() => mark(scope, 'over',
      `${signature.name}(${args()}, ${e(scope, INT)})`));
  }
  if (curried(signature) === type) forms.push(() => signature.name);
  if (curried(signature) === F2 && type === F1) {
    forms.push(() => mark(scope, 'partial',
      `${signature.name}(${e(scope, INT)})`));
  }
  return forms;
});

const e = (scope, type) => expression(scope, type, scope.depth - 1);
const x = scope => fresh(scope, 'x');

const composites = {
  [INT]: s => [
    () => `${e(s, INT)} + ${e(s, INT)}`,
    () => `${e(s, F1)}(${e(s, INT)})`,
    () => `${e(s, F2)}(${e(s, INT)}, ${e(s, INT)})`,
    () => mark(s, 'partial', `${e(s, F2)}(${e(s, INT)})(${e(s, INT)})`),
    () => mark(s, 'over', `adder(${e(s, INT)}, ${e(s, INT)})`),
    () => mark(s, 'over', `compose(${e(s, F1)}, ${e(s, F1)}, ${e(s, INT)})`),
    () => mark(s, 'over', `flip(${e(s, F2)}, ${e(s, INT)}, ${e(s, INT)})`),
    () => mark(s, 'pipe', `${e(s, INT)} |> ${e(s, F1)}`),
    () => mark(s, 'pipe', `${e(s, INT)} |> add(${e(s, INT)})`),
    () => mark(s, 'pipe', `${e(s, INT)} |> flip(${e(s, F2)}, ${e(s, INT)})`),
    () => `fold(${e(s, F2)}, ${e(s, INT)}, ${e(s, LIST)})`,
    () => mark(s, 'pipe', `${e(s, LIST)} |> fold(${e(s, F2)}, ${e(s, INT)})`),
    () => listMatch(s, INT),
    () => capturing(s),
    () => `if ${e(s, BOOL)} then ${e(s, INT)} else ${e(s, INT)}`,
    () => `(${lambda(s, [x(s)], INT)})(${e(s, INT)})`
  ],
  [BOOL]: s => [
    () => `${e(s, INT)} < ${e(s, INT)}`,
    () => `${e(s, INT)} == ${e(s, INT)}`,
    () => `match ${e(s, PAIR)} { Pair(_, b) => b }`
  ],
  [LIST]: s => [
    () => `Cons(${e(s, INT)}, ${e(s, LIST)})`,
    () => `map(${e(s, F1)}, ${e(s, LIST)})`,
    () => mark(s, 'pipe', `${e(s, LIST)} |> map(${e(s, F1)})`),
    () => mark(s, 'constructor', `fold(flip(Cons), ${e(s, LIST)}, `
      + `${e(s, LIST)})`),
    () => listMatch(s, LIST)
  ],
  [PAIR]: s => [
    () => `Pair(${e(s, INT)}, ${e(s, BOOL)})`,
    () => mark(s, 'constructor', `Pair(${e(s, INT)})(${e(s, BOOL)})`),
    () => mark(s, 'pipe', `${e(s, BOOL)} |> Pair(${e(s, INT)})`)
  ],
  [F1]: s => [
    () => lambda(s, [x(s)], INT),
    () => lambda(s, ['_'], INT),
    () => `compose(${e(s, F1)}, ${e(s, F1)})`,
    () => mark(s, 'over', `flip(${e(s, F2)}, ${e(s, INT)})`),
    () => mark(s, 'partial', `${e(s, F2)}(${e(s, INT)})`)
  ],
  [F2]: s => [
    () => lambda(s, [x(s), x(s)], INT),
    () => lambda(s, ['_', x(s)], INT),
    () => lambda(s, [x(s)], F1),
    () => `flip(${e(s, F2)})`,
    // A partial `compose` taking the function `adder` (not a constructor).
    () => mark(s, 'partial', `compose(adder, ${e(s, F1)})`)
  ]
};

// Composite forms are parenthesized, so any of them can be an operand.
function expression(scope, type, depth) {
  const here = { ...scope, depth };
  const locals = scope.locals.filter(local => local.type === type)
    .map(local => () => local.name);
  const simple = [...leaves[type](here).map(text => () => text), ...locals];
  if (depth <= 0 || choose(scope.next, 4) === 0) {
    return pick(scope.next, simple)();
  }
  const forms = [...composites[type](here), ...calls(here, type)];
  return `(${pick(scope.next, forms)()})`;
}

const drawSignature = (next, index) => ({
  name: `g${index}`, result: pick(next, resultTypes),
  parameters: Array.from({ length: 1 + choose(next, 3) },
    () => pick(next, parameterTypes))
});

const mainCall = (scope, signature) => {
  const args = signature.parameters.map(type =>
    expression(scope, type, argumentDepth)).join(', ');
  if (signature.result !== F1) {
    return { text: `${signature.name}(${args})`, type: signature.result };
  }
  const extra = literal(scope);
  return { type: INT, text: choose(scope.next, 2)
    ? `${signature.name}(${args}, ${extra})`
    : `${signature.name}(${args})(${extra})` };
};

// One program from `seed`: { seed, source, features }.
export const drawProgram = seed => {
  const next = generator(seed);
  const scope = { next, locals: [], functions: [], counter: { value: 0 },
    features: new Set() };
  const declarations = [prelude];
  for (let index = 0; index < functionCount; index++) {
    const signature = drawSignature(next, index);
    const inner = within(scope, signature.parameters.map((type, position) =>
      ({ name: `p${position}`, type })));
    const parameters = signature.parameters.map((type, position) =>
      `p${position}: ${type}`).join(', ');
    declarations.push(`fn ${signature.name}(${parameters}): `
      + `${signature.result} = ${expression(inner, signature.result,
        bodyDepth)};`);
    scope.functions.push(signature);
  }
  const made = scope.functions.map(signature => mainCall(scope, signature));
  const last = made.pop();
  const result = made.reduceRight((inner, call) => ({
    text: `Pair(${call.text}, ${inner.text})`,
    type: `Pair(${call.type}, ${inner.type})`
  }), last);
  declarations.push(`fn main(): ${result.type} = ${result.text};`);
  return { seed, source: declarations.join(' '), features: scope.features };
};

export const programCount = 30;
const firstSeed = 0x7a11;
export const programs = Array.from({ length: programCount },
  (_, index) => drawProgram(firstSeed + index));
