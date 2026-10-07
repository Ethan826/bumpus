import test from 'node:test';
import assert from 'node:assert/strict';
import { checked, rejected, rejectedAt } from './support.mjs';

// Coverage must run in constant stack in the number of pattern columns and
// of chained types (G001 final review I1, I2). Before the fixes, a 1,600-field
// constructor pattern and a 3,000-type dependency chain each overflowed the
// stack with a raw RangeError.
const fieldCount = 5000;
const chainLength = 10000;
// Timings measured on a 2026 laptop are recorded in
// docs/plans/applicative-parser-review.md; 5 s leaves room for a cold,
// loaded machine while still failing a quadratic regression by far.
const compileSecondsLimit = 5;
const millisecondsPerSecond = 1000;
const main = ' fn main(): Int = 0;';

const secondsFor = work => {
  const started = performance.now();
  work();
  return (performance.now() - started) / millisecondsPerSecond;
};

const bounded = work => {
  const seconds = secondsFor(work);
  assert.ok(seconds < compileSecondsLimit, `coverage took ${seconds}s`);
};

const listOf = (count, item) => Array.from({ length: count }, item);
const wildcards = count => listOf(count, () => '_');
const wide = (field, arms) => `type T = C(${listOf(fieldCount, () => field)
  .join(', ')}); fn f(t: T): Int = match t { ${arms.join(', ')} };${main}`;
const arm = (patterns, body) => `C(${patterns.join(', ')}) => ${body}`;

test('an exhaustive 5,000-field constructor pattern compiles', () => {
  const binders = listOf(fieldCount, (_, index) => `b${index}`);
  bounded(() => checked(wide('Int', [arm(binders, 'b0')])));
});

test('a wide non-exhaustive match reports its exact witness', () => {
  const inner = wildcards(fieldCount - 2);
  const source = wide('Bool', [arm(['true', ...inner, '_'], 0),
    arm(['false', ...inner, 'true'], 1)]);
  bounded(() => {
    const diagnostic = rejected(source, 'E_NON_EXHAUSTIVE');
    const witness = ['false', ...inner, 'false'].join(', ');
    assert.equal(diagnostic.message, `Missing pattern: C(${witness})`);
  });
});

test('a wide redundant arm is the one reported', () => {
  const last = arm([...wildcards(fieldCount - 1), 'true'], 1);
  const source = wide('Bool', [arm(wildcards(fieldCount), 0), last]);
  bounded(() => rejectedAt(source, 'E_REDUNDANT', last.split(' =>')[0]));
});

test('a 10,000-type dependency chain settles inhabitation', () => {
  const types = listOf(chainLength, (_, index) =>
    `type T${index} = A${index}(T${index + 1});`);
  bounded(() => checked(`${types.join(' ')} type T${chainLength} = E;${main}`));
});
