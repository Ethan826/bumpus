import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';
import { checked, command, goTest, rejected, rejectedAt } from './support.mjs';
import { runGoBatch } from './go-batch.mjs';
import {
  expressionOf, mixedGenerator, parseValue, printValue, typeSystem, value
} from './value-oracle.mjs';

const list = 'type L = Nil | Cons(Int, L);';
const nested = 'Cons(-3, Cons(2147483647, Nil))';
const doubling = `${list} `
  + 'fn append(a: L, b: L): L = '
  + 'match a { Nil => b, Cons(h, t) => Cons(h, append(t, b)) }; '
  + 'fn grow(n: Int, xs: L): L = '
  + 'match n { 13 => xs, _ => grow(n + 1, append(xs, xs)) }; '
  + 'fn main(): L = grow(0, Cons(1, Nil));';

// Seeds were chosen so the values include a nullary constructor, several
// fields, nesting three deep, and a T1 inside T0; the assertions keep that.
// Reselected (18 and 30 for 39 and 40) when choose() moved to the LCG's high
// bits in A003 Task 3b, which changed every draw.
const seeds = [2, 8, 11, 17, 18, 22, 30, 34];
const drawn = seeds.map(seed => {
  const next = mixedGenerator(seed);
  const system = typeSystem(next);
  const v = value(next, system, 0, 3);
  const main = text => `${system.declarations} fn main(): T0 = ${text};`;
  const original = main(expressionOf(next, system, v));
  return { seed, system, v, main, original };
});

// Every first-generation execution in this file, built once (T001). The
// reprints depend on these outputs, so they form a second batch.
const batch = runGoBatch(import.meta.url, [
  ['nested', `${list} fn main(): L = ${nested};`],
  ['nullary', 'type N = N; fn main(): N = N;'],
  ['fields', 'type P = P(Bool, Int); fn main(): P = P(false, -1);'],
  ['int', 'fn main(): Int = 42;'],
  ['bool', 'fn main(): Bool = 1 < 2;'],
  ['doubling', doubling],
  ...drawn.map(({ seed, original }) => [`seed ${seed}`, original])
]);

test('main prints a declared value as an expression', () => {
  assert.equal(batch.run('nested'), `${nested}\n`);
  assert.equal(batch.run('nullary'), 'N\n');
  assert.equal(batch.run('fields'), 'P(false, -1)\n');
});

test('Int and Bool mains print as before', () => {
  assert.equal(batch.run('int'), '42\n');
  assert.equal(batch.run('bool'), 'true\n');
});

test('main is still required and takes no parameters', () => {
  assert.equal(rejected('fn x(): Int = 1;', 'E_ENTRY').message,
    'Expected fn main()');
  const source = `${list} fn main(x: Int): L = Nil;`;
  assert.equal(rejectedAt(source, 'E_ENTRY', 'fn main(x: Int): L = Nil;')
    .message, 'main must have no parameters');
});

test('an 8192-element list prints without stack failure', () => {
  const length = 8192;
  assert.equal(batch.run('doubling'),
    `${'Cons(1, '.repeat(length)}Nil${')'.repeat(length)}\n`);
});

const recovering = call => `package main
import ("fmt"; "testing")
func TestMalformed(t *testing.T) {
  defer func() {
    if got := fmt.Sprint(recover()); got != "waxwing: malformed value" {
      t.Fatalf("recovered %q", got)
    }
  }()
  fmt.Println(string(${call}))
  t.Fatalf("no panic")
}
`;

test('printing a malformed value panics', () => {
  const source = `${list} fn main(): L = Nil;`;
  for (const call of [
    'waxwingShow0(nil, waxwingTy0{tag: 2})',
    'waxwingShow0(nil, waxwingTy0{tag: 3})',
    'waxwingShow0(nil, waxwingTy0{})'
  ]) {
    const result = goTest(source, recovering(call));
    assert.equal(result.status, 0, `${call}\n${result.output}`);
  }
});

test('printed values recompile to the same value', () => {
  const printed = [];
  const outputs = [];
  for (const { seed, system, v } of drawn) {
    const output = batch.run(`seed ${seed}`);
    assert.ok(output.endsWith('\n'), `seed ${seed}: ${output}`);
    const text = output.slice(0, -1);
    assert.deepEqual(parseValue(system, text), v, `seed ${seed}: ${text}`);
    assert.equal(text, printValue(system, v), `seed ${seed}`);
    outputs.push(output);
    printed.push(text);
  }
  const reprints = runGoBatch(import.meta.url, drawn.map(
    ({ seed, main }, index) => [`seed ${seed}`, main(printed[index])]),
  'reprint');
  drawn.forEach(({ seed }, index) => {
    assert.equal(reprints.run(`seed ${seed}`), outputs[index],
      `seed ${seed}: reprint`);
  });
  assert.ok(printed.some(text => !text.includes('(')), 'nullary');
  assert.ok(printed.some(text => /\(.*\(.*\(/.test(text)), 'nested');
  assert.ok(printed.some(text => text.includes(', ')), 'several fields');
  assert.ok(printed.some(text => text.includes('K1_')), 'T1 inside T0');
});

test('tree example matches its snapshot and runs', () => {
  const source = readFileSync('examples/tree.wxw', 'utf8');
  assert.equal(checked(source), readFileSync('bootstrap/tree.go', 'utf8'));
  assert.equal(command('node', ['scripts/waxwing.mjs', 'run',
    'examples/tree.wxw']),
    'Node(Node(Node(Leaf, 1, Leaf), 3, Leaf), 5, Node(Leaf, 8, Leaf))\n');
});
