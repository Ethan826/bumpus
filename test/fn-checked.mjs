// Compact renderings of FN001 checked programs for tests: a checked
// expression is shown as its node, so a tree states structure alone, and
// its types are asserted separately. Spans are left out.
import assert from 'node:assert/strict';
import { wire } from '../output/Format.Diagnostic/index.js';
import { check } from '../output/Features.Check/index.js';
import { checkedPoly, resolved } from './phases.mjs';
import { spanAt } from './support.mjs';

const isSpan = value => value !== null && typeof value === 'object'
  && 'start' in value && 'end' in value;

const fieldsOf = value => Object.keys(value)
  .filter(key => /^value\d+$/.test(key)).map(key => value[key])
  .filter(field => !isSpan(field));

export const tree = value => {
  if (Array.isArray(value)) return `[${value.map(tree).join(', ')}]`;
  if (value === null || typeof value !== 'object') return String(value);
  const name = value.constructor.name;
  if (name === 'Expr') return tree(value.value0.node);
  if (name === 'Object') {
    const keys = Object.keys(value).filter(key => !isSpan(value[key])).sort();
    return `{${keys.map(key => `${key}: ${tree(value[key])}`).join(', ')}}`;
  }
  const fields = fieldsOf(value);
  return fields.length === 0 ? name : `${name}(${fields.map(tree).join(', ')})`;
};

// The checked declaration named `name`.
export const declared = (source, name) => {
  const found = checkedPoly(source).functions.find(f => f.name === name);
  assert.ok(found, `no function ${name}`);
  return found;
};

export const bodyTree = (source, name) => tree(declared(source, name).body);

export const bodyType = (source, name) =>
  tree(declared(source, name).body.value0.ty);

// The occurrence of `text` that is the first at or after `marker`.
export const after = (source, marker, text) => {
  const from = source.indexOf(marker);
  assert.notEqual(from, -1, `${marker} not found`);
  return source.slice(0, from).split(text).length - 1;
};

// Check's raw diagnostic for a source that resolves: its problem and span.
export const checkFailure = source => {
  const result = check(resolved(source));
  assert.equal(result.constructor.name, 'Left', `accepted: ${source}`);
  return result.value0;
};

// Expects Check to reject at the first `text` at or after `marker`.
export const failsAt = (source, marker, text) => {
  const diagnostic = wire(checkFailure(source));
  assert.deepEqual(diagnostic.span,
    spanAt(source, text, after(source, marker, text)), diagnostic.message);
  return diagnostic;
};
