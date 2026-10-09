import test from 'node:test';
import assert from 'node:assert/strict';
import { expectedOutcome, forms, throughSpecialize } from './fn-linear-forms.mjs';

// FN001 Task 8 Step 1b: each function form at 80,000 parameters reaches
// its outcome without a stack failure (a RangeError would throw). Serial
// (scripts/verify.mjs runs `*.serial.test.mjs` after the parallel phase):
// together they take about 13 s. No time bound here; test/fn-linear.test.mjs
// bounds the same forms at 20,000.
const width = 80000;

for (const [name, form] of Object.entries(forms)) {
  test(`${name} at ${width} parameters needs no deep stack`, () => {
    assert.equal(throughSpecialize(form(width)).outcome, expectedOutcome(name));
  });
}
