import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { checked, command, goTest, rejectedAt } from './support.mjs';
import { runGoBatch } from './go-batch.mjs';

const list = 'type IntList = Nil | Cons(Int, IntList);';
const sum = 'fn sum(xs: IntList): Int = '
  + 'match xs { Nil => 0, Cons(h, t) => h + sum(t) };';
// Every runGo-style execution in this file, built once (T001); run finds
// a source's case by its text, so each test still passes its own source.
const sources = {
  listSum: `${list} ${sum} `
    + 'fn main(): Int = sum(Cons(1, Cons(2, Cons(3, Nil))));',
  evaluator: 'type Exp = Lit(Int) | Plus(Exp, Exp); '
    + 'fn eval(e: Exp): Int = match e { '
    + 'Plus(Lit(n), Lit(m)) => n + m + 1000, '
    + 'Plus(a, b) => eval(a) + eval(b), Lit(n) => n }; '
    + 'fn main(): Int = eval(Plus(Plus(Lit(1), Lit(2)), '
    + 'Plus(Lit(3), Plus(Lit(4), Lit(5)))));',
  ints: 'fn sign(n: Int): Int = match n { -1 => 100, 0 => 20, _ => 3 }; '
    + 'fn main(): Int = sign(-1) + sign(0) + sign(7);',
  bools: 'fn pick(b: Bool): Int = match b { true => 1, false => 2 }; '
    + 'fn main(): Int = pick(false) + pick(true) + pick(false);',
  treeForest: 'type Tree = Node(Int, Forest); '
    + 'type Forest = Empty | More(Tree, Forest); '
    + 'fn size(t: Tree): Int = match t { Node(_, f) => 1 + forest(f) }; '
    + 'fn forest(f: Forest): Int = match f { Empty => 0, '
    + 'More(t, rest) => size(t) + forest(rest) }; '
    + 'fn main(): Int = size(Node(1, More(Node(2, Empty), '
    + 'More(Node(3, More(Node(4, Empty), Empty)), Empty))));',
  nested: `${list} fn f(xs: IntList): Int = `
    + 'match match xs { Nil => Cons(5, Nil), _ => xs } { '
    + 'Cons(h, t) => match t { Nil => h, Cons(g, _) => h + g }, Nil => 0 }; '
    + 'fn main(): Int = f(Nil) + f(Cons(1, Cons(2, Nil)));',
  shadow: `${list} fn f(x: Int, xs: IntList): Int = `
    + 'match xs { Cons(x, _) => x, Nil => x }; '
    + 'fn main(): Int = f(1, Cons(7, Nil)) + f(100, Nil);',
  localIds: `${list} fn f(x: Int, xs: IntList): Int = `
    + 'match match xs { Cons(x, t) => t, Nil => xs } { '
    + 'Cons(h, t) => match t { Cons(x, _) => x + h, Nil => x + h }, '
    + 'Nil => f(match xs { Cons(y, _) => y, Nil => x }, Nil) }; '
    + 'fn main(): Int = f(1, Cons(2, Cons(3, Nil)));',
  doubling: `${list} ${sum} `
    + 'fn append(a: IntList, b: IntList): IntList = '
    + 'match a { Nil => b, Cons(h, t) => Cons(h, append(t, b)) }; '
    + 'fn grow(n: Int, xs: IntList): IntList = '
    + 'match n { 13 => xs, _ => grow(n + 1, append(xs, xs)) }; '
    + 'fn main(): Int = sum(grow(0, Cons(1, Nil)));',
  trailingComma: `${list} fn main(): Int = `
    + 'match Cons(4, Nil) { Nil => 0, Cons(h, _) => h, };'
};
const batch = runGoBatch(import.meta.url, Object.entries(sources));
const run = source => batch.run(Object.keys(sources)
  .find(name => sources[name] === source)).trim();

test('a list sum runs', () => {
  const source = sources.listSum;
  assert.equal(run(source), '6');
});

test('an evaluator special-cases a nested pattern', () => {
  const source = sources.evaluator;
  assert.equal(run(source), '2015');
});

test('Int and Bool literal patterns select arms', () => {
  const ints = sources.ints;
  assert.equal(run(ints), '123');
  const bools = sources.bools;
  assert.equal(run(bools), '5');
});

test('mutually recursive Tree and Forest sizes', () => {
  const source = sources.treeForest;
  assert.equal(run(source), '4');
});

test('matches nest in arm bodies and in scrutinee position', () => {
  const source = sources.nested;
  assert.equal(run(source), '8');
});

test('a binder shadows a parameter only in its arm', () => {
  const source = sources.shadow;
  assert.equal(run(source), '107');
});

// Pins resolver numbering: parameters 0..n-1, then binders in source
// pre-order (scrutinee before arms, pattern before body), shadowing per arm:
// x = 2, t = 3 (inner scrutinee), h = 4, t = 5, x = 6, y = 7. Since E005 the
// text runs through bumpusFn0 and its lifted matches 0-3 in number order,
// so it also pins each match's captured parameters and call arguments.
test('LocalIds in emitted Go follow source pre-order', () => {
  const source = sources.localIds;
  const go = checked(source);
  const body = go.slice(go.indexOf('func bumpusFn0'),
    go.indexOf('func bumpusFn1'));
  const ids = body.match(/bumpusLocal\d+/g)
    .map(name => Number(name.slice('bumpusLocal'.length)));
  assert.deepEqual(ids, [
    0, 1, 0, 1, 1, 1, // bumpusFn0
    0, 1, 4, 4, 5, 5, 0, 4, 5, 0, 1, // Match0
    1, 2, 2, 3, 3, 3, 1, // Match1, the scrutinee's match
    0, 4, 6, 6, 6, 4, 0, 4, // Match2
    0, 7, 7, 7, 0 // Match3
  ]);
  assert.equal(run(source), '4');
});

test('an 8192-element list built by doubling sums correctly', () => {
  const source = sources.doubling;
  assert.equal(run(source), '8192');
});

test('a trailing comma is accepted', () => {
  const source = sources.trailingComma;
  assert.equal(run(source), '4');
});

test('patterns and matches are rejected precisely', () => {
  const color = 'type Color = Red | Green;';
  const f = body => `${list} ${color} fn f(xs: IntList, b: Bool): Int = `
    + `${body}; fn main(): Int = 0;`;
  const rows = [
    [f('match xs { Cons(q, Cons(q, _)) => q, _ => 0 }'), 'E_DUPLICATE', 'q'],
    [f('match xs { X => 0, _ => 1 }'), 'E_UNBOUND', 'X'],
    [f('match xs { Cons(h) => 0, _ => 1 }'), 'E_ARITY', 'Cons(h)'],
    [f('match xs { Cons(h) => zz, _ => 0 }'), 'E_ARITY', 'Cons(h)'],
    [`${list} fn f(xs: IntList): Int = match xs { Cons(h) => h, _ => 0 }; `
      + 'fn g(): Int = zz; fn main(): Int = 0;', 'E_ARITY', 'Cons(h)'],
    [f('match xs { Red => 0, _ => 1 }'), 'E_TYPE', 'Red', 1],
    [f('match b { 1 => 0, _ => 1 }'), 'E_TYPE', '1'],
    [f('match xs { Nil => 0, Cons(_, _) => true }'), 'E_TYPE', 'true'],
    // FN001 (design §9): applying a binder is checked by its type.
    [f('match xs { Cons(f, _) => f(1), Nil => 0 }'), 'E_TYPE', '1'],
    [f('match xs { Cons(z, _) => z, Nil => z }'), 'E_UNBOUND', 'z', 2],
    [f('1 + match xs { Nil => 0, _ => 1 }'), 'E_SYNTAX', 'match'],
    [f('match xs {}'), 'E_SYNTAX', '}']
  ];
  for (const [source, code, text, nth] of rows) {
    rejectedAt(source, code, text, nth ?? 0);
  }
});

// The same program is the nil-guard probe in test/regression.mjs; that copy
// is self-contained because it runs against restored-defect compilers.
const second = `${list} fn second(xs: IntList): Int = match xs `
  + '{ Nil => 0, Cons(_, Nil) => 1, Cons(_, Cons(y, _)) => y }; '
  + 'fn main(): Int = second(Nil);';
const recovering = (name, call, check) => `package main
import "testing"
func ${name}(t *testing.T) {
defer func() { r := recover(); ${check} }()
${call}
}
`;

test('malformed values reach the unmatched panic, never a nil error', () => {
  const check = 'if r != "bumpus: unmatched value" '
    + '{ t.Fatalf("recovered %v", r) }';
  for (const value of ['bumpusTy0{}', 'bumpusTy0{tag: 2}']) {
    const go = recovering('TestUnmatched', `bumpusFn0(${value})`, check);
    const result = goTest(second, go);
    assert.equal(result.status, 0, result.output);
  }
});

test('wildcards skip validation of a nil field', () => {
  const source = `${list} fn head(xs: IntList): Int = `
    + 'match xs { Cons(h, _) => h, Nil => 0 }; fn main(): Int = head(Nil);';
  const go = recovering('TestHead',
    'if v := bumpusFn0(bumpusTy0{tag: 2, c1f0: 5}); v != 5 '
    + '{ t.Fatalf("got %v", v) }',
    'if r != nil { t.Fatalf("panicked %v", r) }');
  const result = goTest(source, go);
  assert.equal(result.status, 0, result.output);
});

test('shapes example matches its snapshot and runs', () => {
  const source = readFileSync('examples/shapes.bumpus', 'utf8');
  assert.equal(checked(source), readFileSync('bootstrap/shapes.go', 'utf8'));
  assert.equal(command('node', ['scripts/bumpus.mjs', 'run',
    'examples/shapes.bumpus']), '120\n');
});
