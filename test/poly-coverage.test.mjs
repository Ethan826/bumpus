import test from 'node:test';
import assert from 'node:assert/strict';
import { Left } from '../output/Data.Either/index.js';
import { check } from '../output/Features.Check/index.js';
import { wire } from '../output/Format.Diagnostic/index.js';
import { checkRejectedAt, checkedPoly, resolved } from './phases.mjs';

// P001 Task 6: coverage over applied types and type variables (design §5),
// through Parse, Resolve and Check only; the CLI does not compile
// polymorphic programs until Task 7.
const prelude = 'type List(a) = Nil | Cons(a, List(a));'
  + ' type Pair(a, b) = Pair(a, b); type Maybe(a) = Nothing | Just(a);'
  + ' type Void = Void(Void); ';
const main = ' fn main(): Int = 0;';

// [name, program after the prelude]
const exhaustive = [
  ['Nil and Cons over List(a)', 'fn f(xs: List(a)): Int = match xs {'
    + ' Nil => 0, Cons(_, _) => 1 };' + main],
  ['a binder over a', 'fn f(x: a): Int = match x { y => 1 };' + main],
  ['a binder under a constructor over a', 'fn f(p: Pair(a, Bool)): Int ='
    + ' match p { Pair(x, true) => 0, Pair(_, false) => 1 };' + main],
  ['only Nothing over Maybe(Void)', 'fn f(m: Maybe(Void)): Int = match m {'
    + ' Nothing => 0 };' + main],
  ['Nothing and Just(Nothing) over Maybe(Maybe(Void))',
    'fn f(m: Maybe(Maybe(Void))): Int = match m { Nothing => 0,'
    + ' Just(Nothing) => 1 };' + main],
  ['a hole column', 'fn main(): Int = match Nil { Nil => 0,'
    + ' Cons(x, _) => match x { _ => 1 } };'],
  ['nested heads through List(List(a))', 'fn f(xs: List(List(a))): Int ='
    + ' match xs { Nil => 0, Cons(Nil, _) => 1, Cons(Cons(_, _), _) => 2 };'
    + main]
];

for (const [name, program] of exhaustive) {
  test(`exhaustive: ${name}`, () => checkedPoly(prelude + program));
}

// The span of a program's only match expression, up to its closing brace.
const wholeMatch = Symbol('the whole match');
const matchText = program => program.slice(program.indexOf('match'),
  program.indexOf(' };') + ' }'.length);

// [program after the prelude, code, span text (its first occurrence after
// the prelude), message]
const rejectedRows = [
  // Task 4 rejects a constructor pattern over a variable before coverage.
  ['fn f(x: a): Int = match x { Nothing => 0 };' + main, 'E_TYPE', 'Nothing',
    'Expected a, found Maybe(_)'],
  ['fn f(xs: List(List(Int))): Int = match xs { Nil => 0,'
    + ' Cons(_, Nil) => 1 };' + main, 'E_NON_EXHAUSTIVE', wholeMatch,
  'Missing pattern: Cons(_, Cons(_, _))'],
  ['fn f(xs: List(List(Int))): Int = match xs { Nil => 0,'
    + ' Cons(Nil, _) => 1 };' + main, 'E_NON_EXHAUSTIVE', wholeMatch,
  'Missing pattern: Cons(Cons(_, _), _)'],
  ['fn f(p: Pair(a, Bool)): Int = match p { Pair(_, true) => 0 };' + main,
    'E_NON_EXHAUSTIVE', wholeMatch, 'Missing pattern: Pair(_, false)'],
  ['fn f(m: Maybe(Void)): Int = match m { Just(_) => 0 };' + main,
    'E_NON_EXHAUSTIVE', wholeMatch, 'Missing pattern: Nothing'],
  ['fn f(m: Maybe(Maybe(Void))): Int = match m { Nothing => 0 };' + main,
    'E_NON_EXHAUSTIVE', wholeMatch, 'Missing pattern: Just(_)'],
  ['fn main(): Int = match Nil { Nil => 0 };', 'E_NON_EXHAUSTIVE',
    wholeMatch, 'Missing pattern: Cons(_, _)'],
  ['fn f(x: a): Int = match x { y => 1, _ => 2 };' + main, 'E_REDUNDANT',
    '_', 'Redundant match arm'],
  ['fn f(m: Maybe(Void)): Int = match m { Nothing => 0, _ => 1 };' + main,
    'E_REDUNDANT', '_', 'Redundant match arm'],
  // One source match, one diagnostic at its span, whatever the callers.
  ['fn f(m: Maybe(a)): Int = match m { Nothing => 0 };'
    + ' fn main(): Int = f(Just(1)) + f(Just(true));', 'E_NON_EXHAUSTIVE',
  wholeMatch, 'Missing pattern: Just(_)']
];

for (const [program, code, spanText, message] of rejectedRows) {
  test(`${code} ${message}: ${program}`, () => {
    const text = spanText === wholeMatch ? matchText(program) : spanText;
    const nth = prelude.split(text).length - 1;
    const diagnostic = checkRejectedAt(prelude + program, code, text, nth);
    assert.equal(diagnostic.message, message);
  });
}

// The verdict on a whole program, as code and message, or null if checked.
// Witnesses are renamed to the monomorphic constructors N and J.
const verdict = source => {
  const result = check(resolved(source));
  if (!(result instanceof Left)) return null;
  const { code, message } = wire(result.value0);
  return { code,
    message: message.replace('Nothing', 'N').replace('Just', 'J') };
};

// ADR 003: Maybe(Void) behaves as the monomorphic `type MV = N | J(Void)`.
const armSets = [['Nothing => 0', 'Just(_) => 1'], ['Nothing => 0'],
  ['Just(_) => 1'], ['Nothing => 0', '_ => 1'], ['Just(_) => 0', '_ => 1']];

test('Maybe(Void) follows the monomorphic uninhabited-arm policy', () => {
  for (const arms of armSets) {
    const applied = `${prelude}fn f(m: Maybe(Void)): Int = match m {`
      + ` ${arms.join(', ')} };${main}`;
    const renamed = arms.join(', ').replace('Nothing', 'N')
      .replace('Just', 'J');
    const mono = `${prelude}type MV = N | J(Void); fn f(m: MV): Int =`
      + ` match m { ${renamed} };${main}`;
    assert.deepEqual(verdict(applied), verdict(mono), applied);
  }
  assert.equal(verdict(`${prelude}fn f(m: Maybe(Void)): Int = match m {`
    + ` Nothing => 0, Just(_) => 1 };${main}`), null);
});

// A chain of parameterized types, each applied to the next: expanding
// `U(Void)` and `U(Int)` numbers 3,000 applications each, and whether
// `Dead` needs an arm depends on the argument at the chain's far end, so
// only inhabitation per application settles it.
const chainLength = 3000;
const secondsLimit = 5;
const millisecondsPerSecond = 1000;
const chain = prelude + Array.from({ length: chainLength }, (_, index) =>
  `type T${index}(a) = A${index}(T${index + 1}(a));`).join(' ')
  + ` type T${chainLength}(a) = Z(a); type U(a) = Dead(T0(a)) | Live;`;

const timed = work => {
  const started = performance.now();
  const result = work();
  const seconds = (performance.now() - started) / millisecondsPerSecond;
  assert.ok(seconds < secondsLimit, `coverage took ${seconds} s`);
  return result;
};

test('coverage expands a 3,000-application chain in bounded time', () => {
  const live = 'match u { Live => 0 }';
  timed(() => checkedPoly(`${chain} fn f(u: U(Void)): Int = ${live};${main}`));
  for (const argument of ['Int', 'a']) {
    const source = `${chain} fn f(u: U(${argument})): Int = ${live};${main}`;
    const diagnostic = timed(() =>
      checkRejectedAt(source, 'E_NON_EXHAUSTIVE', live));
    assert.equal(diagnostic.message, 'Missing pattern: Dead(_)');
  }
});
