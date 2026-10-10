import test from 'node:test';
import assert from 'node:assert/strict';
import { runGoBatch } from './go-batch.mjs';
import { cases, failed, log, unit } from './fx-cleanup-programs.mjs';
import { checked, rejected, rejectedAt } from './support.mjs';

// FX001 Task 8: `defer`, `crash`, the cleanup policy and the defect report
// (design §2 "defer", §3, §5). Every run case pins stdout, stderr and the
// exit status exactly.
const batch = runGoBatch(import.meta.url,
  cases.map(([name, prelude, body]) => [name, prelude + body]));
for (const [name, , , status, out, err] of cases) {
  test(name, () => {
    const result = batch.result(name);
    assert.deepEqual(
      { status: result.status, stdout: result.stdout, stderr: result.stderr },
      { status, stdout: out, stderr: err });
  });
}

// The runtime's own causes, injected into emitted Go: the missing-handler
// guard (ruling F7) and an embedded newline.
const injected = runGoBatch(import.meta.url, [
  ['the missing-handler guard is a cause line', {
    source: log + 'fn main(): Unit with Console = { defer print(1); '
      + 'with handler Log { log(n) => () } { log(1) } };',
    transform: go => go.replace('waxwingFind(ctx, 1, "Log")',
      'waxwingFind(ctx, 99, "Log")')
  }],
  ['an embedded newline is escaped', {
    source: 'fn main(): Unit = crash(7);',
    transform: go => go.replace('"crash: "', '"crash:\\n "')
  }]
], 'injected');
test('the missing-handler guard is a cause line', () => {
  const result = injected.result('the missing-handler guard is a cause line');
  assert.deepEqual(
    { status: result.status, stdout: result.stdout, stderr: result.stderr },
    { status: failed, stdout: '1\n', stderr: 'no handler for Log\n' });
});
test('an embedded newline is escaped', () => {
  const result = injected.result('an embedded newline is escaped');
  assert.deepEqual(
    { status: result.status, stdout: result.stdout, stderr: result.stderr },
    { status: failed, stdout: '', stderr: 'crash:\\n 7\n' });
});

const refuse = (source, text, span) => {
  const diagnostic = rejectedAt(source + ' fn main(): Unit = ();', 'E_EFFECT',
    span);
  assert.equal(diagnostic.message,
    `defer must not fail, but it performs ${text}`);
};

test('a defer performing an unhandled Fail directly is rejected', () => {
  refuse(unit + 'fn work(): Unit with Fail(E) = { defer fail(E); () };',
    'Fail(E)', 'defer fail(E)');
});

test('a defer performing an unhandled Fail through a call is rejected', () => {
  refuse(unit + 'fn risky(): Unit with Fail(E) = fail(E); '
    + 'fn work(): Unit with Fail(E) = { defer risky(); () };',
  'Fail(E)', 'defer risky()');
});

test('a defer is rejected whether or not the signature allows the Fail', () => {
  refuse(unit + 'fn risky(): Unit with Fail(E) = fail(E); '
    + 'fn work(): Unit = { defer risky(); () };',
  'Fail(E)', 'defer risky()');
});

test('a defer performing a Fail whose key is deferred is rejected', () => {
  refuse(unit + 'fn pick(): a = crash(0); '
    + 'fn work(): Unit with Fail(E) = { let p = pick(); '
    + 'defer fail(p); match p { E => () } };',
  'Fail(E)', 'defer fail(p)');
});

const refuseTail = (source, tail, span) => {
  const diagnostic = rejectedAt(source + ' fn main(): Unit = ();', 'E_EFFECT',
    span);
  assert.equal(diagnostic.message, 'defer must not fail, but it may perform '
    + `any effect of ${tail}`);
};

test('a defer calling an ambient-row callback is rejected (P1)', () => {
  refuseTail(unit + 'fn bracket(release: Unit -> Unit): Unit = '
    + '{ defer release(()); () };', '...', 'defer release(())');
});

test('a defer calling a named-row callback is rejected (P2)', () => {
  refuseTail(unit + 'fn bracket(release: Unit -> Unit with ...e): '
    + 'Unit with ...e = { defer release(()); () };', '...e',
  'defer release(())');
});

test('a Fail reaching a closure after its key settles is rejected (P3)', () => {
  refuse(unit + 'fn work(): Unit with Console = handle { '
    + 'let f = fn(x) => fail(x); let g = fn(y) => { defer f(y); () }; g(E) } '
    + '{ fail(error: E) => print(9) };', 'Fail(E)', 'defer f(y)');
});

test('a Fail reaching a shared lambda meta later is rejected (P4)', () => {
  refuse(unit + 'fn work(): Unit with Console = handle { '
    + 'let run = fn(h) => { defer h(()); () }; run(fn(_) => fail(E)) } '
    + '{ fail(error: E) => print(9) };', 'Fail(E)', 'defer h(())');
});

test('a pending abort cannot meet a failing cleanup (P5d)', () => {
  refuseTail(unit + 'fn bracket(release: Unit -> Unit with ...e, '
    + 'body: Unit -> Unit with ...e): Unit with ...e = '
    + '{ defer release(()); body(()) };', '...e', 'defer release(())');
});

test('a defer handling a Fail of a key settled later is accepted', () => {
  const go = checked(unit + 'fn pick(): a = crash(0); '
    + 'fn main(): Unit with Console = { let p = pick(); '
    + 'defer handle fail(p) { fail(error: E) => print(1) }; match p '
    + '{ E => () } };');
  assert.ok(go.includes('waxwingCleanup'), go);
});

test('a payload with a 5,000-arrow type is named by a loop', () => {
  const arrow = 'Int -> '.repeat(5000) + 'Int';
  const go = checked('type Error(a) = Error(a); fn work(f: ' + arrow
    + '): Unit with Fail(Error(' + arrow + ')) = '
    + '{ defer crash(1); fail(Error(f)) }; fn main(): Unit = ();');
  assert.ok(go.includes('waxwingCleanup'));
});

test('a defer must have type Unit', () => {
  const diagnostic = rejectedAt('fn main(): Unit = { defer 5; () };',
    'E_TYPE', '5');
  assert.equal(diagnostic.message, 'Expected Unit, found Int');
});

test('a defer cannot be the last item without a semicolon', () => {
  const diagnostic = rejected('fn main(): Unit with Console = '
    + '{ defer print(1) };', 'E_SYNTAX');
  assert.equal(diagnostic.message, 'Expected ;');
});

test('crash takes one printable argument', () => {
  assert.equal(rejected('fn main(): Unit = crash();', 'E_ARITY').message,
    'Wrong number of arguments');
  const diagnostic = rejected('fn main(): Unit = crash(fn(x) => x);',
    'E_TYPE');
  assert.match(diagnostic.message, /^Expected a printable value, found /);
});

test('a block without defer emits no Go defer', () => {
  const go = checked('fn main(): Int with Console = { print(1); 2 };');
  assert.ok(!go.includes('defer'), go);
  assert.ok(!go.includes('waxwingCleanup'), go);
  assert.ok(!go.includes('waxwingReport'), go);
});

test('handlers without defer or crash emit no cleanup or defect runtime', () => {
  const go = checked(unit + 'fn main(): Unit with Console = '
    + 'handle fail(E) { fail(error: E) => print(1) };');
  assert.ok(go.includes('waxwingHandle'), go);
  for (const name of ['waxwingCleanup', 'waxwingReport', 'waxwingDefect']) {
    assert.ok(!go.includes(name), `${name}\n${go}`);
  }
});

test('defer and crash need no context', () => {
  const go = checked('fn main(): Unit = { defer crash(1); () };');
  assert.ok(go.includes('defer waxwingCleanup('), go);
  assert.ok(go.includes('defer waxwingReport()'), go);
  assert.ok(!go.includes('ctx'), go);
});
