import test from 'node:test';
import assert from 'node:assert/strict';
import { checked, rejected, rejectedAt } from './support.mjs';

// The applicative grammar (G001) parses lists in a stack-safe loop. Before
// it, match arms recursed once per arm, and 1,473 arms overflowed the stack
// with a RangeError (BACKLOG E002).
const armCount = 1473;
const compileSecondsLimit = 5;
const millisecondsPerSecond = 1000;
const main = ' fn main(): Int = 0;';

const secondsFor = work => {
  const started = performance.now();
  work();
  return (performance.now() - started) / millisecondsPerSecond;
};

// 1,472 distinct integer arms and a final wildcard: no arm is redundant.
const integerArms = Array.from({ length: armCount - 1 },
  (_, index) => `${index} => ${index}`).concat(['_ => -1']).join(', ');

test('a match with 1,473 arms compiles in bounded time', () => {
  const source = `fn f(n: Int): Int = match n { ${integerArms} };${main}`;
  const seconds = secondsFor(() => checked(source));
  assert.ok(seconds < compileSecondsLimit, `compiling took ${seconds}s`);
});

const single = 'type B = T; fn f(b: B): Int = match b { T => 1';

test('a trailing comma after the last arm is accepted', () => {
  checked(`${single}, };${main}`);
});

// Recorded from the compiler before the applicative grammar.
test('a doubled trailing comma reports a pattern at the second comma', () => {
  const diagnostic = rejectedAt(`${single},, };${main}`, 'E_SYNTAX', ',', 1);
  assert.equal(diagnostic.message, 'Expected a pattern');
});

// Breadth inputs from BACKLOG E002: each overflowed the stack (RangeError)
// while constructor, field and argument lists recursed once per item.
const constructorCount = 1536;
const fieldCount = 1536;
const argumentCount = 1793;
const listOf = (count, item) => Array.from({ length: count }, item);

const boundedCompile = source => {
  const seconds = secondsFor(() => checked(source));
  assert.ok(seconds < compileSecondsLimit, `compiling took ${seconds}s`);
};

test('a type with 1,536 constructors compiles in bounded time', () => {
  const constructors = listOf(constructorCount, (_, index) => `C${index}`);
  boundedCompile(`type T = ${constructors.join(' | ')};${main}`);
});

test('a constructor with 1,536 fields compiles in bounded time', () => {
  const fields = listOf(fieldCount, () => 'Int');
  boundedCompile(`type P = Wide(${fields.join(', ')});${main}`);
});

test('a call with 1,793 arguments compiles in bounded time', () => {
  const parameters = listOf(argumentCount, (_, index) => `p${index}: Int`);
  const zeros = listOf(argumentCount, () => '0');
  boundedCompile(`fn f(${parameters.join(', ')}): Int = 0; `
    + `fn main(): Int = f(${zeros.join(', ')});`);
});

// Recorded from the compiler before the applicative grammar: an unclosed
// parenthesis at end of input is an empty span at the end.
test('an unclosed parenthesis at end of input expects the parenthesis', () => {
  const source = 'fn main(): Int = (1';
  const diagnostic = rejected(source, 'E_SYNTAX');
  const end = { offset: source.length, line: 1, column: source.length + 1 };
  assert.deepEqual(diagnostic.span, { start: end, end });
  assert.equal(diagnostic.message, "Expected ')'");
});
