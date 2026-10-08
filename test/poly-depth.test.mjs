import test from 'node:test';
import assert from 'node:assert/strict';
import * as unifier from '../output/Features.Check.Unify/index.js';
import { checkRejectedAt, checkedPoly } from './phases.mjs';

// P001 Task 4 fix 1 (ruling R7): an inferred type deeper than the bound is
// E_NESTING at the expression whose type first exceeds it, never a stack
// overflow. Check only; the CLI compiles no polymorphic program until Task 7.
const limit = 1000;
const secondsLimit = 5;
const millisecondsPerSecond = 1000;
const list = 'type L(a) = N | C(a, L(a)); fn sink(x: a): Int = 0; ';
const calls = (depth, leaf) => 'deep('.repeat(depth) + leaf
  + ')'.repeat(depth);

// `deep` adds `width` levels per call, so `count` calls give a type
// width·count + 1 deep (Int is depth 1).
const program = (width, count) => `${list}fn deep(x: a): `
  + `${'L('.repeat(width)}a${')'.repeat(width)} = deep(x);`
  + ` fn main(): Int = sink(${calls(count, '1')});`;

const timed = work => {
  const started = performance.now();
  const result = work();
  const seconds = (performance.now() - started) / millisecondsPerSecond;
  assert.ok(seconds < secondsLimit, `took ${seconds} s`);
  return result;
};

const rejectedAtDepth = (width, count, first) => {
  const diagnostic = timed(() => checkRejectedAt(program(width, count),
    'E_NESTING', calls(first, '1')));
  assert.equal(diagnostic.message,
    `Inferred type nesting exceeds ${limit} levels`);
};

test('the inferred type limit is 1000', () => {
  assert.equal(unifier.inferredTypeLimit, limit);
});

test(`an inferred type exactly ${limit} deep checks`, () => {
  timed(() => checkedPoly(program(27, 37)));
});

test(`an inferred type ${limit + 1} deep is E_NESTING at its expression`,
  () => {
    rejectedAtDepth(125, 8, 8);
  });

// Formerly a RangeError in Unify `resolve` from 44 calls (about 5,600 deep).
test('deep(x: a): L^127(a) nested 44 deep is E_NESTING, not a crash', () => {
  rejectedAtDepth(127, 44, 8);
});

test('deep(x: a): L^127(a) nested 127 deep is E_NESTING, not a crash', () => {
  rejectedAtDepth(127, 127, 8);
});

// `deep(…(h))` is 1,000 deep when built, with h's type still a meta; the
// later `same(h, C(1, N))` binds that meta to L(Int), so the finished body
// holds a 1,001-deep type. The final bound reports the first holder in
// pre-order: `sink`'s instantiation, at the call to `sink`.
test('a type that deepens after it is built is E_NESTING at its holder',
  () => {
    const call = `sink(${calls(37, 'h')})`;
    const source = `${list}fn same(x: a, y: a): Int = 0; fn deep(x: a): `
      + `${'L('.repeat(27)}a${')'.repeat(27)} = deep(x); fn main(): Int =`
      + ` match N { C(h, t) => ${call} + same(h, C(1, N)), N => 0 };`;
    const diagnostic = timed(() => checkRejectedAt(source, 'E_NESTING', call));
    assert.equal(diagnostic.message,
      `Inferred type nesting exceeds ${limit} levels`);
  });

// Fix round 2: metas bound during one unification chain into each other,
// so the operands, each bounded beforehand, unify as types deeper than the
// limit. Positions bind h1 := D(h2), h2 := D(h3), … left to right while the
// inner metas are unbound; the last position unifies two chains, about
// 1,780 deep for two links of D7, which overflowed unify's recursion. The
// span is the argument whose unification failed: `same`'s second argument.
const chained = (links, nest) => {
  const named = prefix => Array.from({ length: links + 1 },
    (_, index) => `${prefix}${index + 1}`);
  const [h, g] = [named('h'), named('g')];
  const parameters = count => Array.from({ length: count },
    (_, index) => `t${index}`).join(', ');
  const wrapped = binder => calls(nest, binder);
  const left = `W(${[...h.slice(0, links), ...g.slice(0, links), h[0]]
    .join(', ')})`;
  const right = `W(${[...h.slice(1).map(wrapped), ...g.slice(1).map(wrapped),
    g[0]].join(', ')})`;
  const source = `${list}type T(${parameters(2 * links + 2)}) = Z`
    + ` | P(${parameters(2 * links + 2)}); type U(${parameters(2 * links + 1)})`
    + ` = W(${parameters(2 * links + 1)}) | V;`
    + ' fn same(x: a, y: a): Int = 0; fn deep(x: a): '
    + `${'L('.repeat(127)}a${')'.repeat(127)} = deep(x); fn main(): Int =`
    + ` match Z { P(${[...h, ...g].join(', ')}) => same(${left}, ${right}),`
    + ' Z => 0 };';
  return { source, right };
};

for (const [links, nest] of [[2, 7], [3, 4]]) {
  test(`${links} chained links of deep^${nest} are E_NESTING in unification`,
    () => {
      const { source, right } = chained(links, nest);
      const diagnostic = timed(() => checkRejectedAt(source, 'E_NESTING',
        right));
      assert.equal(diagnostic.message,
        `Inferred type nesting exceeds ${limit} levels`);
    });
}

// A meta bound, within the unification, to a type that earlier positions
// of the same unification made deeper than the limit: `g1 := h1`, where h1
// resolves to D7(D7(h3)).
test('a binding made too deep by its own unification is E_NESTING', () => {
  const right = `W(${calls(7, 'h2')}, ${calls(7, 'h3')}, h1)`;
  const source = `${list}type T(a, b, c, d) = Z | P(a, b, c, d);`
    + ' type U(a, b, c) = W(a, b, c); fn same(x: a, y: a): Int = 0;'
    + ` fn deep(x: a): ${'L('.repeat(127)}a${')'.repeat(127)} = deep(x);`
    + ' fn main(): Int = match Z { P(h1, h2, h3, g1) =>'
    + ` same(W(h1, h2, g1), ${right}), Z => 0 };`;
  const diagnostic = timed(() => checkRejectedAt(source, 'E_NESTING', right));
  assert.equal(diagnostic.message,
    `Inferred type nesting exceeds ${limit} levels`);
});
