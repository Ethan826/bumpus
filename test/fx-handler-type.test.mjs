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

test('a Log-performing clause is rejected under with pure', () => {
  const found = rejection(prelude + 'fn t(h: Handler(Clock with pure)): '
    + 'Handler(Tick with pure) = handler Tick { tick() => { log(); h } };'
    + main);
  assert.equal(found.code, 'E_EFFECT');
});

test('a Log handler is not a pure handler parameter', () => {
  const found = rejection(prelude + 'fn run(h: Handler(Clock with pure)): '
    + 'Int = 0; fn t(g: Handler(Clock with Log)): Int = run(g);' + main);
  assert.equal(found.code, 'E_EFFECT');
});

for (const [name, source, fragment] of [
  ['parameter', 'fn t(x: Int with Log): Int = 0;', 'with Log'],
  ['type argument', 'fn t(x: List(Int with Log)): Int = 0;', 'with Log'],
  ['constructor field', 'type T = T(Int with Log);', 'with Log'],
  ['leading arrow segment', 'fn t(f: Int with Log -> Int): Int = 0;',
    'with Log'],
  ['operation parameter', 'effect E { fn op(x: Int with Log): Unit; };',
    'with Log']
]) test(`a written row is rejected in a ${name}`, () => {
  const found = rejection(prelude + source);
  assert.equal(found.code, 'E_SYNTAX');
  assert.equal(found.message, 'Unexpected effect row');
  const offset = (prelude + source).indexOf(fragment);
  assert.equal(found.span.start.offset, offset);
});
