import test from 'node:test';
import assert from 'node:assert/strict';
import { expectedOutcome, forms, throughSpecialize } from './fn-linear-forms.mjs';

// FN001 Task 8 Step 1b: each function form at 20,000 parameters through
// Specialize, bounded at three times its time measured 2026-10-09 on the
// author's laptop (in this order, one process, load about 3; ms): value
// 392-400, over 536-544, lambda 504-524, mismatch 172-173, partialFirst
// 309-310, partialAll 219-232, parenthesized 365-370, pipe 241-263. At
// 80,000 the same forms took about four times as long (linear), and
// test/fn-linear.serial.test.mjs checks that they finish without a stack
// failure there.
const width = 20000;
const measuredMs = { value: 400, over: 540, lambda: 515, mismatch: 175,
  partialFirst: 310, partialAll: 225, parenthesized: 370, pipe: 250 };

for (const [name, form] of Object.entries(forms)) {
  test(`${name} at ${width} parameters is linear through Specialize`, t => {
    const { elapsedMs, outcome } = throughSpecialize(form(width));
    t.diagnostic(`${Math.round(elapsedMs)} ms, bound ${3 * measuredMs[name]}`);
    assert.equal(outcome, expectedOutcome(name));
    assert.ok(elapsedMs <= 3 * measuredMs[name], `took ${elapsedMs} ms`);
  });
}
