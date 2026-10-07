import test from 'node:test';
import assert from 'node:assert/strict';
import { checked, rejectedAt } from './support.mjs';

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
