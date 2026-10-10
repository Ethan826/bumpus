import assert from 'node:assert/strict';
import { Left } from '../output/Data.Either/index.js';
import { compile } from '../output/Program.Compile/index.js';
import { wire } from '../output/Format.Diagnostic/index.js';

// FX001 Task 9 (design §6): effect errors name the row difference first,
// point at the actionable expression, and carry notes for the origin, the
// call path and the rejecting boundary, within fixed bounds.
export const maxCharacters = 2000;

export const diagnose = source => {
  const result = compile(source);
  assert.ok(result instanceof Left, 'program compiled');
  return { diagnostic: wire(result.value0), problem: result.value0.problem };
};

const offsets = span => [span.start.offset, span.end.offset];

// `inner` within the first `container` (or the container itself), searched
// from `from` characters into it.
export const within = (source, container, inner = container, from = 0) => {
  const outer = source.indexOf(container);
  assert.notEqual(outer, -1, container);
  const start = source.indexOf(inner, outer + from);
  assert.ok(start >= outer && start + inner.length <= outer + container.length,
    `${inner} in ${container}`);
  return [start, start + inner.length];
};

export const length = diagnostic => diagnostic.message.length
  + diagnostic.related.reduce((sum, note) => sum + note.message.length, 0);

// `shape.at` is [container, inner, from] for the primary span; notes are
// [container, inner, message, from], in order: the order is the contract.
export const expectDiagnostic = (source, shape) => {
  const { diagnostic } = diagnose(source);
  assert.equal(diagnostic.code, shape.code);
  assert.equal(diagnostic.message, shape.message);
  assert.deepEqual(offsets(diagnostic.span), within(source, ...shape.at));
  assert.deepEqual(
    diagnostic.related.map(note => [offsets(note.span), note.message]),
    shape.notes.map(([container, inner, message, from]) =>
      [within(source, container, inner, from), message]));
  assert.ok(length(diagnostic) <= maxCharacters,
    `${length(diagnostic)} characters`);
  return diagnostic;
};

export const database = 'effect Database { fn query(): Int; }; ';
export const log = 'effect Log { fn log(n: Int): Unit; }; ';
export const clock = 'effect Clock { fn now(): Int; }; ';
export const state = 'effect State(s) { fn get(): s; fn put(value: s): Unit; }; ';
export const db = 'type DbError = DbError; ';
