import test from 'node:test';
import assert from 'node:assert/strict';
import { checked } from './support.mjs';

// E005 review: capture sets come from one bottom-up pass. Re-scanning each
// lifted match's subtree made this 127-deep, 50-arm ladder (about 147 KB)
// take 3.0 s to compile, against 0.27 s for the closure compiler.
const compileBudgetMs = 1500;
const ladderDepth = 127;
const ladderWidth = 50;

test('a deep, wide match ladder compiles in under 1.5 s', () => {
  const arms = Array.from({ length: ladderWidth - 1 },
    (_, value) => `${value} => f(p, q, r, s, t), `).join('');
  const source = 'fn f(p: Int, q: Int, r: Int, s: Int, t: Int): Int = '
    + `match p { ${arms}_ => `.repeat(ladderDepth) + 'q'
    + ' }'.repeat(ladderDepth) + '; fn main(): Int = f(1, 2, 3, 4, 5);';
  const started = performance.now();
  checked(source);
  const elapsed = performance.now() - started;
  assert.ok(elapsed < compileBudgetMs, `took ${elapsed} ms`);
});
