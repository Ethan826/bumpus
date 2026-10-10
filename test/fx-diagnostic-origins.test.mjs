import test from 'node:test';
import { clock, db, expectDiagnostic, log } from './fx-diagnostics-support.mjs';

test('repeated Fail families attribute each origin to its own occurrence', () => {
  const types = 'type A = A; type B = B; ';
  const both = 'fn two(): Int with Fail(A) + Fail(B) = { fail(A); fail(B) }; ';
  const handled = 'fn main(): Int = handle two() { fail(error: A) => 0 };';
  expectDiagnostic(types + both + handled, {
    code: 'E_EFFECT', message: 'Unhandled Fail(B) in main',
    at: ['fn main(): Int = handle two() { fail(error: A) => 0 };', 'two()'],
    notes: [['fn two(): Int with Fail(A) + Fail(B) = { fail(A); fail(B) };',
      'fail(B', 'Fail(B) is raised here'],
    ['fn main(): Int = handle two() { fail(error: A) => 0 };',
      'fn main(): Int = handle two() { fail(error: A) => 0 };',
      'main may perform only Console']]
  });
  const other = 'fn main(): Int = handle two() { fail(error: B) => 0 };';
  expectDiagnostic(types + both + other, {
    code: 'E_EFFECT', message: 'Unhandled Fail(A) in main', at: [other, 'two()'],
    notes: [['fn two(): Int with Fail(A) + Fail(B) = { fail(A); fail(B) };',
      'fail(A', 'Fail(A) is raised here'],
    [other, other, 'main may perform only Console']]
  });
});

test('a label consumed into a signature-written row gets an origin note', () => {
  const twice = 'fn twice(): Int with Clock = now() + now(); ';
  const main = 'fn main(): Int with Clock = twice();';
  expectDiagnostic(clock + twice + main, {
    code: 'E_EFFECT', message: 'Unhandled Clock in main', at: [main, 'twice()'],
    notes: [[twice, 'now()', 'Clock is performed here'],
      [main, main, 'main may perform only Console']]
  });
});

test('a label consumed into an already-extended row keeps the first origin', () => {
  const first = 'fn first(): Int with Clock = now(); ';
  const second = 'fn second(): Int with Clock = now(); ';
  const main = 'fn main(): Int = { first(); second() };';
  expectDiagnostic(clock + first + second + main, {
    code: 'E_EFFECT', message: 'Unhandled Clock in main', at: [main, 'first()'],
    notes: [[first, 'now()', 'Clock is performed here'],
      [main, main, 'main may perform only Console']]
  });
});

test('Unhandled Fail(DbError) in main has an origin note at the fail', () => {
  const raise = 'fn raise(): Int with Fail(DbError) = fail(DbError); ';
  const main = 'fn main(): Int = raise();';
  expectDiagnostic(db + raise + main, {
    code: 'E_EFFECT', message: 'Unhandled Fail(DbError) in main',
    at: [main, 'raise()'],
    notes: [[raise, 'fail(DbError', 'Fail(DbError) is raised here'],
      [main, main, 'main may perform only Console']]
  });
});

test('a direct operation in main notes only the boundary', () => {
  const main = 'fn main(): Int with Clock = now();';
  expectDiagnostic(clock + main, {
    code: 'E_EFFECT', message: 'Unhandled Clock in main', at: [main, 'now()'],
    notes: [[main, main, 'main may perform only Console']]
  });
});

test('a closed signature that does not allow a label names the signature', () => {
  const stamp = 'fn stamp(): Int with pure = tick(); ';
  const source = log + clock + 'fn tick(): Int with Clock = now(); '
    + stamp + 'fn main(): Int = 0;';
  expectDiagnostic(source, {
    code: 'E_EFFECT',
    message: 'stamp performs Clock, which its signature does not allow',
    at: [stamp.trim(), 'tick()'],
    notes: [['fn tick(): Int with Clock = now();', 'now()',
      'Clock is performed here'],
    [stamp.trim(), 'with pure', 'the signature of stamp does not allow Clock']]
  });
});

test('an ambient signature is named as such', () => {
  const stamp = 'fn stamp(): Int = now(); ';
  expectDiagnostic(clock + stamp + 'fn main(): Int = 0;', {
    code: 'E_EFFECT',
    message: 'stamp performs Clock, which its signature does not allow',
    at: [stamp.trim(), 'now()'],
    notes: [[stamp.trim(), stamp.trim(),
      'the signature of stamp has an ambient row']]
  });
});

const unitFail = 'type E = E; ';

test('defer performing a Fail through a called function: call and raise', () => {
  const risky = 'fn risky(): Unit with Fail(E) = fail(E); ';
  const work = 'fn work(): Unit with Fail(E) = { defer risky(); () }; ';
  expectDiagnostic(unitFail + risky + work + 'fn main(): Unit = ();', {
    code: 'E_EFFECT', message: 'defer must not fail, but it performs Fail(E)',
    at: ['defer risky()'],
    notes: [[work, 'risky()', 'Fail(E) comes from this call of risky'],
      [risky, 'fail(E', 'Fail(E) is raised here']]
  });
});

test('defer performing a Fail whose key settles after the defer', () => {
  const lambdas = 'let f = fn(x) => fail(x); '
    + 'let g = fn(y) => { defer f(y); () }; g(E)';
  const work = `fn work(): Unit with Console = handle { ${lambdas} } `
    + '{ fail(error: E) => print(9) }; ';
  expectDiagnostic(unitFail + work + 'fn main(): Unit = ();', {
    code: 'E_EFFECT', message: 'defer must not fail, but it performs Fail(E)',
    at: ['defer f(y)'],
    notes: [[work, 'f(y)', 'Fail(E) comes from this function value', 'let g'.length],
      [work, 'fail(x', 'Fail(E) is raised here']]
  });
});

test('defer calling an ambient callback names the application and the row', () => {
  const bracket = 'fn bracket(release: Unit -> Unit): Unit = '
    + '{ defer release(()); () }; ';
  expectDiagnostic(bracket + 'fn main(): Unit = ();', {
    code: 'E_EFFECT',
    message: 'defer must not fail, but it may perform any effect of ...',
    at: ['defer release(())'],
    notes: [[bracket, 'release(())',
      'any effect of ... comes from this function value'],
    [bracket.trim(), bracket.trim(), '... is declared here']]
  });
});

test('defer calling a named-row callback names the application and the row', () => {
  const bracket = 'fn bracket(release: Unit -> Unit with ...e): Unit with ...e '
    + '= { defer release(()); () }; ';
  expectDiagnostic(bracket + 'fn main(): Unit = ();', {
    code: 'E_EFFECT',
    message: 'defer must not fail, but it may perform any effect of ...e',
    at: ['defer release(())'],
    notes: [[bracket, 'release(())',
      'any effect of ...e comes from this function value'],
    [bracket, 'with ...e', '...e is declared here']]
  });
});


test('defer calling a named function with a callback names the call', () => {
  const use = 'fn use(f: Unit -> Unit with ...e): Unit with ...e = f(()); ';
  const bracket = 'fn bracket(release: Unit -> Unit): Unit = '
    + '{ defer use(release); () }; ';
  expectDiagnostic(use + bracket + 'fn main(): Unit = ();', {
    code: 'E_EFFECT',
    message: 'defer must not fail, but it may perform any effect of ...',
    at: ['defer use(release)'],
    notes: [[bracket, 'use(release)',
      'any effect of ... comes from this call of use'],
    [bracket.trim(), bracket.trim(), '... is declared here']]
  });
});
