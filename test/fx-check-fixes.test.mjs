import test from 'node:test';
import assert from 'node:assert/strict';
import { Right } from '../output/Data.Either/index.js';
import { parse } from '../output/Format.Parse/index.js';
import { resolve } from '../output/Features.Resolve/index.js';
import { check } from '../output/Features.Check/index.js';

// FX001 Task 7 review: checker fixes found by lowering programs, tested at
// the Check level (no Go). Row-parameterized data is matched at its
// declared rows, and a field row reached through a bound meta consumes as
// the closed row it is.
const checked = source => {
  const parsed = parse(source);
  assert.ok(parsed instanceof Right, JSON.stringify(parsed));
  const resolved = resolve(parsed.value0);
  assert.ok(resolved instanceof Right, JSON.stringify(resolved));
  return check(resolved.value0);
};
const prelude = 'effect Log { fn log(n: Int): Unit; }; '
  + 'effect Clock { fn now(): Int; }; '
  + 'type Job(a, ...effects) = Job(Int -> a with ...effects); '
  + 'fn main(): Int = 0; ';

test('a constructor pattern keeps the type\'s row arguments', () => {
  const result = checked(prelude + 'fn peek(j: Job(Int, Log)): Int = '
    + 'match j { Job(f) => 1 };');
  assert.ok(result instanceof Right, JSON.stringify(result));
});

test('a stored function with two labels is called in a matching row', () => {
  const result = checked(prelude + 'fn start(j: Job(Int, Log + Clock), '
    + 'n: Int): Int with Log + Clock = match j { Job(f) => f(n) };');
  assert.ok(result instanceof Right, JSON.stringify(result));
});
