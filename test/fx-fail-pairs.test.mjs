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

// A Fail whose payload has no family key (a type variable, a function or a
// handler type; keys are Int, Bool, Unit or a declared type) is refused
// where it is written, in every position a signature has rows (user
// decisions on FX009 review M1 and N1), with a hint at the same label.
const positions = [
  ['an own row', 'fn f(e: a): Int with Fail(P) = 0;'],
  ['a parameter row', 'fn g(h: Int -> Unit with Fail(P)): Unit = ();'],
  ['a nested arrow row', 'fn g(h: Int -> (Int -> Unit with Fail(P))): Unit '
    + '= ();'],
  ['a result row', 'fn g(): Int -> Unit with Fail(P) = fn(n: Int) => ();'],
  ['a handler type', 'fn g(h: Handler(Fail(P))): Unit = ();'],
  ['a row argument', job + 'fn g(j: Job(Int, Console + Fail(P))): Int = 1;']
];
const payloads = ['a', 'Int -> Int', 'Handler(Console)'];
const expectWritten = (source, fragment, container = source, from = 0) =>
  expectDiagnostic(source, {
    code: 'E_TYPE', message: family, at: [container, fragment, from],
    notes: [[container, fragment, hint, from]]
  });
for (const [name, template] of positions) {
  for (const payload of payloads) {
    test(`Fail(${payload}) written in ${name} is rejected there`, () => {
      const source = template.replace('P', payload) + ' fn main(): Int = 0;';
      expectWritten(source, `Fail(${payload})`);
    });
  }
}

// The same payloads in a handle clause, which is not a signature row.
const clauses = [
  ['a variable', 'fn f(x: a): Int = handle 0 { fail(e: a) => 1 }; ', 'a'],
  ['a function type', 'fn f(): Int = handle 0 { fail(e: Int -> Int) => 1 }; ',
    'Int -> Int']
];
for (const [name, head, payload] of clauses) {
  test(`a handle clause payload that is ${name} is rejected there`, () => {
    const source = head + 'fn main(): Int = 0;';
    const clause = `fail(e: ${payload})`;
    expectWritten(source, payload, clause, 'fail(e: '.length);
  });
}

test('the keyless-payload program from review N1 is rejected at Fail', () => {
  const source = 'type E = E; fn g(h: Int -> Unit with Fail(Int -> Int)): '
    + 'Unit = h(1); fn main(): Unit with Console = '
    + 'g(fn(n: Int) => fail(E));';
  expectWritten(source, 'Fail(Int -> Int)');
});

test('Fail(Unit) and Fail(Error(a)) are still allowed', () => {
  const result = checked('type Error(a) = Error(a); fn raise(e: a): Int '
    + 'with Fail(Error(a)) + Fail(Unit) = fail(Error(e)); '
    + 'fn main(): Int = 0;');
  assert.ok(result instanceof Right, JSON.stringify(result));
});

test('the reported program is rejected at Fail(a) in the signature', () => {
  const source = 'type E = E; fn g(h: Int -> Unit with Fail(a)): Unit = h(1); '
    + 'fn main(): Unit with Console = g(fn(n: Int) => fail(E));';
  expectWritten(source, 'Fail(a)');
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
