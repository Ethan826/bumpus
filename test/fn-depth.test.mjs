import test from 'node:test';
import assert from 'node:assert/strict';
import { functionForms } from '../scripts/depth-forms.mjs';
import { nestingLimit } from '../output/Format.Parse.Grammar/index.js';
import { rejectedAt } from './support.mjs';
import { resolved } from './phases.mjs';

// FN001 Task 3: the function nesting forms of scripts/depth-forms.mjs
// through Parse and Resolve (ADR 006, Functions). They join
// test/depth.test.mjs, through the CLI, once Go emits them (Task 6).
const message = `Nesting exceeds ${nestingLimit} levels`;

for (const [name, form] of Object.entries(functionForms)) {
  test(`${name}: depth ${nestingLimit} resolves, one more is E_NESTING`,
    () => {
      resolved(form(nestingLimit).source);
      const over = form(nestingLimit + 1);
      const nth = over.source.slice(0, over.at).split(over.text).length - 1;
      assert.equal(rejectedAt(over.source, 'E_NESTING', over.text, nth)
        .message, message);
    });
}

// A parenthesized type raises its contents' depth by one while they are
// parsed and adds nothing to the measure passed outward, so one redundant
// pair at the limit is E_NESTING.
const listed = (depth, inner) => `type L(a) = N; fn f(g: ${'L('.repeat(depth)}`
  + `${inner}${')'.repeat(depth)}): Int = 0; fn main(): Int = 0;`;

test('a redundant parenthesis pair at the limit is E_NESTING', () => {
  resolved(listed(nestingLimit - 1, 'Int -> Int'));
  resolved(listed(nestingLimit, 'Int'));
  assert.equal(rejectedAt(listed(nestingLimit - 1, '(Int -> Int)'),
    'E_NESTING', '->').message, message);
  assert.equal(rejectedAt(listed(nestingLimit, '(Int)'), 'E_NESTING', 'Int')
    .message, message);
});
