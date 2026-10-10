import assert from 'node:assert/strict';
import test from 'node:test';
import { goTest, traceCalls } from './support.mjs';
import { runGoBatch } from './go-batch.mjs';
import {
  choose, compare3, expressionOf, mixedGenerator, printValue, typeSystem,
  value
} from './value-oracle.mjs';

const list = 'type L = Nil | Cons(Int, L);';
const built = `${list} fn a(): L = Cons(1, Nil); fn b(): L = Cons(1, Nil);`;
const big = `${list} `
  + 'fn append(a: L, b: L): L = '
  + 'match a { Nil => b, Cons(h, t) => Cons(h, append(t, b)) }; '
  + 'fn grow(n: Int, xs: L): L = '
  + 'match n { 13 => xs, _ => grow(n + 1, append(xs, xs)) }; '
  + 'fn bump(xs: L): L = match xs { Nil => Nil, '
  + 'Cons(h, Nil) => Cons(h + 1, Nil), Cons(h, t) => Cons(h, bump(t)) }; '
  + 'fn big(): L = grow(0, Cons(1, Nil));';
const claims = [
  [list, 'Nil < Cons(0, Nil)'],
  [list, 'Cons(1, Nil) > Cons(0, Cons(5, Nil))'],
  [list, 'Cons(0, Nil) < Cons(0, Cons(0, Nil))'],
  ['type P = P(Bool, Int);', 'P(false, 9) < P(true, 0)'],
  [built, 'a() == b()'], [built, '(a() < b()) == false'],
  [big, 'big() == big()'], [big, 'big() < bump(big())']
];
// Every runGo-style execution in this file, built once (T001); a claim's
// case is named by its body, which is unique.
const batch = runGoBatch(import.meta.url, [
  ...claims.map(([declarations, body]) =>
    [body, `${declarations} fn main(): Bool = ${body};`]),
  ['uninhabited', 'type V = V(V); fn f(a: V, b: V): Bool = a < b; '
    + 'fn main(): Int = 0;']
]);
const holds = body => assert.equal(batch.run(body), 'true\n', body);

test('declared values order by constructor, then fields', () => {
  holds('Nil < Cons(0, Nil)');
  holds('Cons(1, Nil) > Cons(0, Cons(5, Nil))');
  holds('Cons(0, Nil) < Cons(0, Cons(0, Nil))');
  holds('P(false, 9) < P(true, 0)');
});

test('separately built equal values are equal', () => {
  holds('a() == b()');
  holds('(a() < b()) == false');
});

test('8192-element lists compare without stack failure', () => {
  holds('big() == big()');
  holds('big() < bump(big())');
});

test('a comparison on an uninhabited type builds', () => {
  assert.equal(batch.run('uninhabited'), '0\n');
});

const recovering = call => `package main
import ("fmt"; "testing")
func TestMalformed(t *testing.T) {
  defer func() {
    if got := fmt.Sprint(recover()); got != "waxwing: malformed value" {
      t.Fatalf("recovered %q", got)
    }
  }()
  fmt.Println(${call})
  t.Fatalf("no panic")
}
`;
const returning = (call, expected) => `package main
import "testing"
func TestReturns(t *testing.T) {
  if got := ${call}; got != ${expected} { t.Fatalf("got %d", got) }
}
`;
const passes = (
  testGo, source = `${list} fn main(): Int = 0;`, transform = undefined
) => {
  const result = goTest(source, testGo, transform);
  assert.equal(result.status, 0, result.output);
};

test('malformed values panic only when visited', () => {
  passes(recovering('waxwingCmp0(waxwingTy0{tag: 2}, waxwingTy0{tag: 2})'));
  passes(recovering('waxwingCmp0(waxwingTy0{}, waxwingTy0{})'));
  // One past the last tag: an off-by-one range check would return 0 here.
  passes(recovering('waxwingCmp0(waxwingTy0{tag: 3}, waxwingTy0{tag: 3})'));
  passes(returning(
    'waxwingCmp0(waxwingTy0{tag: 2, c1f0: 1}, waxwingTy0{tag: 2, c1f0: 2})', -1
  ));
  passes(recovering(
    'waxwingCmp0(waxwingTy0{tag: 2, c1f0: 1}, waxwingTy0{tag: 2, c1f0: 1})'
  ));
});

test('declared operands evaluate once each, left first', () => {
  for (const op of ['<', '==']) {
    const source = `${list} fn l(): L = Cons(1, Nil); fn r(): L = Nil; `
      + `fn main(): Bool = l() ${op} r();`;
    // Function 2 is main; its operands l and r follow, once each.
    passes(`package main
import ("fmt"; "testing")
var waxwingTrace []string
func TestTrace(t *testing.T) {
  waxwingFn2()
  if got := fmt.Sprint(waxwingTrace); got != "[2 0 1]" {
    t.Fatalf("trace %s", got)
  }
}
`, source, traceCalls);
  }
});

// Spec order of the six operators; bit i of a mask is operator i's result.
const operators = ['==', '!=', '<', '<=', '>', '>='];
const implied = order => [
  order === 0, order !== 0, order < 0, order <= 0, order > 0, order >= 0
].reduce((mask, bit, index) => mask + (bit ? 2 ** index : 0), 0);

// Replaces one field somewhere in v, so pairs often share long prefixes.
const mutate = (next, system, v, typeIndex, depth) => {
  const fields = system.types[typeIndex].ctors[v.ctor].fields;
  if (fields.length === 0 || depth <= 0) return value(next, system, typeIndex, depth);
  const at = choose(next, fields.length);
  const copy = [...v.fields];
  const field = fields[at];
  if (field === 'Int') copy[at] = choose(next, 2) ? copy[at] + 1 | 0 : next() | 0;
  else if (field === 'Bool') copy[at] = !copy[at];
  else copy[at] = mutate(next, system, copy[at], field, depth - 1);
  return { ctor: v.ctor, fields: copy };
};

const pairsFor = (next, system) => {
  const pairs = [];
  for (let index = 0; index < 8; index++) {
    const left = value(next, system, 0, 3);
    if (index < 2) {
      pairs.push({ left, right: left, text: expressionOf(next, system, left) });
      continue;
    }
    const right = choose(next, 2) ? mutate(next, system, left, 0, 3)
      : value(next, system, 0, 3);
    pairs.push({ left, right, text: printValue(system, right) });
  }
  return pairs;
};

const lawful = (system, values) => {
  const order = (a, b) => compare3(system, a, b);
  for (const a of values) {
    assert.equal(order(a, a), 0, 'reflexive');
    for (const b of values) {
      assert.ok([-1, 0, 1].includes(order(a, b)), 'total');
      assert.equal(order(a, b) + order(b, a), 0, 'antisymmetric');
      assert.equal(order(a, b) === 0, JSON.stringify(a) === JSON.stringify(b));
      for (const c of values) {
        if (order(a, b) <= 0 && order(b, c) <= 0) {
          assert.ok(order(a, c) <= 0, 'transitive');
        }
      }
    }
  }
};

// Operands live in their own functions so each pair is checked separately.
const fragment = (system, pair, index) => {
  const terms = operators.map((op, bit) =>
    `(if l${index}() ${op} r${index}() then ${2 ** bit} else 0)`);
  return `fn l${index}(): T0 = ${printValue(system, pair.left)}; `
    + `fn r${index}(): T0 = ${pair.text}; `
    + `fn p${index}(): Int = ${terms.join(' + ')};`;
};

// One program per seed; pair k declares l, r, then p: p is function 3k + 2.
const agrees = (system, pairs, orders) => {
  const fragments = pairs.map((pair, index) => fragment(system, pair, index));
  const calls = pairs.map((_, index) => `waxwingFn${3 * index + 2}()`);
  const masks = orders.map(implied);
  const source = `${system.declarations} ${fragments.join(' ')} `
    + 'fn main(): Int = 0;';
  const result = goTest(source, `package main
import ("fmt"; "testing")
func TestMasks(t *testing.T) {
  if got := fmt.Sprint(${calls.join(', ')}); got != "${masks.join(' ')}" {
    t.Fatalf("masks %s", got)
  }
}
`);
  assert.equal(result.status, 0, `${source}\n${result.output}`);
};

// The first field index at which a same-constructor pair differs, else -1.
const decidingField = (a, b) => a.ctor !== b.ctor ? -1
  : a.fields.findIndex((field, index) =>
    JSON.stringify(field) !== JSON.stringify(b.fields[index]));

// Seeds were chosen so every T0 has two or more constructors and a declared
// field (T0 itself in 0, 10, 19, 34; T1 in 2, 6; both in 17, 47); together
// they cover each outcome on equal and differing constructors and a decision
// after the first field. The assertions below keep that true. They were
// reselected when choose() moved to the LCG's high bits (A003 Task 3b).
const seeds = [0, 2, 6, 10, 17, 19, 34, 47];

test('generated pairs agree with the order interpreter', () => {
  const seen = new Set();
  for (const seed of seeds) {
    const next = mixedGenerator(seed);
    const system = typeSystem(next);
    const ctors = system.types[0].ctors;
    assert.ok(ctors.length >= 2, `seed ${seed}: one T0 constructor`);
    assert.ok(ctors.some(ctor => ctor.fields.some(field =>
      typeof field === 'number')), `seed ${seed}: no declared T0 field`);
    const pairs = pairsFor(next, system);
    lawful(system, pairs.flatMap(pair => [pair.left, pair.right]));
    const orders = pairs.map(pair =>
      compare3(system, pair.left, pair.right));
    pairs.forEach((pair, index) => {
      const same = pair.left.ctor === pair.right.ctor ? 'same' : 'other';
      seen.add(`${orders[index]} ${same}`);
      if (decidingField(pair.left, pair.right) > 0) seen.add('later field');
    });
    agrees(system, pairs, orders);
  }
  assert.deepEqual([...seen].sort(), [
    '-1 other', '-1 same', '0 same', '1 other', '1 same', 'later field'
  ]);
});
