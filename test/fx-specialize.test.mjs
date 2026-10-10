import test from 'node:test';
import assert from 'node:assert/strict';
import { Right } from '../output/Data.Either/index.js';
import { specialize } from '../output/Features.Specialize/index.js';
import { compile } from '../output/Program.Compile/index.js';
import { checkedPoly, checkRejectedAt } from './phases.mjs';
import { keyTexts } from './poly-keys.mjs';
import { specialized } from './fx-task7-programs.mjs';
import { runGo } from './support.mjs';

// FX001 Task 6 (design §4 "Specialization keys and dependencies", "Layout
// dependencies"), through Specialize called directly; the last tests run
// the CLI pipeline, which lowers every effect node since Task 7.
const list = 'type List(a) = Nil | Cons(a, List(a)); type Box(a) = Box(a); ';
const clock = 'effect Clock { fn now(): Int; }; ';
const state = 'effect State(s) { fn get(): s; fn put(value: s): Unit; }; ';
const main = ' fn main(): Int = 0;';
const code = 'E_SPECIALIZATION';

const keysOf = (source, pattern) => keyTexts(source)
  .filter(key => pattern.test(key)).sort();

test('recursive handler installation yields one function key', () => {
  const source = clock + 'fn loop(x: a, n: Int): a with Clock = '
    + 'if n > 3 then x else with handler Clock { now() => n } '
    + '{ { now(); loop(x, n + 1) } }; fn main(): Int = '
    + 'with handler Clock { now() => 0 } { loop(1, now()) };';
  assert.deepEqual(keysOf(source, /^fn loop/), ['fn loop[Int]']);
  assert.deepEqual(keysOf(source, /^effect/), ['effect Clock[]']);
});

test('growing-label recursion is rejected by the instantiation rule', () => {
  const source = list + state + 'fn listState(v: List(a)): '
    + 'Handler(State(List(a))) = handler State(List(a)) '
    + '{ get() => v, put(value) => () }; '
    + 'fn r(): Unit with State(a) + ...e = { let v = get(); '
    + 'with listState(Cons(v, Nil)) { r() } };' + main;
  const diagnostic = checkRejectedAt(source, code, 'r()', 1);
  assert.equal(diagnostic.message,
    'Recursive call to r changes its type arguments');
});

// [name, program, offending text, its occurrence, message]
const layoutCycles = [
  ['Grow', 'effect Grow(a) { fn next(): Handler(Grow(Box(a))); };',
    'Grow(Box(a))', 'Recursive use of Grow changes its type arguments'],
  ['the mutual pair', 'effect A(x) { fn f(): Handler(B(Box(x))); }; '
    + 'effect B(y) { fn g(): Handler(A(y)); };', 'B(Box(x))',
  'Recursive use of B changes its type arguments'],
  ['the data/effect cycle', 'type T(a) = T(Handler(G(List(a)))); '
    + 'effect G(a) { fn h(): T(a); };', 'G(List(a))',
  'Recursive use of G changes its type arguments'],
  ['an operation parameter', 'effect P(a) { fn give(h: Handler(P(Box(a))))'
    + ': Int; };', 'P(Box(a))', 'Recursive use of P changes its type arguments']
];

for (const [name, program, text, message] of layoutCycles) {
  test(`layout cycle rejected: ${name}`, () => {
    const diagnostic = checkRejectedAt(list + program + main, code, text);
    assert.equal(diagnostic.message, message);
  });
}

const bareCycles = [
  ['Grow', 'effect Grow(a) { fn next(): Handler(Grow(a)); };'],
  ['the mutual pair', 'effect A(x) { fn f(): Handler(B(x)); }; '
    + 'effect B(y) { fn g(): Handler(A(y)); };'],
  ['the data/effect cycle', 'type T(a) = T(Handler(G(a))); '
    + 'effect G(a) { fn h(): T(a); };']
];

for (const [name, program] of bareCycles) {
  test(`bare-parameter layout accepted and compiled: ${name}`, () => {
    const result = compile(list + program + main);
    assert.ok(result instanceof Right, JSON.stringify(result));
  });
}

// The result's handler row is `pure`: a bare `Handler(Grow(Int))` result
// would share grow's ambient row, which the clause's `next` result (an
// operation type, so `pure`) cannot match (design §1, §2).
test('a Grow handler at bare parameters makes one effect key', () => {
  const source = list + 'effect Grow(a) { fn next(): Handler(Grow(a)); }; '
    + 'fn grow(): Handler(Grow(Int) with pure) = handler Grow(Int) '
    + '{ next() => grow() };' + main;
  assert.deepEqual(keysOf(source, /^effect/), ['effect Grow[Int]']);
});

test('State(Int) and State(Bool) give two effect keys', () => {
  const source = state + 'fn nested(): Int = with handler State(Int) '
    + '{ get() => 1, put(value) => () } { with handler State(Bool) '
    + '{ get() => true, put(value) => () } { get(); }; get() };' + main;
  assert.deepEqual(keysOf(source, /^effect/),
    ['effect State[Bool]', 'effect State[Int]']);
});

test('effect keys reach operation types; handler fields reach effects', () => {
  const source = list + 'effect Store(a) { fn load(): List(a); }; '
    + 'type Holder = Holder(Handler(Store(Bool)));' + main;
  const keys = keyTexts(source);
  assert.ok(keys.includes('effect Store[Bool]'), keys.join('\n'));
  assert.ok(keys.includes('type List[Bool]'), keys.join('\n'));
});

test('a performed operation reaches its effect key', () => {
  const source = list + state + 'fn f(): List(Bool) with State(List(Bool))'
    + ' = get();' + main;
  assert.deepEqual(keysOf(source, /^effect/), ['effect State[List(Bool)]']);
});

test('rows in data arguments give no extra type key', () => {
  const source = clock + 'effect Log { fn log(n: Int): Unit; }; '
    + 'type Job(a, ...effects) = Job(Int -> a with ...effects); '
    + 'fn keep(j: Job(Int, Log + Clock)): Int = 0; '
    + 'fn other(j: Job(Int, pure)): Int = 0;' + main;
  assert.deepEqual(keysOf(source, /^type Job/), ['type Job[Int]']);
});

test('a pure function used at three different rows is one key', () => {
  const source = clock + 'fn twice(f: a -> a, x: a): a = f(f(x)); '
    + 'fn main(): Int with Console = twice(fn(x) => x + 1, 0) '
    + '+ twice(fn(x) => { print(x); x }, 1) '
    + '+ (with handler Clock { now() => 2 } '
    + '{ twice(fn(x) => x + now(), 3) });';
  assert.deepEqual(keysOf(source, /^fn twice/), ['fn twice[Int]']);
});

// A variable that only a label mentions is still a type variable: the
// function is polymorphic, so it gets no copy until a use instantiates it.
test('a type variable only in the effect row makes a function generic', () => {
  const source = state + 'fn peek(): Unit with State(a) = '
    + '{ let v = get(); () };' + main;
  const result = specialize(checkedPoly(source));
  assert.ok(result instanceof Right, JSON.stringify(result));
  assert.deepEqual(
    result.value0.functions.map(definition => definition.name), ['main']);
});

// Task 7 deleted the post-Specialize guard: each program it stopped now
// builds and prints exactly what its handlers say.
test('programs holding every effect node but print run end to end', () => {
  for (const [, source, output] of specialized) {
    assert.equal(runGo(source), output);
  }
});

test('declared but unused effects reach Go unchanged', () => {
  const result = compile(clock + state + main);
  assert.ok(result instanceof Right, JSON.stringify(result));
  assert.ok(!result.value0.includes('ctx'));
});
