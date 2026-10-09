import test from 'node:test';
import assert from 'node:assert/strict';
import { Right } from '../output/Data.Either/index.js';
import { TBool } from '../output/Domain.Type/index.js';
import { specializeWith } from '../output/Features.Specialize/index.js';
import { emit } from '../output/Format.Go/index.js';
import { withLambdas } from './fn-lambdas.mjs';
import { runGoBatch } from './go-batch.mjs';
import { checkedPoly } from './phases.mjs';
import { programs } from './poly-programs.mjs';
import { checked } from './support.mjs';

// FN001 Task 6, Step 1b: function values executed through Go (design §5,
// §7, §13 rules 1-8). One Go batch; each case prints its expected value.
const lists = 'type List(a) = Nil | Cons(a, List(a)); '
  + 'type Maybe(a) = Nothing | Just(a); '
  + 'fn length(xs: List(a)): Int = match xs { Nil => 0, '
  + 'Cons(_, rest) => 1 + length(rest) }; '
  + 'fn add(x: Int, y: Int): Int = x + y; ';
const higher = lists
  + 'fn map(f: a -> b, xs: List(a)): List(b) = match xs { Nil => Nil, '
  + 'Cons(x, rest) => Cons(f(x), map(f, rest)) }; '
  + 'fn foldLeft(f: b -> a -> b, acc: b, xs: List(a)): b = match xs { '
  + 'Nil => acc, Cons(x, rest) => foldLeft(f, f(acc, x), rest) }; '
  + 'fn compose(f: b -> c, g: a -> b): a -> c = fn(x) => f(g(x)); '
  + 'fn flip(f: a -> b -> c): b -> a -> c = fn(y, x) => f(x, y); ';
const oneTwo = 'Cons(1, Cons(2, Nil))';

const ints = count => Array(count).fill('Int').join(', ');
const numbered = count => Array.from({ length: count },
  (_, index) => index + 1);
// A function summing `count` Int parameters, by a balanced tree of `+`
// (each `+` is a nesting level), used as a value and applied to 1…count.
const sum = (low, high) => (high - low === 1 ? `p${low}`
  : `(${sum(low, low + Math.floor((high - low) / 2))} + `
    + `${sum(low + Math.floor((high - low) / 2), high)})`);
const applied = count => `fn total(${numbered(count).map(index =>
  `p${index - 1}: Int`).join(', ')}): Int = ${sum(0, count)}; `
  + `fn use(f: (${ints(count)}) -> Int): Int = `
  + `f(${numbered(count).join(', ')}); fn main(): Int = use(total);`;

const timing = 'fn add(x: Int, y: Int): Int = x + y; '
  + 'fn stuck(n: Int): Int -> Int = stuck(n); '
  + 'fn drop1(f: Int -> Int): Int = 0; '
  + 'fn use(f: Int -> Int -> Int): Int = drop1(f(1)); ';

// [name, source, expected output]
const cases = [
  ['64 arguments inline', applied(64), '2080'],
  ['65 arguments in two helpers', applied(65), '2145'],
  ['three free locals, two parameters', lists
    + 'fn mk(a: Int, b: Bool, c: List(Int)): Int -> Int -> Int = '
    + 'fn(x, y) => if b then a + x + length(c) else y; '
    + `fn main(): Int = mk(1, true, ${oneTwo})(10, 20) `
    + `+ mk(1, false, Nil)(10, 20);`, '33'],
  ['three parameter types, value and direct', lists
    + 'fn pick(n: Int, b: Bool, xs: List(Int)): Int = '
    + 'if b then n else length(xs); '
    + 'fn apply3(f: Int -> Bool -> List(Int) -> Int): Int = '
    + `f(5, true, Nil); fn main(): Int = pick(1, false, ${oneTwo}) `
    + '+ apply3(pick);', '7'],
  ['map, fold and compose', higher + 'fn main(): List(Int) = '
    + `map(compose(add(1), fn(x) => x + x), ${oneTwo});`,
  'Cons(3, Cons(5, Nil))'],
  ['fold', higher + `fn main(): Int = foldLeft(add, 0, ${oneTwo});`, '3'],
  ['closures over parameters and binders', lists
    + 'fn adder(m: Maybe(Int), k: Int): Int -> Int = match m { '
    + 'Nothing => fn(x) => x + k, Just(n) => fn(x) => x + n }; '
    + 'fn main(): Int = adder(Just(5), 1)(10) + adder(Nothing, 100)(1);',
  '116'],
  ['returning closures', 'fn always(x: a): b -> a = fn(_) => x; '
    + 'fn main(): Int = always(7)(true) + always(always(1))(2)(false);',
  '8'],
  ['partial and over-application', 'fn add(x: Int, y: Int): Int = x + y; '
    + 'fn add3(a: Int, b: Int, c: Int): Int = a + b + c; '
    + 'fn k(x: Int): Int -> Int = add(x); '
    + 'fn main(): Int = add3(1)(2, 3) + add3(1, 2)(3) + k(1, 2) + k(1)(2);',
  '18'],
  ['use(add) prints 0', `${timing}fn main(): Int = use(add);`, '0'],
  ['constructor values', higher + 'fn main(): List(Maybe(Int)) = '
    + `map(Just, ${oneTwo});`, 'Cons(Just(1), Cons(Just(2), Nil))'],
  ['partial constructors', higher + 'fn main(): List(List(Int)) = '
    + 'map(Cons(1), Cons(Nil, Cons(Cons(2, Nil), Nil)));',
  'Cons(Cons(1, Nil), Cons(Cons(1, Cons(2, Nil)), Nil))'],
  ['a two-field constructor as a value', higher + 'fn main(): List(Int) = '
    + `foldLeft(flip(Cons), Nil, ${oneTwo});`, 'Cons(2, Cons(1, Nil))'],
  ['a lifted match inside a lambda', lists + 'fn main(): Int = '
    + '(fn(m, k) => match m { Nothing => k, Just(n) => n + k })(Just(4), 1)'
    + ' + (fn(m: Maybe(Int)) => match m { Nothing => 7, _ => 0 })(Nothing);',
  '12'],
  ['nested lambdas three deep', 'fn main(): Int = '
    + '(fn(a) => fn(b) => fn(c) => a + b + c + a)(1)(2, 3);', '7'],
  ['pipe chains', higher + 'fn main(): Int = '
    + `${oneTwo} |> map(add(10)) |> foldLeft(add, 0) |> add(1) `
    + '|> (fn(x) => x + 100) |> add(length(Nil));', '124'],
  ['pipes with literal, local and call operands', higher
    + 'fn twice(f: Int -> Int, x: Int): Int = x |> f |> f; '
    + 'fn main(): Int = 3 |> twice(add(1)) |> add(length(Cons(1, Nil)) '
    + '|> add(1));', '7'],
  ['a type with a function field', lists
    + 'type Handler = Handler(Int -> Int, Bool); '
    + 'type Box(a) = Box(a); '
    + 'fn run(h: Handler, x: Int): Int = match h { Handler(f, _) => f(x) }; '
    + 'fn open(b: Box(Int -> Int)): Int -> Int = match b { Box(f) => f }; '
    + 'fn main(): Int = run(Handler(add(2), true), 3) '
    + '+ open(Box(fn(x) => x + 1))(1);', '7']
];

// Task 5's representative-independence programs, executed with Int (as
// compiled) and with Bool as the hole representative.
const boolGo = source => {
  const result = specializeWith(TBool.value)(checkedPoly(source));
  assert.ok(result instanceof Right, 'specialized at Bool');
  return emit(result.value0);
};
const independent = programs.flatMap(({ source }, index) => {
  const lambdas = withLambdas(source);
  return [[`int${index}`, lambdas],
    [`bool${index}`, { source: lambdas, transform: () => boolGo(lambdas) }]];
});

const batch = runGoBatch(import.meta.url, [
  ...cases.map(([name, source]) => [name, source]), ...independent
]);

for (const [name, , expected] of cases) {
  test(`function values run: ${name}`, () => {
    assert.equal(batch.run(name), `${expected}\n`);
  });
}

const count = (go, pattern) => (go.match(pattern) ?? []).length;
const helpers = /^func waxwingFn\d+Apply\d+\(/gm;

test('an application longer than 64 arguments is split into helpers', () => {
  assert.equal(count(checked(applied(64)), helpers), 0);
  assert.equal(count(checked(applied(65)), helpers), 2);
});

test('a function used as a value and called directly has one body', () => {
  const [, source] = cases.find(([name]) =>
    name === 'three parameter types, value and direct');
  const go = checked(source);
  // Monomorphic functions first (add 0, pick 1), then length's copy; the
  // entry calls pick's one body.
  assert.equal(count(go, /^func waxwingFn1\(/gm), 1);
  assert.equal(count(go, /^func waxwingFn1Entry\(e any\) int32 \{$/gm), 1);
  assert.equal(count(go, /^return waxwingFn1\(a0\[0\], a1\[0\], a2\[0\]\)$/gm),
    1);
  assert.equal(count(go, /^type waxwingNode\d+ struct/gm), 3);
});

test('a lambda takes its free locals, then its parameters', () => {
  const [, source] = cases.find(([name]) =>
    name === 'three free locals, two parameters');
  // Monomorphic functions first (add 0, mk 1); locals a 0, b 1, c 2, x 3,
  // y 4.
  assert.match(checked(source), new RegExp('^func waxwingFn1Lambda0\\('
    + 'waxwingLocal0 int32, waxwingLocal1 bool, waxwingLocal2 waxwingTy\\d+, '
    + 'waxwingLocal3 int32, waxwingLocal4 int32\\) int32 \\{$', 'm'));
});

test('representative independence: unused lambda parameters as Int or Bool',
  () => {
    programs.forEach((_, index) => {
      assert.equal(batch.run(`bool${index}`), batch.run(`int${index}`),
        `program ${index}`);
    });
  });
