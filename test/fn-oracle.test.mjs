import test from 'node:test';
import assert from 'node:assert/strict';
import { programs } from './fn-programs.mjs';
import { runGoBatch } from './go-batch.mjs';
import { interpret } from './poly-oracle.mjs';

// FN001 Task 7: generated programs over function values
// (test/fn-programs.mjs) run in Go, one batch, and must print what the
// independent interpreter (test/poly-oracle.mjs) computes. A failure names
// the seed (drawProgram(seed) regenerates it) and the source.
const batch = runGoBatch(import.meta.url,
  programs.map(({ source }, index) => [`f${index}`, source]));

test('generated programs use every function-value form', () => {
  const seen = new Set(programs.flatMap(({ features }) => [...features]));
  assert.deepEqual([...seen].sort(), ['capture', 'constructor', 'lambda',
    'over', 'partial', 'pipe', 'wildcard']);
  assert.ok(programs.length >= 30);
});

test('execution oracle: function-value programs print what the '
  + 'interpreter computes', () => {
  programs.forEach(({ seed, source }, index) => {
    const context = `seed ${seed}: ${source}`;
    let printed;
    try {
      printed = batch.run(`f${index}`);
    } catch (error) {
      assert.fail(`${context}\n${error.message}`);
    }
    assert.equal(printed, `${interpret(source)}\n`, context);
  });
});
