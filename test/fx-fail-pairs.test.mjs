import test from 'node:test';
import assert from 'node:assert/strict';
import { Right } from '../output/Data.Either/index.js';
import { parse } from '../output/Format.Parse/index.js';
import { resolve } from '../output/Features.Resolve/index.js';
import { check } from '../output/Features.Check/index.js';
import { runGo } from './support.mjs';
import { expectDiagnostic } from './fx-diagnostics-support.mjs';

// FX009: a Fail whose family is a type variable is rejected where it is
// written; the checker's set-aside pairs are the guard behind that.
const checked = source => {
  const parsed = parse(source);
  assert.ok(parsed instanceof Right, JSON.stringify(parsed));
  const resolved = resolve(parsed.value0);
  assert.ok(resolved instanceof Right, JSON.stringify(resolved));
  return check(resolved.value0);
};

const family = 'Fail needs a concrete error family';
const hint = 'use ...e to pass through what a callback performs, a concrete '
  + 'family such as Fail(DbError), or return a Result';
const job = 'type Job(a, ...effects) = Job(Int -> a with ...effects); ';

// A Fail label whose payload is a type variable is rejected where it is
// written, in every position a signature has rows (user decision on FX009
// review M1), with a hint at the same label.
const written = [
  ['an own row', 'fn f(e: a): Int with Fail(a) = 0;', 'Fail(a)'],
  ['a parameter row', 'fn g(h: Int -> Unit with Fail(a)): Unit = ();',
    'Fail(a)'],
  ['a nested arrow row', 'fn g(h: Int -> (Int -> Unit with Fail(a))): Unit '
    + '= ();', 'Fail(a)'],
  ['a result row', 'fn g(): Int -> Unit with Fail(a) = fn(n: Int) => ();',
    'Fail(a)'],
  ['a handler type', 'fn g(h: Handler(Fail(a))): Unit = ();', 'Fail(a)'],
  ['a row argument', job + 'fn g(j: Job(Int, Console + Fail(a))): Int = 1;',
    'Fail(a)']
];
for (const [name, body, fragment] of written) {
  test(`Fail(a) written in ${name} is rejected there`, () => {
    const source = body + ' fn main(): Int = 0;';
    const offset = source.indexOf(fragment);
    const diagnostic = expectDiagnostic(source, {
      code: 'E_TYPE', message: family, at: [source, fragment],
      notes: [[source, fragment, hint]]
    });
    assert.equal(diagnostic.span.start.offset, offset);
  });
}

test('the reported program is rejected at Fail(a) in the signature', () => {
  const source = 'type E = E; fn g(h: Int -> Unit with Fail(a)): Unit = h(1); '
    + 'fn main(): Unit with Console = g(fn(n: Int) => fail(E));';
  expectDiagnostic(source, {
    code: 'E_TYPE', message: family, at: [source, 'Fail(a)'],
    notes: [[source, 'Fail(a)', hint]]
  });
});

test('a concrete head with a variable inside is still allowed', () => {
  const result = checked('type Error(a) = Error(a); fn raise(e: a): Int '
    + 'with Fail(Error(a)) = fail(Error(e)); fn main(): Int = 0;');
  assert.ok(result instanceof Right, JSON.stringify(result));
});

test('a concrete Fail(E) parameter row is accepted and runs', () => {
  const source = 'type E = E; fn g(h: Int -> Int with Fail(E)): Int '
    + 'with Fail(E) = h(1); fn main(): Int = '
    + 'handle g(fn(n: Int) => fail(E)) { fail(e: E) => 7 };';
  assert.ok(checked(source) instanceof Right);
  assert.equal(runGo(source), '7\n');
});

// Both payloads are unsolved; the walk reports the inner `fail(e`, the
// outer `fail(h(` would be the first found without descending.
test('nested unresolved failure payload is visited', () => {
  const source = 'fn hole(u: Unit): a = hole(u); fn h(k: b): a = hole(()); '
    + 'fn f(): Int with Fail(Int) = fail(h(fn(e) => fail(e))); '
    + 'fn main(): Int = 0;';
  expectDiagnostic(source, {
    code: 'E_TYPE', message: family, at: ['fail(e)', 'fail(e'], notes: []
  });
});
