import test from 'node:test';
import assert from 'node:assert/strict';
import { lex } from '../output/Format.Lex/index.js';
import { Right } from '../output/Data.Either/index.js';
import { checked, rejected, rejectedAt } from './support.mjs';
import { runGoBatch } from './go-batch.mjs';

// Lexing and declaration parsing must run in constant stack and linear time
// (BACKLOG E002); before they were loops, these sizes exhausted the stack or,
// through per-character array copies, the heap.
const program = 'fn main(): Int = 42;';
const paddingLength = 1000000;
const padded = program + ' '.repeat(paddingLength);
const declarationCount = 20000;
const lexSecondsLimit = 5;
// About 0.3 s after the E002/I3 fixes on a 2026 laptop and 25.7 s before
// (quadratic resolver tables and Go emission); 5 s leaves room for a cold,
// loaded machine while still failing a quadratic regression by far.
const compileSecondsLimit = 5;
const millisecondsPerSecond = 1000;

const secondsFor = work => {
  const started = performance.now();
  work();
  return (performance.now() - started) / millisecondsPerSecond;
};

test('a megabyte of trailing whitespace compiles like none', () => {
  assert.equal(checked(padded), checked(program));
});

const declarationsFrom = separator => Array.from({ length: declarationCount },
  (_, index) => `fn f${index}(): Int = ${index};`).join(separator);

const last = declarationCount - 1;
const declarations = `${declarationsFrom('\n')}\nfn main(): Int = f${last}();`;
// Coverage.redundancy searched the arms with an Array.foldM over Either, one
// stack frame chain per arm, so a match of about 1,929 arms overflowed on a
// cold compile (G001 Task 4b). Each arm is still judged against the
// earlier ones; 5,000 arms take about 1.3 s.
const armCount = 5000;
const armSource = `fn main(): Int = match 7 { ${Array.from(
  { length: armCount - 1 }, (_, index) => `${index} => ${index}`
).join(', ')}, _ => 0 };`;
// Each execution has its own Go batch (T001), built lazily inside its test
// after the timed compile, so each timed checked() is that source's first
// (cold) compile, as before.
const batch = runGoBatch(import.meta.url, [['declarations', declarations]]);

test('twenty thousand declarations compile and run', () => {
  const source = declarations;
  const seconds = secondsFor(() => checked(source));
  assert.ok(seconds < compileSecondsLimit, `compiling took ${seconds}s`);
  assert.equal(batch.run('declarations'), `${last}\n`);
});

const typesFrom = count => Array.from({ length: count },
  (_, index) => `type T${index} = C${index};`).join(' ');
const manyTypes = typesFrom(declarationCount);

// Resolver tables and Go emission once scanned every type per type or per
// constructor, so 20,000 types took 25.7 s (A003 final review I3).
test('twenty thousand one-constructor types compile in linear time', () => {
  const source = `${manyTypes} fn main(): Int = 0;`;
  const seconds = secondsFor(() => checked(source));
  assert.ok(seconds < compileSecondsLimit, `compiling took ${seconds}s`);
});

// Type and constructor duplicate checks sort names like functions do; the
// first declaration in source order is still the one reported.
test('duplicates among many types are reported where they first occur', () => {
  const main = ' fn main(): Int = 0;';
  const seconds = secondsFor(() => {
    rejectedAt(`${manyTypes} type T7 = X;${main}`, 'E_DUPLICATE',
      'type T7 = C7;');
    rejectedAt(`${manyTypes} type X = C7;${main}`, 'E_DUPLICATE', 'C7');
    rejectedAt(`fn C7(): Int = 0; ${manyTypes}${main}`, 'E_DUPLICATE',
      'fn C7(): Int = 0;');
  });
  assert.ok(seconds < compileSecondsLimit, `rejecting took ${seconds}s`);
});

// Duplicate detection sorts names instead of comparing every pair; the
// clash is still reported at the first declaration of the name.
test('a duplicate among many functions is reported where it first occurs', () => {
  const source = `${declarationsFrom(' ')} fn f7(): Int = 0; fn main(): Int = 0;`;
  rejectedAt(source, 'E_DUPLICATE', 'fn f7(): Int = 7;');
});

test('a lexical error after a megabyte reports its exact position', () => {
  const offset = program.length + paddingLength;
  const diagnostic = rejected(`${padded}@`, 'E_LEX');
  assert.deepEqual(diagnostic.span, {
    start: { offset, line: 1, column: offset + 1 },
    end: { offset: offset + 1, line: 1, column: offset + 2 }
  });
});

test('lexing a megabyte takes linear, not quadratic, time', () => {
  const started = performance.now();
  const result = lex(padded);
  const seconds = (performance.now() - started) / millisecondsPerSecond;
  assert.ok(result instanceof Right, 'padded program did not lex');
  assert.ok(seconds < lexSecondsLimit, `lexing took ${seconds}s`);
});

// Resolution numbers binders through Fresh and a balanced `traverse` (G001
// Task 4); its earlier Array.foldM over Either overflowed the stack near
// 1,700 arguments or arms.
const wideCount = 10000;

test('ten thousand binding arguments resolve in source order', () => {
  const parameters = Array.from({ length: wideCount },
    (_, index) => `p${index}: Int`);
  const bindings = Array.from({ length: wideCount },
    (_, index) => `match ${index} { y => y }`);
  const source = `fn f(${parameters.join(', ')}): Int = 0; `
    + `fn main(): Int = f(${bindings.join(', ')});`;
  let go = '';
  const seconds = secondsFor(() => { go = checked(source); });
  assert.ok(seconds < compileSecondsLimit, `compiling took ${seconds}s`);
  const binders = Array.from(go.matchAll(/waxwingLocal(\d+) := /g),
    found => Number(found[1]));
  const inOrder = Array.from({ length: wideCount }, (_, index) => index);
  assert.deepEqual(binders, inOrder, 'one binder per argument, in order');
  assert.ok(!go.includes(`waxwingLocal${wideCount} `), 'no extra binder');
});

test('a five-thousand-arm integer match compiles', () => {
  const source = armSource;
  const seconds = secondsFor(() => checked(source));
  assert.ok(seconds < compileSecondsLimit, `compiling took ${seconds}s`);
  const arms = runGoBatch(import.meta.url, [['arms', source]], 'arms');
  assert.equal(arms.run('arms'), '7\n');
});

test('a five-thousand-arm match reports its redundant arm', () => {
  const arms = Array.from({ length: armCount - 1 },
    (_, index) => `${index} => ${index}`);
  const source = `fn main(): Int = match 7 { ${arms.join(', ')}, _ => 0, `
    + '3 => 3 };';
  const diagnostic = rejected(source, 'E_REDUNDANT');
  const offset = source.lastIndexOf('3 => 3');
  assert.deepEqual(diagnostic.span, {
    start: { offset, line: 1, column: offset + 1 },
    end: { offset: offset + 1, line: 1, column: offset + 2 }
  });
});

// Three searches were Array.foldM over Either and overflowed near 2,000
// constructors (G001 Task 4b): redundancy over the arms (one per
// constructor), exhaustiveness trying each constructor in turn, and the
// wildcard's usefulness against the complete constructor column.
const ctorCount = 3000;

test('a three-thousand-constructor match is judged in full', () => {
  const ctors = Array.from({ length: ctorCount }, (_, index) => `C${index}`);
  const matching = (count, extra = '') => `type T = ${ctors.join(' | ')}; `
    + `fn main(): Int = match C3 { ${ctors.slice(0, count)
      .map((ctor, index) => `${ctor} => ${index}`).join(', ')}${extra} };`;
  const seconds = secondsFor(() => checked(matching(ctorCount)));
  assert.ok(seconds < compileSecondsLimit, `compiling took ${seconds}s`);
  const diagnostic = rejected(matching(ctorCount - 1), 'E_NON_EXHAUSTIVE');
  assert.equal(diagnostic.message, `Missing pattern: C${ctorCount - 1}`);
  const redundant = matching(ctorCount, ', _ => 0');
  rejectedAt(redundant, 'E_REDUNDANT', '_');
});

// Parameter duplicates sort names (Repeated) rather than filtering the
// parameter list per parameter, which took 2.7 s at 20,000 (G001 Task 4b).
const parameterCount = 20000;
const parameterSecondsLimit = 1;

test('twenty thousand parameters are checked in linear time', () => {
  const parameters = Array.from({ length: parameterCount },
    (_, index) => `p${index}: Int`);
  const source = `fn f(${parameters.join(', ')}): Int = 0; `
    + 'fn main(): Int = 0;';
  const seconds = secondsFor(() => checked(source));
  assert.ok(seconds < parameterSecondsLimit, `checking took ${seconds}s`);
  rejectedAt(source.replace('p19999: Int', 'p7: Int'), 'E_DUPLICATE', 'p7');
});

// P001 Task 7: a worklist or key table that is quadratic in the number of
// keys fails this bound. Each f<i> instantiates `single` at its own type,
// so 3,000 function keys and 3,000 `List` type keys are created.
const instantiationCount = 3000;

test('three thousand distinct instantiations compile in linear time', () => {
  const each = index => `type T${index} = C${index};`
    + ` fn f${index}(): List(T${index}) = single(C${index});`;
  const source = 'type List(a) = Nil | Cons(a, List(a));'
    + ' fn single(x: a): List(a) = Cons(x, Nil); '
    + Array.from({ length: instantiationCount }, (_, index) => each(index))
      .join(' ') + ' fn main(): Int = 0;';
  let go = '';
  const seconds = secondsFor(() => { go = checked(source); });
  assert.ok(seconds < compileSecondsLimit, `compiling took ${seconds}s`);
  const functions = go.match(/^func waxwingFn\d+\(/gm).length;
  assert.equal(functions, 2 * instantiationCount + 1, 'one copy per key');
});

// P001 final review: unifying two unbound metas bound the older to the
// newer, so sibling metas formed one ever-longer chain that every later
// walk followed. These took 15.9 s and 8.7 s before the newer meta was
// bound to the older instead. Every arm but the last is `Nothing`, a fresh
// meta each, joined to the match's result; a first `Nothing` followed by
// `Just` arms grows no chain (1.6 s before the fix), so it would not fail.
const nothingCount = 5000;
const nilCount = 4000;

test('five thousand Nothing arms join in linear time', () => {
  const arms = Array.from({ length: nothingCount - 1 },
    (_, index) => `${index} => Nothing`);
  const source = 'type Maybe(a) = Nothing | Just(a);'
    + ` fn main(): Maybe(Int) = match 7 { ${arms.join(', ')}, _ => Just(0) };`;
  const seconds = secondsFor(() => checked(source));
  assert.ok(seconds < compileSecondsLimit, `compiling took ${seconds}s`);
});

test('four thousand Nil arguments unify in linear time', () => {
  const parameters = Array.from({ length: nilCount },
    (_, index) => `x${index}: b`);
  const source = 'type List(a) = Nil | Cons(a, List(a));'
    + ` fn f(${parameters.join(', ')}): Int = 0;`
    + ` fn main(): Int = f(${Array(nilCount).fill('Nil').join(', ')});`;
  const seconds = secondsFor(() => checked(source));
  assert.ok(seconds < compileSecondsLimit, `compiling took ${seconds}s`);
});
