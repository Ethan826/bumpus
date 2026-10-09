import test from 'node:test';
import assert from 'node:assert/strict';
import { runGoBatch } from './go-batch.mjs';
import { checked, rejected, rejectedAt } from './support.mjs';

// FX001 Task 8: `defer`, `crash`, the cleanup policy and the defect report
// (design §2 "defer", §3, §5). Every run case pins stdout, stderr and the
// exit status exactly.
const log = 'effect Log { fn log(n: Int): Unit; }; ';
const ok = 0;
const failed = 1;
const unit = 'type E = E; ';
const why = 'type Why = Busy | Slow; ';
const db = 'type DbError = Timeout(Int) | Dead; ';

const cases = [
  ['LIFO order', '', 'fn main(): Unit with Console = '
    + '{ defer print(1); defer print(2); print(3) };',
  ok, '3\n2\n1\n', ''],
  ['an unreached defer never runs', unit,
    'fn work(): Unit with Fail(E) + Console = '
    + '{ defer print(1); fail(E); defer print(2); () }; '
    + 'fn main(): Unit with Console = '
    + 'handle work() { fail(error: E) => print(9) };',
  ok, '1\n9\n', ''],
  ['two crashing defers on normal exit', why,
    'fn main(): Unit = { defer crash(Busy); defer crash(Slow); () };',
  failed, '', 'crash: Slow\ncleanup failed: crash: Busy\n'],
  ['abort with crashing cleanup', db + why,
    'fn work(): Unit with Fail(DbError) = '
    + '{ defer crash(Busy); fail(Timeout(3)) }; '
    + 'fn main(): Unit with Console = '
    + 'handle work() { fail(error: DbError) => print(7) };',
  failed, '', 'fail(DbError): Timeout(3)\ncleanup failed: crash: Busy\n'],
  ['multiple recoverable defects in order', '',
    'fn inner(): Unit = { defer crash(1); defer crash(2); crash(3) }; '
    + 'fn main(): Unit = { defer crash(4); inner() };',
  failed, '', 'crash: 3\ncleanup failed: crash: 2\n'
    + 'cleanup failed: crash: 1\ncleanup failed: crash: 4\n'],
  ['cleanup handling its own failure while an abort is pending', unit
    + 'type F = F; ',
  'fn clean(): Unit with Console = '
    + 'handle fail(F) { fail(error: F) => print(2) }; '
    + 'fn work(): Unit with Fail(E) + Console = '
    + '{ defer clean(); print(1); fail(E) }; '
    + 'fn main(): Unit with Console = '
    + 'handle work() { fail(error: E) => print(3) };',
  ok, '1\n2\n3\n', ''],
  ['cleanup uses the registration context during an abort', unit + log,
    'fn main(): Unit with Console = '
    + 'with handler Log { log(n) => print(n) } { handle { { defer log(1); '
    + 'with handler Log { log(n) => print(n + 100) } { fail(E) } } } '
    + '{ fail(error: E) => print(9) } };',
  ok, '1\n9\n', ''],
  ['crash is not caught by handle', unit,
    'fn main(): Unit with Console = '
    + '{ print(0); handle crash(1) { fail(error: E) => print(2) } };',
  failed, '0\n', 'crash: 1\n'],
  ['a payload holding a function is not printable',
    'type Boxed = Boxed(Int -> Int); ' + why,
    'fn work(): Unit with Fail(Boxed) = '
    + '{ defer crash(Busy); fail(Boxed(fn(x) => x)) }; '
    + 'fn main(): Unit = handle work() { fail(error: Boxed) => () };',
  failed, '', 'fail(Boxed): <not printable>\ncleanup failed: crash: Busy\n'],
  ['the payload type is printed with its arguments',
    'type Error(a) = Error(a); ' + why,
    'fn work(): Unit with Fail(Error(Int)) = '
    + '{ defer crash(Busy); fail(Error(5)) }; '
    + 'fn main(): Unit = handle work() { fail(error: Error(Int)) => () };',
  failed, '', 'fail(Error(Int)): Error(5)\ncleanup failed: crash: Busy\n'],
  ['a defer handling its own failure', unit,
    'fn main(): Unit with Console = { defer handle fail(E) '
    + '{ fail(error: E) => print(1) }; print(2) };',
  ok, '2\n1\n', ''],
  ['a defer performing a non-Fail effect', log,
    'fn work(): Unit with Log = { defer log(1); log(2) }; '
    + 'fn main(): Unit with Console = '
    + 'with handler Log { log(n) => print(n) } { work() };',
  ok, '2\n1\n', ''],
  ['a defer in a block of a function value', '',
    'fn main(): Unit with Console = '
    + '{ let f = fn(x) => { defer print(x + 1); print(x) }; f(1); f(5) };',
  ok, '1\n2\n5\n6\n', '']
];

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
