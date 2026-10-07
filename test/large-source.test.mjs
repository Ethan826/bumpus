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
const millisecondsPerSecond = 1000;

test('a megabyte of trailing whitespace compiles like none', () => {
  assert.equal(checked(padded), checked(program));
});

const declarationsFrom = separator => Array.from({ length: declarationCount },
  (_, index) => `fn f${index}(): Int = ${index};`).join(separator);

test('twenty thousand declarations compile and run', () => {
  const last = declarationCount - 1;
  const source = `${declarationsFrom('\n')}\nfn main(): Int = f${last}();`;
  assert.equal(runGo(source), `${last}\n`);
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
