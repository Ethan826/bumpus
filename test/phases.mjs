// Runs a source through a prefix of the pipeline. Before P001 Task 7 the
// full `compile` could not emit a polymorphic program, so Tasks 2–6 stop
// at Resolve or Check (plan, "Phase boundaries for tests"); since Task 7
// `compile` specializes and emits them (test/poly-run.test.mjs).
import assert from 'node:assert/strict';
import { Left, Right } from '../output/Data.Either/index.js';
import { parse } from '../output/Format.Parse/index.js';
import { resolve } from '../output/Features.Resolve/index.js';
import { check } from '../output/Features.Check/index.js';
import { wire } from '../output/Format.Diagnostic/index.js';
import { spanAt } from './support.mjs';

const succeeded = (result, source) => {
  assert.ok(result instanceof Right, `${source}\n${JSON.stringify(result)}`);
  return result.value0;
};

const rejectedWith = (result, source, code, text, nth) => {
  assert.ok(result instanceof Left, `accepted: ${source}`);
  const diagnostic = wire(result.value0);
  assert.equal(diagnostic.code, code, diagnostic.message);
  assert.deepEqual(diagnostic.span, spanAt(source, text, nth));
  return diagnostic;
};

// Parse then resolve; returns the resolved program.
export const resolved = source =>
  succeeded(resolve(succeeded(parse(source), source)), source);

// Parses, then expects Resolve to reject at the nth occurrence of `text`.
export const resolveRejectedAt = (source, code, text, nth = 0) =>
  rejectedWith(resolve(succeeded(parse(source), source)), source, code, text,
    nth);

// Parse, resolve and check; returns the checked program.
export const checkedPoly = source => succeeded(check(resolved(source)), source);

// Resolves, then expects Check to reject at the nth occurrence of `text`.
export const checkRejectedAt = (source, code, text, nth = 0) =>
  rejectedWith(check(resolved(source)), source, code, text, nth);
