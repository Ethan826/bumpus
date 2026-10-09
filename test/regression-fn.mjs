// FN001 regression probes, imported by test/regression.mjs; the rows are
// in scripts/regression-fn.mjs. Each probe compiles with the compiler
// under test only (support.mjs is imported for its Go-text helper,
// panicOnEntry, never for its compile).
import { panicOnEntry } from './support.mjs';

const fail = message => {
  console.error(message);
  process.exit(1);
};

const detected = context =>
  console.log(`${context.probe} regression detects the defect`);

// Duplicates rows of test/fn-timing.test.mjs (probes cannot share a
// test's helpers): each probe function panics on entry with its label,
// so the run prints exactly the label of the first body entered.
const timing = 'fn add(x: Int, y: Int): Int = x + y; '
  + 'fn stuck(n: Int): Int -> Int = stuck(n); '
  + 'fn drop1(f: Int -> Int): Int = 0; '
  + 'fn use(f: Int -> Int -> Int): Int = drop1(f(1)); ';
const ints = count => Array(count).fill('Int').join(', ');
const numbers = (count, at, text) => Array.from({ length: count },
  (_, index) => (index === at ? text : String(index + 1))).join(', ');

const enters = (source, pairs, label, failure) => context => {
  const result = context.compile(source);
  if (!(result instanceof context.Right)) fail(`${failure}: rejected`);
  const go = pairs.reduce(
    (text, [index, name]) => panicOnEntry(text, index, name), result.value0);
  const run = context.ran(go);
  const labels = [...run.output.matchAll(/waxwing-probe: (\w+)/g)]
    .map(match => match[1]);
  if (labels.join() !== label) fail(`${failure}: ${run.output}`);
  detected(context);
};

// The wire form of a rejection, or null when the program was accepted.
const rejects = (source, code, message, failure) => context => {
  const result = context.compile(source);
  const found = result instanceof context.Left
    ? context.wire(result.value0) : null;
  if (found === null || found.code !== code || found.message !== message) {
    fail(`${failure}: ${JSON.stringify(found)}`);
  }
  detected(context);
};

// A mutant may reject the program or emit Go that fails to build; either
// way the expected output is missing, and the reason is printed.
const runs = (source, expected, failure) => context => {
  let output;
  try { output = context.printed(source); } catch (error) {
    output = error.message;
  }
  if (output !== expected) fail(`${failure}: ${output}`);
  detected(context);
};

const pair = 'type Pair(a, b) = Pair(a, b); ';
const list = 'type List(a) = Nil | Cons(a, List(a)); ';

export const fnProbes = {
  'stage-value': enters(`${timing}fn main(): Int = use(stuck);`,
    [[1, 'stuck']], 'stuck', 'named value staged by its type'),
  'stage-lambda': enters(`${timing}fn main(): Int = use(fn(x) => stuck(x));`,
    [[1, 'stuck']], 'stuck', 'lambda staged by its type'),
  'partial-strict': enters('fn probe(n: Int): Int = n; '
    + 'fn k3(a: Int, b: Int, c: Int): Int = a; '
    + 'fn ignore(f: Int -> Int -> Int): Int = 0; '
    + 'fn main(): Int = ignore(k3(probe(1)));', [[0, 'probe']], 'probe',
  'partial arguments evaluated late'),
  'pipe-order': enters('fn probe1(n: Int): Int = n; '
    + 'fn probe2(n: Int): Int = n; fn g(a: Int, b: Int): Int = a + b; '
    + 'fn main(): Int = probe1(1) |> g(probe2(2));',
  [[0, 'probe1'], [1, 'probe2']], 'probe1',
  'pipe evaluated its left operand late'),
  // A lifted match inside a lambda reads the lambda's parameter.
  'lambda-capture': runs('fn apply(f: Int -> Int, x: Int): Int = f(x); '
    + 'fn main(): Int = apply(fn(x) => match x { 0 => 1, _ => x + 10 }, 5);',
  '15\n', 'lambda parameter captured'),
  'fun-compare': rejects('fn f(g: Int -> Int): Bool = g == g; '
    + 'fn main(): Int = 0;', 'E_TYPE', 'Type Int -> Int is not comparable',
  'function comparison accepted'),
  // w's body runs at its second stage, after argument 2 of 65 and before
  // argument 3's probe, as Task 1's order check (design §13 rule 6).
  'block-order': enters('fn probe2(n: Int): Int = n; '
    + `fn w(a: Int, b: Int): (${ints(63)}) -> Int = w(a, b); `
    + `fn use(f: (${ints(65)}) -> Int): Int = `
    + `f(${numbers(65, 2, 'probe2(3)')}); fn main(): Int = use(w);`,
  [[0, 'probe2'], [1, 'w']], 'w', 'helper evaluated its block early'),
  'value-edge': rejects(`${list}fn apply(f: a -> Int, x: a): Int = f(x); `
    + 'fn grow(x: a): Int = apply(fn(y) => grow(Cons(y, Nil)), x); '
    + 'fn main(): Int = grow(1);', 'E_SPECIALIZATION',
  'Recursive call to grow changes its type arguments',
  'recursion through a lambda accepted'),
  'functional-fixpoint': rejects('type Box = Box(Int -> Int); '
    + 'type Outer = Outer(Box); fn f(o: Outer): Bool = o == o; '
    + 'fn main(): Int = 0;', 'E_TYPE', 'Type Outer is not comparable',
  'indirectly functional type compared'),
  'arrow-key': runs(`${pair}fn id(x: a): a = x; `
    + 'fn inc(n: Int): Int = n + 1; '
    + 'fn pick(b: Bool): Int = if b then 1 else 0; '
    + 'fn main(): Pair(Int, Int) = Pair(id(inc)(1), id(pick)(true));',
  'Pair(2, 1)\n', 'arrow keys merged')
};
