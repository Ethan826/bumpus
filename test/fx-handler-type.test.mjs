import test from 'node:test';
import assert from 'node:assert/strict';
import { Left, Right } from '../output/Data.Either/index.js';
import { parse } from '../output/Format.Parse/index.js';
import { resolve } from '../output/Features.Resolve/index.js';
import { check } from '../output/Features.Check/index.js';
import { Just } from '../output/Data.Maybe/index.js';
import { NamedRef, THandlerRef } from '../output/Domain.Syntax/index.js';
import { wire } from '../output/Format.Diagnostic/index.js';

const checked = source => {
  const parsed = parse(source);
  if (parsed instanceof Left) return parsed;
  const resolved = resolve(parsed.value0);
  return resolved instanceof Left ? resolved : check(resolved.value0);
};
const accepted = source => {
  const result = checked(source);
  assert.ok(result instanceof Right, JSON.stringify(result));
};
const rejection = source => {
  const result = checked(source);
  assert.ok(result instanceof Left, source);
  return wire(result.value0);
};
const prelude = 'effect Clock { fn now(): Int; }; '
  + 'effect Tick { fn tick(): Handler(Clock); }; '
  + 'effect Log { fn log(): Unit; }; ';
const main = ' fn main(): Int = 0;';

const parameterType = source => {
  const parsed = parse(source);
  assert.ok(parsed instanceof Right, JSON.stringify(parsed));
  return parsed.value0.functions[0].parameters[0].ty;
};
const rowLabels = row => row.value0.value1.map(label => label.name);

test('Handler(Clock with pure) parses to THandlerRef with its row', () => {
  const found = parameterType(prelude
    + 'fn t(h: Handler(Clock with pure)): Int = 0;');
  assert.ok(found instanceof THandlerRef, JSON.stringify(found));
  assert.equal(found.value1.name, 'Clock');
  assert.ok(found.value2 instanceof Just);
  assert.deepEqual(rowLabels(found.value2), []);
});

test('Handler(Tick with Log) keeps Log in its row', () => {
  const found = parameterType(prelude
    + 'fn t(h: Handler(Tick with Log)): Int = 0;');
  assert.ok(found instanceof THandlerRef, JSON.stringify(found));
  assert.deepEqual(rowLabels(found.value2), ['Log']);
});

test('bare Handler(Clock) stays an ordinary application', () => {
  const found = parameterType(prelude + 'fn t(h: Handler(Clock)): Int = 0;');
  assert.ok(found instanceof NamedRef, JSON.stringify(found));
});

test('a pure handler argument is accepted where the clause returns it', () => {
  accepted(prelude + 'fn t(h: Handler(Clock with pure)): '
    + 'Handler(Tick with pure) = handler Tick { tick() => h };' + main);
});

test('a Log-performing clause fits Handler(Tick with Log)', () => {
  accepted(prelude + 'fn t(h: Handler(Clock with pure)): '
    + 'Handler(Tick with Log) = handler Tick { tick() => { log(); h } };'
    + main);
});

const spanText = (source, found) =>
  source.slice(found.span.start.offset, found.span.end.offset);

test('a Log-performing clause is rejected under with pure', () => {
  const source = prelude + 'fn t(h: Handler(Clock with pure)): '
    + 'Handler(Tick with pure) = handler Tick { tick() => { log(); h } };'
    + main;
  const found = rejection(source);
  assert.equal(found.code, 'E_EFFECT');
  assert.equal(found.message, 'This function must be pure, but it performs Log');
  assert.equal(spanText(source, found),
    'handler Tick { tick() => { log(); h } }');
});

test('a Log handler is not a pure handler parameter', () => {
  const source = prelude + 'fn run(h: Handler(Clock with pure)): '
    + 'Int = 0; fn t(g: Handler(Clock with Log)): Int = run(g);' + main;
  const found = rejection(source);
  assert.equal(found.code, 'E_EFFECT');
  assert.equal(found.message, 'This function must be pure, but it performs Log');
  assert.equal(spanText(source, found), 'g');
});

test('a parenthesized effect label is still accepted', () => {
  accepted(prelude + 'fn t(h: Handler((Clock))): Int = 0;' + main);
  accepted(prelude + 'fn t(h: Handler((Clock) with Log)): Int = 0;' + main);
});

test('a function type as Handler argument keeps its arity diagnostic', () => {
  const source = prelude + 'fn t(h: Handler(Int -> Int)): Int = 0;' + main;
  const found = rejection(source);
  assert.equal(found.code, 'E_ARITY');
  assert.equal(found.message, 'Wrong number of type arguments for Handler');
  assert.equal(spanText(source, found), 'Handler(Int -> Int)');
});

test('a row on one of several Handler arguments is rejected', () => {
  const source = prelude + 'fn t(h: Handler(Clock with Log, Tick)): Int = 0;';
  const found = rejection(source);
  assert.equal(found.code, 'E_SYNTAX');
  assert.equal(found.message, 'Unexpected effect row');
  assert.equal(spanText(source, found), 'with Log');
});

test('kept rows still parse: results, operations, arrows', () => {
  accepted(prelude + 'effect Q { fn op(): Int with Log; }; '
    + 'fn a(): Int with Log = 0; '
    + 'fn b(f: (Int) -> Int with Log): Int = 0; '
    + 'fn c(f: Int -> Int with Log -> Int): Int = 0;' + main);
});

for (const [name, source] of [
  ['parameter', 'fn t(x: Int with Log): Int = 0;'],
  ['type argument', 'fn t(x: List(Int with Log)): Int = 0;'],
  ['constructor field', 'type T = T(Int with Log);'],
  ['leading arrow segment', 'fn t(f: Int with Log -> Int): Int = 0;'],
  ['operation parameter', 'effect E { fn op(x: Int with Log): Unit; };'],
  ['lambda parameter',
    'fn t(): Int = { let f = fn(x: Int with Log) => x; 0 };'],
  ['fail clause', 'type DbError = DbError; fn t(): Int = handle fail(DbError) '
    + '{ fail(error: DbError with Log) => 0 };']
]) test(`a written row is rejected in a ${name}`, () => {
  const full = prelude + source;
  const found = rejection(full);
  assert.equal(found.code, 'E_SYNTAX');
  assert.equal(found.message, 'Unexpected effect row');
  assert.equal(spanText(full, found), 'with Log');
});
