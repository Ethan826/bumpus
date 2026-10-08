import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { checked, command, runGo } from './support.mjs';

// E005: each match is a top-level Go function `bumpusFn{f}Match{k}`, k in
// pre-order (scrutinee before arms) within bumpusFn{f}. Its parameters are
// the captured locals in LocalId order, then the scrutinee.
const list = 'type L = Nil | Cons(Int, L);';
const work = mkdtempSync(join(tmpdir(), 'bumpus-lift-'));
after(() => rmSync(work, { recursive: true, force: true }));

const headers = go => go.match(/^func bumpusFn[^\n]*$/gm);

test('lifted matches are named in pre-order with captures first', () => {
  const source = `${list} fn f(xs: L, n: Int): Int = (match xs { Nil => n, `
    + 'Cons(h, t) => match t { Nil => h + n, Cons(g, _) => g } }) '
    + '+ (match n { 0 => 1, _ => 2 }); '
    + 'fn main(): Int = match Cons(1, Nil) { '
    + 'Cons(a, _) => f(Cons(a, Nil), a), Nil => 0 };';
  assert.deepEqual(headers(checked(source)), [
    'func bumpusFn0(bumpusLocal0 bumpusTy0, bumpusLocal1 int32) int32 {',
    'func bumpusFn0Match0(bumpusLocal1 int32, '
      + 'bumpusScrutinee bumpusTy0) int32 {',
    'func bumpusFn0Match1(bumpusLocal1 int32, bumpusLocal2 int32, '
      + 'bumpusScrutinee bumpusTy0) int32 {',
    'func bumpusFn0Match2(bumpusScrutinee int32) int32 {',
    'func bumpusFn1() int32 {',
    'func bumpusFn1Match0(bumpusScrutinee bumpusTy0) int32 {'
  ]);
  assert.equal(runGo(source), '4\n');
});

test('a match in a scrutinee is numbered before the arms', () => {
  const source = `${list} fn main(): Int = `
    + 'match match 1 { 1 => Cons(2, Nil), _ => Nil } '
    + '{ Cons(h, _) => match h { 2 => 5, _ => 6 }, Nil => 0 };';
  assert.deepEqual(headers(checked(source)), [
    'func bumpusFn0() int32 {',
    'func bumpusFn0Match0(bumpusScrutinee bumpusTy0) int32 {',
    'func bumpusFn0Match1(bumpusScrutinee int32) bumpusTy0 {',
    'func bumpusFn0Match2(bumpusScrutinee int32) int32 {'
  ]);
  assert.equal(runGo(source), '5\n');
});

// A parameter (k) and outer binders (h, t) reach matches two and three
// levels down; t is used only as an inner scrutinee, so the middle match
// must capture it even though none of its arm expressions read it directly.
const capturing = `${list} fn f(xs: L, k: Int): Int = match xs { `
  + 'Nil => k, Cons(h, t) => match h { '
  + '0 => match t { Nil => k, Cons(g, _) => g + h + k }, '
  + '_ => match k { 0 => h, _ => match t { Nil => h + k, '
  + 'Cons(g2, u) => match u { Nil => g2 + h, Cons(z, _) => z + k } } } } }; '
  + 'fn main(): Int = f(Cons(0, Cons(5, Nil)), 100) '
  + '+ f(Cons(3, Cons(4, Cons(6, Nil))), 1000) + f(Cons(2, Nil), 10) '
  + '+ f(Nil, 1);';

test('captures propagate through several nested matches', () => {
  const file = join(work, 'capture.bumpus');
  writeFileSync(file, capturing);
  assert.equal(command('node', ['scripts/bumpus.mjs', 'run', file]),
    '1124\n');
});
