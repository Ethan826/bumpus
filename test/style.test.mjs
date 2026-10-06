import test from 'node:test';
import assert from 'node:assert/strict';
import { check } from '../output/Style.Check/index.js';
const moduleSource = body => `module Fixture where\nimport Prelude\nimport Data.Maybe (Maybe(..))\n${body}\n`;

test('CST style gate rejects let-in, lambdas, Maybe routing, and branch blocks', () => {
  for (const [body, message] of [
    ['f x = let y = x in y', 'use where'],
    ['f = map (\\x -> x)', 'name transformations'],
    ['f x = case x of\n  Nothing -> 0\n  Just value -> value', 'use maybe/either'],
    ['f x = if x then do\n  pure unit\nelse pure unit', 'move branch work']
  ]) assert.ok(check(moduleSource(body)).some(finding => finding.includes(message)), body);
});

test('comments and strings cannot hide code or trigger style errors', () => {
  assert.deepEqual(check(moduleSource('f = "case x of Just y -> let z = y in z"\n-- let x = 1 in x')), []);
  assert.ok(check(moduleSource('f x = case x of\n  Just\n    value -> value\n  Nothing -> 0')).length > 0);
  assert.ok(check('this is not a PureScript module').length > 0);
});

test('named where helpers and lazy Maybe fallback are accepted', () => {
  assert.deepEqual(check(moduleSource('f x = maybe 0 found x\n  where\n  found value = value')), []);
});
