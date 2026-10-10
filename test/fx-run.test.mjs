import test from 'node:test';
import assert from 'node:assert/strict';
import { runGoBatch } from './go-batch.mjs';
import { cases } from './fx-run-programs.mjs';
import { checked } from './support.mjs';

// FX001 Task 7: handlers, operations and failures executed through Go
// (design §3, §4). One Go batch; every case checks exact stdout.
const log = 'effect Log { fn log(n: Int): Unit; }; ';
const state = 'effect State(s) { fn get(): s; fn put(value: s): Unit; }; ';
const clock = 'effect Clock { fn now(): Int; }; ';
const batch = runGoBatch(import.meta.url, cases.map(([name, source]) =>
  [name, source]));
for (const [name, , expected] of cases) {
  test(name, () => assert.equal(batch.run(name), expected));
}

test('Console-only programs thread no context', () => {
  const go = checked('fn main(): Unit with Console = print(1);');
  assert.ok(!go.includes('ctx'), go);
});

test('an unused generic effectful function is not emitted and forces no ctx',
  () => {
    const go = checked(state + 'fn peek(): Unit with State(a) = '
      + '{ let v = get(); () }; fn main(): Int = 7;');
    assert.ok(!go.includes('ctx'), go);
  });

test('an unused monomorphic effectful function forces ctx', () => {
  const go = checked(clock + 'fn unused(): Int with Clock = now(); '
    + 'fn main(): Int = 7;');
  assert.ok(go.includes('ctx *waxwingCtx'), go);
});
