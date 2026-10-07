import assert from 'node:assert/strict';
import test from 'node:test';
import { goTest, runGo, traceCalls } from './support.mjs';
import {
  choose, compare3, expressionOf, mixedGenerator, printValue, typeSystem,
  value
} from './value-oracle.mjs';

const list = 'type L = Nil | Cons(Int, L);';
const holds = (declarations, body) => assert.equal(
  runGo(`${declarations} fn main(): Bool = ${body};`), 'true\n', body
);

test('declared values order by constructor, then fields', () => {
  holds(list, 'Nil < Cons(0, Nil)');
  holds(list, 'Cons(1, Nil) > Cons(0, Cons(5, Nil))');
  holds(list, 'Cons(0, Nil) < Cons(0, Cons(0, Nil))');
  holds('type P = P(Bool, Int);', 'P(false, 9) < P(true, 0)');
});

test('separately built equal values are equal', () => {
  const built = `${list} fn a(): L = Cons(1, Nil); fn b(): L = Cons(1, Nil);`;
  holds(built, 'a() == b()');
  holds(built, '(a() < b()) == false');
});

test('8192-element lists compare without stack failure', () => {
  const source = `${list} `
    + 'fn append(a: L, b: L): L = '
    + 'match a { Nil => b, Cons(h, t) => Cons(h, append(t, b)) }; '
    + 'fn grow(n: Int, xs: L): L = '
    + 'match n { 13 => xs, _ => grow(n + 1, append(xs, xs)) }; '
    + 'fn bump(xs: L): L = match xs { Nil => Nil, '
    + 'Cons(h, Nil) => Cons(h + 1, Nil), Cons(h, t) => Cons(h, bump(t)) }; '
    + 'fn big(): L = grow(0, Cons(1, Nil));';
  holds(source, 'big() == big()');
  holds(source, 'big() < bump(big())');
});

test('a comparison on an uninhabited type builds', () => {
  assert.equal(runGo('type V = V(V); fn f(a: V, b: V): Bool = a < b; '
    + 'fn main(): Int = 0;'), '0\n');
});

const recovering = call => `package main
import ("fmt"; "testing")
func TestMalformed(t *testing.T) {
  defer func() {
    if got := fmt.Sprint(recover()); got != "sprig: malformed value" {
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
  passes(recovering('sprigCmp0(sprigTy0{tag: 2}, sprigTy0{tag: 2})'));
  passes(recovering('sprigCmp0(sprigTy0{}, sprigTy0{})'));
  passes(returning(
    'sprigCmp0(sprigTy0{tag: 2, c1f0: 1}, sprigTy0{tag: 2, c1f0: 2})', -1
  ));
  passes(recovering(
    'sprigCmp0(sprigTy0{tag: 2, c1f0: 1}, sprigTy0{tag: 2, c1f0: 1})'
  ));
});

test('declared operands evaluate once each, left first', () => {
  for (const op of ['<', '==']) {
    const source = `${list} fn l(): L = Cons(1, Nil); fn r(): L = Nil; `
      + `fn main(): Bool = l() ${op} r();`;
    // Function 2 is main; its operands l and r follow, once each.
    passes(`package main
import ("fmt"; "testing")
var sprigTrace []string
func TestTrace(t *testing.T) {
  sprigFn2()
  if got := fmt.Sprint(sprigTrace); got != "[2 0 1]" {
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

// Operands live in their own functions, and pairs are split across
// programs, because the stage 0 compiler overflows the JavaScript stack on
// sources of roughly 3500 characters (BACKLOG E002).
const sourceBudget = 2000;
const fragment = (system, pair, index) => {
  const terms = operators.map((op, bit) =>
    `(if l${index}() ${op} r${index}() then ${2 ** bit} else 0)`);
  return `fn l${index}(): T0 = ${printValue(system, pair.left)}; `
    + `fn r${index}(): T0 = ${pair.text}; `
    + `fn p${index}(): Int = ${terms.join(' + ')};`;
};
// Groups of consecutive pair indices whose fragments fit the budget.
const batches = (system, pairs) => {
  const groups = [[]];
  let size = system.declarations.length;
  pairs.forEach((pair, index) => {
    const length = fragment(system, pair, index).length;
    if (groups.at(-1).length > 0 && size + length > sourceBudget) {
      groups.push([]);
      size = system.declarations.length;
    }
    groups.at(-1).push(index);
    size += length;
  });
  return groups;
};

// Within a program, pair k declares l, r, then p: p is function 3k + 2.
const agrees = (system, pairs, orders, group) => {
  const fragments = group.map((pairIndex, local) =>
    fragment(system, pairs[pairIndex], local));
  const calls = group.map((_, local) => `sprigFn${3 * local + 2}()`);
  const masks = group.map(pairIndex => implied(orders[pairIndex]));
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
// field (T0 itself in 6, 22, 24, 34, 43; T1 in 29, 39, 47); together they
// cover each outcome on equal and differing constructors and a decision
// after the first field. The assertions below keep that true.
const seeds = [6, 22, 24, 29, 34, 39, 43, 47];

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
    for (const group of batches(system, pairs)) {
      agrees(system, pairs, orders, group);
    }
  }
  assert.deepEqual([...seen].sort(), [
    '-1 other', '-1 same', '0 same', '1 other', '1 same', 'later field'
  ]);
});
