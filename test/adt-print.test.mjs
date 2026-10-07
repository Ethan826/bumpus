import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';
import {
  checked, command, goTest, rejected, rejectedAt, runGo
} from './support.mjs';
import {
  expressionOf, mixedGenerator, parseValue, printValue, typeSystem, value
} from './value-oracle.mjs';

const list = 'type L = Nil | Cons(Int, L);';

test('main prints a declared value as an expression', () => {
  const nested = 'Cons(-3, Cons(2147483647, Nil))';
  assert.equal(runGo(`${list} fn main(): L = ${nested};`), `${nested}\n`);
  assert.equal(runGo('type N = N; fn main(): N = N;'), 'N\n');
  assert.equal(runGo('type P = P(Bool, Int); fn main(): P = P(false, -1);'),
    'P(false, -1)\n');
});

test('Int and Bool mains print as before', () => {
  assert.equal(runGo('fn main(): Int = 42;'), '42\n');
  assert.equal(runGo('fn main(): Bool = 1 < 2;'), 'true\n');
});

test('main is still required and takes no parameters', () => {
  assert.equal(rejected('fn x(): Int = 1;', 'E_ENTRY').message,
    'Expected fn main()');
  const source = `${list} fn main(x: Int): L = Nil;`;
  assert.equal(rejectedAt(source, 'E_ENTRY', 'fn main(x: Int): L = Nil;')
    .message, 'main must have no parameters');
});

test('an 8192-element list prints without stack failure', () => {
  const source = `${list} `
    + 'fn append(a: L, b: L): L = '
    + 'match a { Nil => b, Cons(h, t) => Cons(h, append(t, b)) }; '
    + 'fn grow(n: Int, xs: L): L = '
    + 'match n { 13 => xs, _ => grow(n + 1, append(xs, xs)) }; '
    + 'fn main(): L = grow(0, Cons(1, Nil));';
  const length = 8192;
  assert.equal(runGo(source),
    `${'Cons(1, '.repeat(length)}Nil${')'.repeat(length)}\n`);
});

const recovering = call => `package main
import ("fmt"; "testing")
func TestMalformed(t *testing.T) {
  defer func() {
    if got := fmt.Sprint(recover()); got != "bumpus: malformed value" {
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
    'bumpusShow0(nil, bumpusTy0{tag: 2})',
    'bumpusShow0(nil, bumpusTy0{tag: 3})',
    'bumpusShow0(nil, bumpusTy0{})'
  ]) {
    const result = goTest(source, recovering(call));
    assert.equal(result.status, 0, `${call}\n${result.output}`);
  }
});

// Seeds were chosen so the values include a nullary constructor, several
// fields, nesting three deep, and a T1 inside T0; the assertions keep that.
// Reselected (18 and 30 for 39 and 40) when choose() moved to the LCG's high
// bits in A003 Task 3b, which changed every draw.
const seeds = [2, 8, 11, 17, 18, 22, 30, 34];

test('printed values recompile to the same value', () => {
  const printed = [];
  for (const seed of seeds) {
    const next = mixedGenerator(seed);
    const system = typeSystem(next);
    const v = value(next, system, 0, 3);
    const main = text => `${system.declarations} fn main(): T0 = ${text};`;
    const original = main(expressionOf(next, system, v));
    const output = runGo(original);
    assert.ok(output.endsWith('\n'), `seed ${seed}: ${output}`);
    const text = output.slice(0, -1);
    assert.deepEqual(parseValue(system, text), v, `seed ${seed}: ${text}`);
    assert.equal(text, printValue(system, v), `seed ${seed}`);
    assert.equal(runGo(main(text)), output, `seed ${seed}: reprint`);
    printed.push(text);
  }
  assert.ok(printed.some(text => !text.includes('(')), 'nullary');
  assert.ok(printed.some(text => /\(.*\(.*\(/.test(text)), 'nested');
  assert.ok(printed.some(text => text.includes(', ')), 'several fields');
  assert.ok(printed.some(text => text.includes('K1_')), 'T1 inside T0');
});

test('tree example matches its snapshot and runs', () => {
  const source = readFileSync('examples/tree.bumpus', 'utf8');
  assert.equal(checked(source), readFileSync('bootstrap/tree.go', 'utf8'));
  assert.equal(command('node', ['scripts/bumpus.mjs', 'run',
    'examples/tree.bumpus']),
    'Node(Node(Node(Leaf, 1, Leaf), 3, Leaf), 5, Node(Leaf, 8, Leaf))\n');
});
