import test from 'node:test';
import assert from 'node:assert/strict';
import { compile } from '../output/Program.Compile/index.js';
import { Right } from '../output/Data.Either/index.js';
import { manyLets } from './fx-block-programs.mjs';

// FX001 Task 2: a long block through a long Bumpus phase against a fixed
// bound, so it runs serially, not under the parallel runner's load (as
// test/fn-linear.serial.test.mjs; under that load it took 999 ms of 1,500).
// 20,000 let items, each reading the one before, through the whole
// compiler to Go text, bounded at three times the time measured on the
// author's laptop (2026-10-09, one process, load about 3: 490-510 ms; 40,000
// took 915 ms and 80,000 1,739 ms, linear; docs/progress.md FX001 Task 2).
const measuredMs = 500;
test('20,000 let items compile in linear time', t => {
  const source = manyLets(20000);
  const started = performance.now();
  const result = compile(source);
  const elapsedMs = performance.now() - started;
  t.diagnostic(`${Math.round(elapsedMs)} ms, bound ${3 * measuredMs}`);
  assert.ok(result instanceof Right, 'compiled');
  assert.ok(elapsedMs <= 3 * measuredMs, `took ${elapsedMs} ms`);
});
