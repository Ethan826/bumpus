import test from 'node:test';
import assert from 'node:assert/strict';
import { Right } from '../output/Data.Either/index.js';
import {
  specialize, specializationKeys
} from '../output/Features.Specialize/index.js';
import { compile } from '../output/Program.Compile/index.js';
import { runGoBatch } from './go-batch.mjs';
import { checkedPoly } from './phases.mjs';
import { keyTexts } from './poly-keys.mjs';

// FN001 Task 5: function values through Specialize, called directly
// (design §6, §7). The CLI stops these programs at the unlowered guard
// until Task 6 (test/fn-check.test.mjs).
const prelude = 'type List(a) = Nil | Cons(a, List(a)); type Box(a) = Box(a); '
  + 'fn id(x: a): a = x; fn keep(x: a): Int = 0; ';
const mapping = 'fn map(f: a -> b, xs: List(a)): List(b) = match xs {'
  + ' Nil => Nil, Cons(h, t) => Cons(f(h), map(f, t)) }; ';

// The failure message is built only on failure: a large program's IR is
// too deep for JSON.stringify.
const specialized = source => {
  const result = specialize(checkedPoly(source));
  if (!(result instanceof Right)) assert.fail(JSON.stringify(result));
  return result.value0;
};

// Every node of `tag` under `value`, in pre-order.
const nodes = (value, tag, found = []) => {
  if (Array.isArray(value)) value.forEach(item => nodes(item, tag, found));
  else if (value !== null && typeof value === 'object') {
    if (value.constructor.name === tag) found.push(value);
    Object.values(value).forEach(field => nodes(field, tag, found));
  }
  return found;
};

const named = (program, name) => program.functions.filter(
  definition => definition.name === name);

test('map(id, …) at Int and at Bool specializes id twice', () => {
  const source = prelude + mapping + 'fn main(): Int = keep(map(id,'
    + ' Cons(1, Nil))) + keep(map(id, Cons(true, Nil)));';
  const functions = keyTexts(source).filter(key => key.startsWith('fn '));
  assert.deepEqual(functions.filter(key => /^fn (id|map)\[/.test(key)).sort(),
    ['fn id[Bool]', 'fn id[Int]', 'fn map[Bool, Bool]', 'fn map[Int, Int]']);
  const program = specialized(source);
  const [main] = named(program, 'main');
  const referenced = nodes(main.body, 'FunctionRef').map(ref =>
    program.functions[ref.value0].parameters[0].constructor.name);
  assert.deepEqual(referenced, ['TInt', 'TBool']);
  assert.equal(named(program, 'id').length, 2);
});

// A constructor value and a partial construction name the constructor of
// their owner's copy: the final result of their arrow, not the arrow.
test('constructor values name their owner\'s copy', () => {
  const source = prelude + mapping + 'fn main(): Int = keep(map(Box,'
    + ' Cons(true, Nil))) + keep(Cons(1));';
  const program = specialized(source);
  const [main] = named(program, 'main');
  const owners = [...nodes(main.body, 'CtorRef'),
    ...nodes(main.body, 'Construct')].map(node => {
    const ctor = program.ctors[node.value0];
    return `${ctor.name} ${ctor.fields.map(f => f.constructor.name)}`;
  });
  assert.deepEqual(owners.sort(),
    ['Box TBool', 'Cons TBool,TData', 'Cons TInt,TData', 'Nil ']);
});

// Two 5,000-parameter function types differing only in the last parameter,
// as generic arguments of a function (`id`, `keep`, `probe`) and of a type
// (`Box`). `probe` then refers to `keep` and `Box` at its variable
// `references` times, so each lookup of a key whose argument is an arrow
// compares two such types: by interned numbers that is constant time; by
// walking or spelling the types it is 5,000 steps each. Measured on a 2026
// laptop (scratchpad mutants of Specialize.Keys, not committed): 0.23 s
// interned; 5.5 s with keys of whole IR types (compared by the spine loop);
// 12.6 s with keys spelled as strings.
const width = 5000;
const references = 2000;
const spelled = last => [...Array(width - 1).fill('Int'), last, 'Int']
  .join(' -> ');
const parameters = last => Array.from({ length: width }, (_, index) =>
  `p${index}: ${index === width - 1 ? last : 'Int'}`).join(', ');
const repeated = text => Array(references).fill(text).join(', ');
const wide = prelude
  + `fn sink(${Array.from({ length: references }, (_, index) =>
    `q${index}: Int`).join(', ')}): Int = 0; `
  + `fn probe(x: a): Int = sink(${repeated('keep(x)')})`
  + ` + sink(${repeated('keep(Box(x))')}); `
  + `fn wide(${parameters('Int')}): Int = 0; `
  + `fn other(${parameters('Bool')}): Int = 0; `
  + 'fn main(): Int = probe(wide) + probe(other) + keep(id(wide))'
  + ' + keep(id(other)) + keep(Box(wide)) + keep(Box(other));';
const secondsLimit = 2;

test('5,000-parameter function types key by number, kept distinct', () => {
  const checked = checkedPoly(wide);
  const started = performance.now();
  const result = specializationKeys(checked);
  const seconds = (performance.now() - started) / 1000;
  if (!(result instanceof Right)) assert.fail(JSON.stringify(result));
  assert.ok(seconds < secondsLimit, `specializing took ${seconds} s`);
  const keys = keyTexts(wide);
  assert.equal(new Set(keys).size, keys.length, 'keys are unique');
  for (const last of ['Int', 'Bool']) {
    const arrow = spelled(last);
    for (const key of [`fn id[${arrow}]`, `fn keep[${arrow}]`,
      `fn probe[${arrow}]`, `type Box[${arrow}]`, `fn keep[Box(${arrow})]`]) {
      assert.ok(keys.includes(key), key.slice(0, 40));
    }
  }
});

// Review I1: arrows are numbers in the IR. The two 5,000-parameter types
// get different FunTypeIds, every use of one type the same id, and the
// table spells each spine once: suffix by suffix, a result numbered before
// the arrow holding it.
test('arrow types in the IR are interned table entries', () => {
  const program = specialized(wide);
  const parameterOf = name => named(program, name).map(definition =>
    definition.parameters[0]);
  const ids = parameterOf('id');
  assert.equal(ids.length, 2);
  assert.ok(ids.every(ty => ty.constructor.name === 'TFun'));
  assert.notEqual(ids[0].value0, ids[1].value0);
  const probes = parameterOf('probe').map(ty => ty.value0);
  assert.deepEqual(probes.sort(), ids.map(ty => ty.value0).sort());
  const spineOf = id => {
    const parameters = [];
    let ty = { constructor: { name: 'TFun' }, value0: id };
    while (ty.constructor.name === 'TFun') {
      assert.ok(ty.value0 < id || ty.value0 === id);
      const arrow = program.funTypes[ty.value0];
      parameters.push(arrow.parameter.constructor.name);
      ty = arrow.result;
    }
    return parameters;
  };
  for (const ty of ids) {
    const spine = spineOf(ty.value0);
    assert.equal(spine.length, width);
    assert.ok(['TInt', 'TBool'].includes(spine[width - 1]));
  }
  // Two spines sharing every suffix but the outermost parts: 2 × 5,000
  // entries at most, never a copy per use.
  assert.ok(program.funTypes.length <= 2 * width, program.funTypes.length);
});

// Review M4: test/phases.mjs builds its failure message only on failure;
// stringifying a successful result whose checked IR holds a 20,000-long
// arrow (the type of the value `f`) overflowed the stack.
test('checkedPoly succeeds on a 20,000-parameter function value', () => {
  const parameters = Array.from({ length: 20000 }, (_, index) =>
    `p${index}: Int`).join(', ');
  const program = checkedPoly(`fn f(${parameters}): Int = 0; `
    + 'fn keep(x: a): Int = 0; fn main(): Int = keep(f);');
  assert.equal(program.functions.length, 3);
});

// Review M1: the guard judges the monomorphic IR. An arrow that is only a
// phantom type argument is no value, function type or node there, so the
// program reaches Go, with the arrow's named type declared and unused.
const phantom = 'type Proxy(a) = P; fn keep(x: Proxy(a)): Int = 0;'
  + ' fn mk(): Proxy(Int -> Int) = P; fn main(): Int = keep(mk());';
const batch = runGoBatch(import.meta.url, [['phantom', phantom]]);

test('a phantom arrow argument compiles and runs', () => {
  const result = compile(phantom);
  if (!(result instanceof Right)) assert.fail(JSON.stringify(result));
  assert.ok(result.value0.includes('type bumpusFun0 func(int32) int32\n'));
  assert.equal(batch.run('phantom'), '0\n');
});
