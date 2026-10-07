import test from 'node:test';
import assert from 'node:assert/strict';
import { lex } from '../output/Format.Lex/index.js';
import { Right } from '../output/Data.Either/index.js';
import { checked, rejected, rejectedAt, runGo } from './support.mjs';

// Lexing and declaration parsing must run in constant stack and linear time
// (BACKLOG E002); before they were loops, these sizes exhausted the stack or,
// through per-character array copies, the heap.
const program = 'fn main(): Int = 42;';
const paddingLength = 1000000;
const padded = program + ' '.repeat(paddingLength);
const declarationCount = 20000;
const lexSecondsLimit = 5;
// About 0.3 s after the E002/I3 fixes on a 2026 laptop and 25.7 s before
// (quadratic resolver tables and Go emission); 5 s leaves room for a cold,
// loaded machine while still failing a quadratic regression by far.
const compileSecondsLimit = 5;
const millisecondsPerSecond = 1000;

const secondsFor = work => {
  const started = performance.now();
  work();
  return (performance.now() - started) / millisecondsPerSecond;
};

test('a megabyte of trailing whitespace compiles like none', () => {
  assert.equal(checked(padded), checked(program));
});

const declarationsFrom = separator => Array.from({ length: declarationCount },
  (_, index) => `fn f${index}(): Int = ${index};`).join(separator);

test('twenty thousand declarations compile and run', () => {
  const last = declarationCount - 1;
  const source = `${declarationsFrom('\n')}\nfn main(): Int = f${last}();`;
  const seconds = secondsFor(() => checked(source));
  assert.ok(seconds < compileSecondsLimit, `compiling took ${seconds}s`);
  assert.equal(runGo(source), `${last}\n`);
});

const typesFrom = count => Array.from({ length: count },
  (_, index) => `type T${index} = C${index};`).join(' ');
const manyTypes = typesFrom(declarationCount);

// Resolver tables and Go emission once scanned every type per type or per
// constructor, so 20,000 types took 25.7 s (A003 final review I3).
test('twenty thousand one-constructor types compile in linear time', () => {
  const source = `${manyTypes} fn main(): Int = 0;`;
  const seconds = secondsFor(() => checked(source));
  assert.ok(seconds < compileSecondsLimit, `compiling took ${seconds}s`);
});

// Type and constructor duplicate checks sort names like functions do; the
// first declaration in source order is still the one reported.
test('duplicates among many types are reported where they first occur', () => {
  const main = ' fn main(): Int = 0;';
  const seconds = secondsFor(() => {
    rejectedAt(`${manyTypes} type T7 = X;${main}`, 'E_DUPLICATE',
      'type T7 = C7;');
    rejectedAt(`${manyTypes} type X = C7;${main}`, 'E_DUPLICATE', 'C7');
    rejectedAt(`fn C7(): Int = 0; ${manyTypes}${main}`, 'E_DUPLICATE',
      'fn C7(): Int = 0;');
  });
  assert.ok(seconds < compileSecondsLimit, `rejecting took ${seconds}s`);
});

// Duplicate detection sorts names instead of comparing every pair; the
// clash is still reported at the first declaration of the name.
test('a duplicate among many functions is reported where it first occurs', () => {
  const source = `${declarationsFrom(' ')} fn f7(): Int = 0; fn main(): Int = 0;`;
  rejectedAt(source, 'E_DUPLICATE', 'fn f7(): Int = 7;');
});

test('a lexical error after a megabyte reports its exact position', () => {
  const offset = program.length + paddingLength;
  const diagnostic = rejected(`${padded}@`, 'E_LEX');
  assert.deepEqual(diagnostic.span, {
    start: { offset, line: 1, column: offset + 1 },
    end: { offset: offset + 1, line: 1, column: offset + 2 }
  });
});

test('lexing a megabyte takes linear, not quadratic, time', () => {
  const started = performance.now();
  const result = lex(padded);
  const seconds = (performance.now() - started) / millisecondsPerSecond;
  assert.ok(result instanceof Right, 'padded program did not lex');
  assert.ok(seconds < lexSecondsLimit, `lexing took ${seconds}s`);
});
