// FX001 Task 3: sort-aware substitution (Domain.Type.substitute). A type
// variable is replaced by a type; a row tail by a row, spliced: its labels
// appended in order, its tail the new tail. Variables are checker Flex
// values here; type metas 0..2 and row metas 10..12 keep the sorts apart.
import test from 'node:test';
import assert from 'node:assert/strict';
import { Just } from '../output/Data.Maybe/index.js';
import { Row } from '../output/Domain.Row/index.js';
import { TVar, functorTy, substitute, substituteRow } from '../output/Domain.Type/index.js';
import * as unifier from '../output/Features.Check.Unify/index.js';
import { choose, generator } from './coverage-oracle.mjs';
import { label, row, rowMeta } from './row-support.mjs';
import { bool, fromRow, fromTy, fun, int, list, meta, rigid, toRow, toTy } from './unify-support.mjs';

const cases = 500;
const open = flex => Row.create([])(Just.create(flex));
const identity = { types: TVar.create, rows: open };
const metaOf = flex => flex instanceof unifier.Meta ? flex.value0 : null;

// A substitution from two plain maps; unmapped variables stay.
const substitution = (types, rowMap) => ({
  types: flex => types.has(metaOf(flex)) ? toTy(types.get(metaOf(flex))) : TVar.create(flex),
  rows: flex => rowMap.has(metaOf(flex)) ? toRow(rowMap.get(metaOf(flex))) : open(flex)
});
const apply = (s, t) => fromTy(substitute(s)(toTy(t)));

// With `rowed` false every row is closed and empty: a row-free type.
const genLabel = (next, depth) => choose(next, 3) === 0 ? label(0)
  : label(1 + choose(next, 2), genType(next, depth - 1));
const genRow = (next, depth, rowed = true) => !rowed ? row([]) : row(
  Array.from({ length: choose(next, 3) }, () => genLabel(next, depth)),
  [null, rigid(5), rowMeta(10), rowMeta(11), rowMeta(12)][choose(next, 5)]);
const genType = (next, depth, rowed = true) => {
  const shape = depth <= 0 ? choose(next, 2) : choose(next, 5);
  const part = () => genType(next, depth - 1, rowed);
  if (shape === 0) return [int, bool, rigid(0), meta(0), meta(1), meta(2)][choose(next, 6)];
  if (shape === 1) return meta(choose(next, 3));
  if (shape === 2) return list(part());
  if (shape === 3) return { k: 'data', id: 2, args: [], rows: [genRow(next, depth, rowed)] };
  return { ...fun(part(), part()), row: genRow(next, depth, rowed) };
};
const genMaps = next => [
  new Map([0, 1, 2].filter(() => choose(next, 2) === 0).map(n => [n, genType(next, 2)])),
  new Map([10, 11, 12].filter(() => choose(next, 2) === 0).map(n => [n, genRow(next, 2)]))
];
// fromTy leaves a closed empty row out, as toTy reads it; normalize both.
const plain = t => fromTy(toTy(t));

test('the identity substitution changes nothing', () => {
  const next = generator(0x41);
  for (let index = 0; index < cases; index += 1) {
    const t = genType(next, 3);
    assert.deepEqual(fromTy(substitute(identity)(toTy(t))), plain(t));
  }
});

test('substituting a composition is substituting in sequence', () => {
  const next = generator(0x42);
  for (let index = 0; index < cases; index += 1) {
    const [s1, s2] = [substitution(...genMaps(next)), substitution(...genMaps(next))];
    const composed = {
      types: flex => substitute(s2)(s1.types(flex)),
      rows: flex => substituteRow(s2)(s1.rows(flex))
    };
    const t = toTy(genType(next, 3));
    assert.deepEqual(fromTy(substitute(composed)(t)), fromTy(substitute(s2)(substitute(s1)(t))));
  }
});

test('one row variable is replaced by the same spliced row everywhere', () => {
  const shared = { ...fun(int, { ...fun(bool, int), row: row([label(2, int)], rowMeta(10)) }),
    row: row([label(0)], rowMeta(10)) };
  const s = substitution(new Map(), new Map([[10, row([label(1, bool), label(0)], rowMeta(11))]]));
  assert.deepEqual(apply(s, shared), {
    ...fun(int, { ...fun(bool, int), row: row([label(2, int), label(1, bool), label(0)], rowMeta(11)) }),
    row: row([label(0), label(1, bool), label(0)], rowMeta(11))
  });
});

// One pass: the spliced image is not substituted again (meta 0 stays).
test('splicing keeps order and multiplicity, and closes a closed tail', () => {
  const written = row([label(0), label(1, int)], rowMeta(10));
  const s = substitution(new Map([[0, int]]), new Map([[10, row([label(1, meta(0)), label(0)])]]));
  assert.deepEqual(fromRow(substituteRow(s)(toRow(written))),
    row([label(0), label(1, int), label(1, meta(0)), label(0)]));
});

test('renaming by Functor agrees with substitute on row-free types', () => {
  const next = generator(0x43);
  const renamed = flex => flex instanceof unifier.Meta ? unifier.Meta.create(flex.value0 + 1) : flex;
  for (let index = 0; index < cases; index += 1) {
    const t = toTy(genType(next, 3, false));
    const viaSubstitute = substitute({ types: flex => TVar.create(renamed(flex)),
      rows: flex => open(renamed(flex)) })(t);
    assert.deepEqual(fromTy(functorTy.map(renamed)(t)), fromTy(viaSubstitute));
  }
});
