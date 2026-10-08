import test from 'node:test';
import assert from 'node:assert/strict';
import { TData, TVar } from '../output/Domain.Type/index.js';
import * as problem from '../output/Domain.Problem/index.js';
import { message } from '../output/Format.Diagnostic/index.js';
import { nestingLimit } from '../output/Format.Parse.Grammar/index.js';
import { rejectedAt } from './support.mjs';
import { resolved } from './phases.mjs';

// P001 Task 2: type parameters and applied types, through Parse and
// Resolve only. The CLI does not compile polymorphic programs until Task 7.
const list = 'type List(a) = Nil | Cons(a, List(a));';
const main = ' fn main(): Int = 0;';

const rows = [
  ['type T() = A;', 'E_SYNTAX', ')', 0, 'Expected a type parameter'],
  ['fn f(x: List()): Int = 0;', 'E_SYNTAX', ')', 0, 'Expected a type'],
  ['fn f(x: Int(a)): Int = 0;', 'E_SYNTAX', '(', 1, "Expected ')'"],
  ['fn f(x: a(Int)): Int = 0;', 'E_SYNTAX', '(', 1, "Expected ')'"],
  ['type T(a, a) = A(a);', 'E_DUPLICATE', 'a', 1,
    'Duplicate type parameter a'],
  // Every declaration's parameters are checked before any field type.
  ['type A = A(b); type T(a, a) = T;', 'E_DUPLICATE', 'a', 1,
    'Duplicate type parameter a'],
  ['type T(a) = A(b);', 'E_UNBOUND', 'b', 0, 'Unbound type variable b'],
  [list + ' fn f(x: List): Int = 0;' + main, 'E_ARITY', 'List', 2,
    'Wrong number of type arguments for List'],
  [list + ' fn f(x: List(Int, Int)): Int = 0;' + main, 'E_ARITY',
    'List(Int, Int)', 0, 'Wrong number of type arguments for List'],
  [list + ' type B = B(List); fn f(x: Int): Int = 0;' + main, 'E_ARITY',
    'List', 2, 'Wrong number of type arguments for List'],
  [list + ' fn main(): List(a) = Nil;', 'E_ENTRY',
    'fn main(): List(a) = Nil;', 0,
    'Expected fn main() with a concrete result type'],
  // `int` is a type variable, so this `main` is polymorphic.
  ['fn main(): int = 1;', 'E_ENTRY', 'fn main(): int = 1;', 0,
    'Expected fn main() with a concrete result type'],
  // A lowercase name is bound in a signature, but not in a field.
  [list + ' fn f(x: List(c)): Int = 0;' + main + ' type C = C(c);',
    'E_UNBOUND', 'c', 1, 'Unbound type variable c']
];

for (const [source, code, text, nth, expected] of rows) {
  test(`${code} ${expected}: ${source}`, () => {
    assert.equal(rejectedAt(source, code, text, nth).message, expected);
  });
}

const nestedReference = depth =>
  `type L(a) = N; fn f(x: ${'L('.repeat(depth)}Int${')'.repeat(depth)}`
  + `): Int = 0;${main}`;

test(`a type argument nested ${nestingLimit} deep resolves`, () => {
  resolved(nestedReference(nestingLimit));
});

test(`a type argument nested ${nestingLimit + 1} deep is E_NESTING`, () => {
  const source = nestedReference(nestingLimit + 1);
  const diagnostic = rejectedAt(source, 'E_NESTING', 'Int');
  assert.equal(diagnostic.message, `Nesting exceeds ${nestingLimit} levels`);
});

test('parameterized declarations resolve; VarId i is the i-th parameter',
  () => {
    const program = resolved(list + ' type Pair(a, b) = Pair(a, b);'
      + ' type Proxy(a) = Proxy;' + main);
    assert.deepEqual(program.types.map(info => info.parameters),
      [['a'], ['a', 'b'], ['a']]);
    const [nil, cons, pair, proxy] = program.ctors;
    assert.deepEqual(nil.fields, []);
    assert.deepEqual(cons.fields,
      [TVar.create(0), TData.create(0)([TVar.create(0)])]);
    assert.deepEqual(pair.fields, [TVar.create(0), TVar.create(1)]);
    assert.deepEqual(proxy.fields, []);
    assert.equal(cons.fieldSyntax.length, 2);
  });

test('type variables do not collide with value names', () => {
  const [a] = resolved('fn a(a: a): a = a;' + main).functions;
  assert.deepEqual(a.variables, ['a']);
  assert.deepEqual(a.parameters[0].ty, TVar.create(0));
  assert.deepEqual(a.result, TVar.create(0));
});

test('function variables number in first occurrence, parameters then result',
  () => {
    const [f] = resolved(list + ' type Pair(a, b) = Pair(a, b);'
      + ' fn f(x: b, y: List(a)): Pair(c, b) = f(x, y);' + main).functions;
    assert.deepEqual(f.variables, ['b', 'a', 'c']);
    assert.deepEqual(f.result,
      TData.create(1)([TVar.create(2), TVar.create(0)]));
  });

test('a variable may appear only in the result', () => {
  const [loop] = resolved('fn loop(): a = loop();' + main).functions;
  assert.deepEqual(loop.variables, ['a']);
});

test('monomorphic declarations have no parameters or variables', () => {
  const program = resolved('type T = A(Int);' + main);
  assert.deepEqual(program.types[0].parameters, []);
  assert.deepEqual(program.functions[0].variables, []);
});

test('type names render applied types, variables and holes', () => {
  const { AppliedName, VariableName, HoleName, IntName } = problem;
  const pair = AppliedName.create('Pair')([IntName.value,
    VariableName.create('a')]);
  const mismatch = problem.TypeMismatch.create(
    AppliedName.create('List')([pair]))(HoleName.value);
  assert.equal(message(mismatch), 'Expected List(Pair(Int, a)), found _');
});
