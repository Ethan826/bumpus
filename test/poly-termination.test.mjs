import test from 'node:test';
import assert from 'node:assert/strict';
import { Left, Right } from '../output/Data.Either/index.js';
import { check } from '../output/Features.Check/index.js';
import { components } from '../output/Features.Check.Components/index.js';
import { wire } from '../output/Format.Diagnostic/index.js';
import { generator } from './generators.mjs';
import { checkRejectedAt, resolved } from './phases.mjs';
import { spanAt } from './support.mjs';
import {
  components as generated, groundArguments, groundTypes, render, wrapped
} from './poly-components.mjs';

// P001 Task 5: the instantiation rule (design §4.1), through Parse,
// Resolve and Check only; the CLI compiles no polymorphic program until
// Task 7.
const prelude = 'type List(a) = Nil | Cons(a, List(a));'
  + ' type Pair(a, b) = Pair(a, b); ';
const main = ' fn main(): Int = 0;';
const code = 'E_SPECIALIZATION';

const accepted = source => {
  const result = check(resolved(source));
  if (result instanceof Left) {
    assert.fail(`${source}\n${JSON.stringify(wire(result.value0))}`);
  }
  assert.ok(result instanceof Right);
};

// [name, program after the prelude]
const acceptedRows = [
  ['length(t)', 'fn length(xs: List(a)): Int = match xs { Nil => 0,'
    + ' Cons(_, t) => 1 + length(t) };' + main],
  ['mutual even and odd over List(a)', 'fn even(xs: List(a)): Bool ='
    + ' match xs { Nil => true, Cons(_, t) => odd(t) }; fn odd(xs: List(a)):'
    + ' Bool = match xs { Nil => false, Cons(_, t) => even(t) };' + main],
  ['swapping', 'fn f(x: a, y: b): Int = g(y, x);'
    + ' fn g(x: a, y: b): Int = f(y, x);' + main],
  ['dropping', 'fn f(x: a, y: b): Int = g(x); fn g(x: a): Int = f(x, x);'
    + main],
  ['ground substitution', 'fn f(x: a, y: b): Int = g(x, 1);'
    + ' fn g(x: a, y: b): Int = f(y, x);' + main],
  ['a hole is ground', 'fn f(x: a): Int = f(Nil);' + main],
  ['wrapping into another component', 'fn g(x: a): Int = 0;'
    + ' fn f(x: a): Int = g(Cons(x, Nil)) + f(x);' + main],
  ['Rose and Forest', 'type Rose(a) = Node(a, Forest(a));'
    + ' type Forest(a) = Empty | More(Rose(a), Forest(a));' + main],
  ['swapped type arguments', 'type T(a, b) = C(T(b, a)) | D;' + main],
  ['a variable wrapped by another component\'s type',
    'type Rose(a) = Node(a, List(Rose(a))); type Box(a) = Box(List(a));'
    + main]
];

for (const [name, program] of acceptedRows) {
  test(`accepted: ${name}`, () => accepted(prelude + program));
}

// [program after the prelude, offending text, its occurrence, message]
const rejectedRows = [
  ['fn f(x: a): Int = f(Cons(x, Nil));' + main, 'f(Cons(x, Nil))', 0,
    'Recursive call to f changes its type arguments'],
  ['fn f(x: a): Int = g(Cons(x, Nil)); fn g(x: a): Int = f(x);' + main,
    'g(Cons(x, Nil))', 0, 'Recursive call to g changes its type arguments'],
  // §4.3: finite (g fixes Int), but rejected by the simpler rule.
  ['fn f(x: a): Int = g(Cons(x, Nil)); fn g(x: b): Int = f(1);' + main,
    'g(Cons(x, Nil))', 0, 'Recursive call to g changes its type arguments'],
  ['fn f(x: a, y: b): Int = f(y, Pair(x, 1));' + main, 'f(y, Pair(x, 1))', 0,
    'Recursive call to f changes its type arguments'],
  // The first offending call in pre-order.
  ['fn f(x: a): Int = f(Cons(x, Nil)) + f(Cons(Cons(x, Nil), Nil));' + main,
    'f(Cons(x, Nil))', 0, 'Recursive call to f changes its type arguments'],
  ['type Nest(a) = Nil2 | Cons2(a, Nest(List(a)));' + main,
    'Nest(List(a))', 0, 'Recursive use of Nest changes its type arguments'],
  // The nested reference, not the whole field.
  ['type W(a) = W(List(W(Pair(Int, a)))) | E;' + main, 'W(Pair(Int, a))', 0,
    'Recursive use of W changes its type arguments'],
  ['type A(a) = A(B(List(a))) | AE; type B(a) = B(A(a)) | BE;' + main,
    'B(List(a))', 0, 'Recursive use of B changes its type arguments'],
  // Types are judged before functions.
  ['fn f(x: a): Int = f(Cons(x, Nil)); type Nest(a) = N | M(Nest(List(a)));'
    + main, 'Nest(List(a))', 0,
  'Recursive use of Nest changes its type arguments']
];

for (const [program, text, nth, message] of rejectedRows) {
  test(`E_SPECIALIZATION ${message}: ${program}`, () => {
    const diagnostic = checkRejectedAt(prelude + program, code, text, nth);
    assert.equal(diagnostic.message, message);
  });
}

// Generator sanity: the edges really mix the three kinds of argument.
test('generated components mix permutation, dropping and ground', () => {
  const edges = generated.flatMap(component => component.calls.flat());
  const variable = value => 'variable' in value;
  const permuted = edges.filter(edge => edge.arguments.some(
    (value, index) => variable(value) && value.variable !== index));
  const dropped = edges.filter(edge => edge.arguments.filter(variable)
    .length < edge.arguments.length);
  assert.ok(permuted.length > 0 && dropped.length > 0);
  const grounds = new Set(generated.flatMap(groundTypes));
  assert.deepEqual([...grounds].sort(),
    groundArguments.map(each => each.type).sort());
});

test('wrapping an intra-component argument is rejected', () => {
  const next = generator(0x77a9);
  for (const component of generated) {
    accepted(render(component).source);
    const variant = wrapped(component, next);
    const { source, calls } = render(variant.component);
    const { text, offset, callee } = calls[variant.call];
    const nth = source.slice(0, offset).split(text).length - 1;
    const diagnostic = checkRejectedAt(source, code, text, nth);
    assert.deepEqual(diagnostic.span, spanAt(source, text, nth));
    assert.equal(diagnostic.message, `Recursive call to `
      + `${component.functions[callee].name} changes its type arguments`);
  }
});

// Strongly connected components against mutual reachability by brute
// force, over seeded graphs including self loops and isolated nodes.
const reachability = graph => {
  const reach = graph.map((edges, from) => graph.map((_, to) =>
    from === to || edges.includes(to)));
  for (const middle of graph.keys()) {
    for (const from of graph.keys()) {
      for (const to of graph.keys()) {
        if (reach[from][middle] && reach[middle][to]) reach[from][to] = true;
      }
    }
  }
  return reach;
};

test('components agree with mutual reachability', () => {
  const next = generator(0x3c3c);
  const draw = count => (next() >>> 0) % count;
  const graphCount = 300;
  const maximumNodes = 10;
  const maximumEdges = 4;
  assert.deepEqual(components([]), []);
  for (let index = 0; index < graphCount; index++) {
    const nodes = 1 + draw(maximumNodes);
    const graph = Array.from({ length: nodes }, () => Array.from(
      { length: draw(maximumEdges) }, () => draw(nodes)));
    const found = components(graph);
    const reach = reachability(graph);
    for (const from of graph.keys()) {
      for (const to of graph.keys()) {
        assert.equal(found[from] === found[to],
          reach[from][to] && reach[to][from], JSON.stringify(graph));
      }
    }
  }
});

const longest = 20000;
const secondsLimit = 5;
const timed = work => {
  const started = performance.now();
  const result = work();
  const seconds = (performance.now() - started) / 1000;
  assert.ok(seconds < secondsLimit, `took ${seconds} s`);
  return result;
};

test('components are stack-safe on a 20,000-node chain and cycle', () => {
  const chain = Array.from({ length: longest }, (_, index) =>
    index + 1 < longest ? [index + 1] : []);
  assert.equal(new Set(timed(() => components(chain))).size, longest);
  const cycle = Array.from({ length: longest }, (_, index) =>
    [(index + 1) % longest]);
  assert.equal(new Set(timed(() => components(cycle))).size, 1);
});
