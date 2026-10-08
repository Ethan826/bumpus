import test from 'node:test';
import assert from 'node:assert/strict';
import { checked, rejectedAt } from './support.mjs';
import { runGoBatch } from './go-batch.mjs';

const list = 'type IntList = Nil | Cons(Int, IntList);';
// Every Go execution in this file, built once (T001).
const batch = runGoBatch(import.meta.url, [
  ['construction', `${list} fn ignore(xs: IntList): Int = 7; `
    + 'fn main(): Int = ignore(Cons(1, Cons(2, Nil)));'],
  ['mutual', 'fn size(t: Tree): Int = 5; '
    + 'fn main(): Int = size(Node(1, More(Node(2, Empty), Empty))); '
    + 'type Tree = Node(Int, Forest); '
    + 'type Forest = Empty | More(Tree, Forest);'],
  ['adtIf', `${list} fn wrap(flag: Bool): IntList = `
    + 'if flag then Cons(1, Nil) else Nil; '
    + 'fn head(xs: IntList): Int = match xs { Nil => 0, Cons(x, _) => x }; '
    + 'fn main(): Int = head(wrap(true)) + head(wrap(false)) '
    + '+ head(if false then Nil else Cons(7, Nil));'],
  ['shadowing', 'type T = Nil; fn f(Nil: Int): Int = Nil; '
    + 'fn main(): Int = f(9);'],
  ['adtMain', `${list} fn main(): IntList = Nil;`]
]);

test('construction builds and runs', () => {
  assert.equal(batch.run('construction').trim(), '7');
});

test('mutually recursive types resolve in any order', () => {
  assert.equal(batch.run('mutual').trim(), '5');
});

test('ADT-returning functions and ADT-typed if build and run', () => {
  assert.equal(batch.run('adtIf').trim(), '8');
});

test('a local shadows a nullary constructor', () => {
  assert.equal(batch.run('shadowing').trim(), '9');
});

test('Go declarations use the pinned bytes', () => {
  const go = checked(`${list} fn main(): Int = 1;`);
  assert.ok(go.includes(
    'type bumpusTy0 struct {\ntag uint32\nc1f0 int32\nc1f1 *bumpusTy0\n}\n'));
  assert.ok(go.includes(
    'func bumpusCtor0() bumpusTy0 { return bumpusTy0{tag: 1} }\n'));
  assert.ok(go.includes(
    'func bumpusCtor1(f0 int32, f1 bumpusTy0) bumpusTy0 '
    + '{ return bumpusTy0{tag: 2, c1f0: f0, c1f1: &f1} }\n'));
});

test('type and constructor declarations are rejected precisely', () => {
  const main = ' fn main(): Int = 1;';
  let source = `type T = A; type T = B;${main}`;
  rejectedAt(source, 'E_DUPLICATE', 'type T = A;');
  source = `type A = X; type B = X;${main}`;
  rejectedAt(source, 'E_DUPLICATE', 'X');
  source = 'type T = F; fn F(): Int = 1; fn main(): Int = 1;';
  rejectedAt(source, 'E_DUPLICATE', 'F');
  // The first declaration in source order is reported, whatever its kind.
  source = 'fn A(): Int = 1; type T = A; fn main(): Int = 1;';
  rejectedAt(source, 'E_DUPLICATE', 'fn A(): Int = 1;');
  for (const reserved of ['Int', 'Bool']) {
    rejectedAt(`type ${reserved} = A;${main}`, 'E_SYNTAX', reserved);
  }
  rejectedAt(`type T = Int;${main}`, 'E_SYNTAX', 'Int');
  source = `type T = C(Missing);${main}`;
  rejectedAt(source, 'E_UNBOUND', 'Missing');
  source = `${list} fn f(x: Missing): Int = 1;${main}`;
  rejectedAt(source, 'E_UNBOUND', 'Missing');
});

test('main may return a declared value', () => {
  assert.equal(batch.run('adtMain'), 'Nil\n');
});

test('construction expressions are rejected precisely', () => {
  const rows = [
    ['fn main(): Int = Cons;', 'E_ARITY', 'Cons', 1],
    ['fn main(): Int = Nil();', 'E_NOT_CALLABLE', 'Nil()'],
    ['fn main(): Int = Cons(1);', 'E_ARITY', 'Cons(1)'],
    ['fn main(): Int = Cons(true, Nil);', 'E_TYPE', 'true'],
    ['fn main(): Int = Foo(1);', 'E_UNBOUND', 'Foo(1)'],
    ['fn helper(): Int = 1; fn main(): Int = helper;', 'E_UNBOUND',
      'helper', 1]
  ];
  for (const [body, code, text, nth] of rows) {
    rejectedAt(`${list} ${body}`, code, text, nth ?? 0);
  }
});
