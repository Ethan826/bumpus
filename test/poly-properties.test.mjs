import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { Right } from '../output/Data.Either/index.js';
import { TBool } from '../output/Domain.Type/index.js';
import { specializeWith } from '../output/Features.Specialize/index.js';
import { emit } from '../output/Format.Go/index.js';
import { compile } from '../output/Program.Compile/index.js';
import { generator } from './coverage-oracle.mjs';
import { runGoBatch } from './go-batch.mjs';
import { checkedPoly } from './phases.mjs';
import {
  components, groundArguments, groundTypes, render
} from './poly-components.mjs';
import { keyTexts, namedKeys } from './poly-keys.mjs';
import { interpret, run } from './poly-oracle.mjs';
import { programs } from './poly-programs.mjs';
import { typeText } from './poly-types.mjs';

// P001 Task 8: specialization properties (design §8). Generated
// polymorphic programs (test/poly-programs.mjs) run in Go and must print
// what an independent untyped interpreter (test/poly-oracle.mjs) computes;
// their keys are unique and independent of declaration order; their
// output is independent of the hole representative; and Task 5's
// components stay within the §4.2 bound. All execution is one Go batch.

// The Go for `source` with every hole specialized to Bool instead of Int.
const boolGo = source => {
  const result = specializeWith(TBool.value)(checkedPoly(source));
  assert.ok(result instanceof Right, JSON.stringify(result));
  return emit(result.value0);
};

// Per program: as generated, with declarations reversed, and with Bool as
// the hole representative (the batch's Go is replaced by boolGo's).
const cases = programs.flatMap(({ source, reversed }, index) => [
  [`p${index}`, source], [`r${index}`, reversed],
  [`b${index}`, { source, transform: () => boolGo(source) }]
]);
const batch = runGoBatch(import.meta.url, cases);

test('the reference interpreter agrees with known outputs', () => {
  const lists = readFileSync('examples/lists.wxw', 'utf8');
  assert.equal(interpret(lists),
    'Pair(Cons(Pair(3, true), Cons(Pair(2, false), Nil)), Just(6))');
  assert.equal(interpret('fn main(): Int = 2147483647 + 1;'), '-2147483648');
  assert.equal(interpret('type T = A | B(Int, Bool);'
    + ' fn main(): Bool = if B(1, true) < A then false else B(1, false)'
    + ' < B(1, true);'), 'true');
});

// The generator really produces what the properties need.
test('generated programs permute, drop, recurse, leave holes and nest', () => {
  const calls = programs.flatMap(program => program.calls);
  const between = calls.filter(call => call.caller
    && call.caller !== call.callee);
  const named = call => [...call.mapping].map(([name, type]) =>
    [name, typeText(type)]);
  assert.ok(between.some(call => named(call).some(([name, type]) =>
    call.caller.bare.includes(type) && type !== name)), 'permuted');
  assert.ok(between.some(call => call.caller.bare.some(name =>
    !named(call).some(([, type]) => type === name))), 'dropped');
  assert.ok(calls.some(call => call.caller && call.caller === call.callee),
    'recursive');
  const recursing = programs.filter(({ source }) => run(source).recursive);
  assert.ok(recursing.length >= programs.length / 3, 'recursion runs');
  for (const program of programs) {
    const instantiated = program.calls.filter(call => !call.caller)
      .flatMap(call => named(call).map(([, type]) =>
        `${call.callee.name} ${type}`));
    assert.ok(instantiated.some(text => text.endsWith(' _')), 'hole');
  }
  const together = (left, right) => programs.some(program => {
    const texts = program.calls.filter(call => !call.caller)
      .map(call => `${call.callee.name} ${named(call).join(' ')}`);
    return texts.some(text => text.includes(left)
      && texts.includes(text.replace(left, right)));
  });
  assert.ok(together('List(List(Int))', 'List(List(Bool))'), 'nested lists');
  assert.ok(together('Pair(Int, Bool)', 'Pair(Bool, Int)'), 'pairs');
});

test('execution oracle: programs print what the interpreter computes', () => {
  programs.forEach(({ source }, index) => {
    assert.equal(batch.run(`p${index}`), `${interpret(source)}\n`,
      `program ${index}: ${source}`);
  });
});

test('uniqueness: no two specialization keys are equal', () => {
  programs.forEach(({ source }, index) => {
    const keys = keyTexts(source);
    assert.ok(keys.some(key => key.includes('(')), `program ${index}`);
    assert.equal(new Set(keys).size, keys.length,
      `program ${index}: ${keys.join('; ')}`);
  });
});

const sorted = items => [...items].sort();

test('determinism: same Go twice; reversed declarations, same meaning',
  () => {
    programs.forEach(({ source, reversed }, index) => {
      const first = compile(source);
      assert.ok(first instanceof Right, `program ${index}`);
      assert.equal(compile(source).value0, first.value0, `program ${index}`);
      assert.equal(batch.run(`r${index}`), batch.run(`p${index}`),
        `program ${index}`);
      assert.deepEqual(sorted(keyTexts(reversed)), sorted(keyTexts(source)),
        `program ${index}`);
    });
  });

test('representative independence: holes as Int or Bool print the same',
  () => {
    programs.forEach(({ source }, index) => {
      // The holes reach specialization: the two Go programs differ.
      assert.notEqual(boolGo(source), compile(source).value0,
        `program ${index}`);
      assert.equal(batch.run(`b${index}`), batch.run(`p${index}`),
        `program ${index}`);
    });
  });

// Entry arguments for the termination bound: Task 5's ground arguments
// and two nested ones. `_` is the hole, which specializes to Int.
const entries = [...groundArguments,
  { text: 'Cons(Cons(true, Nil), Nil)', type: 'List(List(Bool))' },
  { text: 'Cons(Nil, Nil)', type: 'List(List(_))' }];
const representative = type => type.replaceAll('_', 'Int');

// Design §4.2: entered once from `main` at (d0, τ̄0), component C creates
// at most Σ_{d ∈ C} |T|^arity(d) keys, T = components(τ̄0) ∪ G_C, and
// every key's arguments lie in T.
test('termination: keys per component stay within the §4.2 bound', () => {
  const next = generator(0x4b1d);
  const draw = count => (next() >>> 16) % count;
  for (const component of components) {
    const entry = component.functions[draw(component.functions.length)];
    const chosen = Array.from({ length: entry.arity },
      () => entries[draw(entries.length)]);
    const call = `${entry.name}(${chosen.map(each => each.text).join(', ')})`;
    const { source } = render(component, `fn main(): Int = ${call};`);
    const arities = new Map(component.functions.map(definition =>
      [definition.name, definition.arity]));
    const allowed = new Set([...chosen.map(each => each.type),
      ...groundTypes(component)].map(representative));
    const keys = namedKeys(source).filter(key => key.function
      && arities.has(key.name));
    const bound = [...arities.values()].reduce((total, arity) =>
      total + allowed.size ** arity, 0);
    assert.ok(keys.length >= 1 && keys.length <= bound,
      `${keys.length} keys, bound ${bound}: ${source}`);
    for (const key of keys) {
      assert.ok(key.arguments.every(arg => allowed.has(arg)),
        `${key.text} outside ${[...allowed].join(', ')}: ${source}`);
    }
  }
});
