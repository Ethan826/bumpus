// FN001 Task 2: Features.Check.Functional, the declared types whose values
// can hold a function (design §3), built directly from constructor tables:
// no syntax writes an arrow until Task 3.
import test from 'node:test';
import assert from 'node:assert/strict';
import { member } from '../output/Data.Set/index.js';
import { ordTypeId } from '../output/Domain.Ids/index.js';
import { closedRow } from '../output/Domain.Row/index.js';
import { TData, TFun, TInt, TVar } from '../output/Domain.Type/index.js';
import { containsFunction, functional } from '../output/Features.Check.Functional/index.js';

const int = TInt.value;
const fun = (parameter, result) => TFun.create(parameter)(closedRow)(result);
const variable = TVar.create(0);
// TypeId and VarId are newtypes, so plain numbers at run time.
const applied = (id, ...args) => TData.create(id)(args)([]);
const ctor = (owner, fields) => ({ name: `C${owner}`, owner, fields, fieldSyntax: [], span: null });

const [List, Box, A, B, Phantom, C, E, H, Plain] = [0, 1, 2, 3, 4, 5, 6, 7, 8];
const ctors = [
  ctor(List, []),
  ctor(List, [variable, applied(List, variable)]),
  ctor(Box, [fun(variable, variable)]),
  ctor(A, [applied(B)]),
  ctor(B, [fun(int, int)]),
  ctor(B, [applied(A)]),
  ctor(Phantom, []),
  ctor(C, [applied(Phantom, fun(int, int))]),
  ctor(E, [applied(List, applied(Box, int))]),
  ctor(H, [variable]),
  ctor(Plain, [int, applied(List, int), applied(H, applied(Plain))])
];
const holds = (found, id) => member(ordTypeId)(id)(found);

test('the functional types are the least fixed point through fields', () => {
  const found = functional(ctors);
  for (const id of [Box, A, B, C, E]) assert.equal(holds(found, id), true, `type ${id}`);
  for (const id of [List, Phantom, H, Plain]) assert.equal(holds(found, id), false, `type ${id}`);
});

test('a type contains a function directly or through a functional type', () => {
  const found = functional(ctors);
  const contains = ty => containsFunction(found)(ty);
  assert.equal(contains(applied(List, int)), false);
  assert.equal(contains(applied(Box, int)), true);
  assert.equal(contains(applied(H, fun(int, int))), true);
  assert.equal(contains(applied(H, applied(Box, int))), true);
  assert.equal(contains(applied(H, applied(List, int))), false);
  assert.equal(contains(fun(int, int)), true);
  assert.equal(contains(int), false);
});

const chainLength = 50000;
const chainBoundMs = 5000;

test('a 50,000-type chain settles without stack failure', () => {
  // Type i holds type i + 1; only the last holds an arrow.
  const chain = Array.from({ length: chainLength }, (_, index) =>
    ctor(index, [index + 1 < chainLength ? applied(index + 1) : fun(int, int)]));
  const started = performance.now();
  const found = functional(chain);
  const elapsed = performance.now() - started;
  assert.equal(holds(found, 0), true);
  assert.equal(holds(found, chainLength - 1), true);
  assert.ok(elapsed < chainBoundMs, `${elapsed} ms`);
});
