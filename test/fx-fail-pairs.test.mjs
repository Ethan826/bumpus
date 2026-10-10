import test from 'node:test';
import assert from 'node:assert/strict';
import { Left, Right } from '../output/Data.Either/index.js';
import { parse } from '../output/Format.Parse/index.js';
import { resolve } from '../output/Features.Resolve/index.js';
import { check } from '../output/Features.Check/index.js';
import { wire } from '../output/Format.Diagnostic/index.js';
import { runGo } from './support.mjs';

// FX009: a row pair set aside because a Fail payload's key stays unknown
// (a rigid variable) is E_TYPE once the body is settled, never dropped.
const checked = source => {
  const parsed = parse(source);
  assert.ok(parsed instanceof Right, JSON.stringify(parsed));
  const resolved = resolve(parsed.value0);
  assert.ok(resolved instanceof Right, JSON.stringify(resolved));
  return check(resolved.value0);
};
const rejectedAt = (source, fragment) => {
  const result = checked(source);
  assert.ok(result instanceof Left, source);
  const diagnostic = wire(result.value0);
  assert.equal(diagnostic.code, 'E_TYPE');
  assert.equal(diagnostic.message, 'Fail needs a concrete error family');
  const offset = source.indexOf(fragment);
  assert.notEqual(offset, -1, fragment);
  assert.equal(diagnostic.span.start.offset, offset);
  assert.equal(diagnostic.span.end.offset, offset + fragment.length);
};

const rigid = 'type E = E; fn g(h: Int -> Unit with Fail(a)): Unit = ';

test('calling a rigid Fail(a) parameter in a pure function', () => {
  rejectedAt(rigid + 'h(1); fn main(): Unit with Console = '
    + 'g(fn(n: Int) => fail(E));', 'h(1)');
});

test('a lambda failing with E against a rigid Fail(a) parameter row', () => {
  rejectedAt(rigid + '(); fn main(): Unit with Console = '
    + 'g(fn(n: Int) => fail(E));', 'fail(E');
});

test('a concrete Fail(E) parameter row is accepted and runs', () => {
  const source = 'type E = E; fn g(h: Int -> Int with Fail(E)): Int '
    + 'with Fail(E) = h(1); fn main(): Int = '
    + 'handle g(fn(n: Int) => fail(E)) { fail(e: E) => 7 };';
  assert.ok(checked(source) instanceof Right);
  assert.equal(runGo(source), '7\n');
});
