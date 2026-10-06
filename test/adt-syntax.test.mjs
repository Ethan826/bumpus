import test from 'node:test';
import assert from 'node:assert/strict';
import { parse } from '../output/Sprig.Parse/index.js';
import { lex } from '../output/Sprig.Lex/index.js';
import { Right } from '../output/Data.Either/index.js';
import { rejectedAt, rejected, spanAt } from './support.mjs';

const parsed = source => {
  const result = parse(source);
  assert.ok(result instanceof Right, JSON.stringify(result));
  return result.value0;
};

test('type declarations parse with constructors, fields and spans', () => {
  const source = 'type IntList = Nil | Cons(Int, IntList);';
  const { types, functions } = parsed(source);
  assert.equal(functions.length, 0);
  assert.equal(types.length, 1);
  assert.deepEqual(types[0].ctors.map(ctor => ctor.name), ['Nil', 'Cons']);
  assert.equal(types[0].ctors[1].fields[1].value1, 'IntList');
  assert.equal(types[0].span.start.offset, 0);
  assert.equal(types[0].span.end.offset, source.length);
  assert.deepEqual(types[0].ctors[0].span, spanAt(source, 'Nil'));
  assert.deepEqual(types[0].ctors[1].span, spanAt(source, 'Cons(Int, IntList)'));
});

test('mutually referring types parse in either order', () => {
  const tree = 'type Tree = Node(Int, Forest);';
  const forest = 'type Forest = Empty | More(Tree, Forest);';
  assert.deepEqual(parsed(`${tree} ${forest}`).types.map(t => t.name), ['Tree', 'Forest']);
  assert.deepEqual(parsed(`${forest} ${tree}`).types.map(t => t.name), ['Forest', 'Tree']);
});

test('declarations and functions interleave', () => {
  const program = parsed('fn main(): Int = 1; type T = A;');
  assert.equal(program.functions.length, 1);
  assert.equal(program.types.length, 1);
});

test('malformed type declarations are rejected at the offending token', () => {
  rejectedAt('type shape = A;', 'E_SYNTAX', 'shape');
  rejectedAt('type S = a;', 'E_SYNTAX', 'a');
  rejectedAt('type S = _A;', 'E_SYNTAX', '_A');
  rejectedAt('type S = A();', 'E_SYNTAX', ')');
});

test('reserved words and bad types are syntax errors', () => {
  for (const source of [
    'fn type(): Int = 1;', 'fn f(match: Int): Int = 1;',
    'fn f(_: Int): Int = 1;', 'fn main(): int = 1;'
  ]) rejected(source, 'E_SYNTAX');
});

test('a lone > is a lexical error', () => {
  rejected('fn main(): Int = 1 > 2;', 'E_LEX');
});

test('=> | { } lex as single tokens', () => {
  const result = lex('a=>b|{}');
  assert.ok(result instanceof Right);
  assert.deepEqual(result.value0.map(token => token.text), ['a', '=>', 'b', '|', '{', '}']);
});
