import test from 'node:test';
import assert from 'node:assert/strict';
import { wire } from '../output/Format.Diagnostic/index.js';
import * as names from '../output/Features.Check.RowName/index.js';
import { toRow, rigid, int, bool } from './unify-support.mjs';

const env = { effects: [{ name: 'Log' }, { name: 'State' }],
  types: [], variables: ['', 'e'] };
const span = { start: { offset: 0, line: 1, column: 1 },
  end: { offset: 0, line: 1, column: 1 } };
const rendered = row => {
  const result = names.rowName(env)(span)(toRow(row));
  assert.equal(result.constructor.name, 'Right');
  return result.value0;
};
const labels = [{ e: 0, args: [] }, { e: 1, args: [int] },
  { e: 1, args: [bool] }];

test('row names preserve labels, multiplicity and named tails', () => {
  assert.equal(rendered({ labels, tail: rigid(1) }),
    'Log + State(Int) + State(Bool) + ...e');
});
test('closed empty and ambient rows print distinctly', () => {
  assert.equal(rendered({ labels: [], tail: null }), 'pure');
  assert.equal(rendered({ labels: [], tail: rigid(0) }), '...');
});
test('1000 labels print without one stack frame per label', () => {
  const many = Array.from({ length: 1000 }, () => labels[0]);
  assert.equal(rendered({ labels: many, tail: null }),
    Array(1000).fill('Log').join(' + '));
});

test('shared-tail row conflicts name both ordered rows and the tail', () => {
  const left = toRow({ labels: [labels[0]], tail: rigid(1) });
  const right = toRow({ labels: [labels[1]], tail: rigid(1) });
  const failure = names.rowConflict(env)(span)(left)(right);
  assert.equal(failure.constructor.name, 'Left');
  assert.deepEqual(wire(failure.value0), { code: 'E_EFFECT', span,
    related: [], message: 'Log + ...e and State(Int) + ...e'
      + ' cannot be made equal: both end in ...e' });
});
