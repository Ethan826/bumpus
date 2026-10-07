import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { forms } from '../scripts/depth-forms.mjs';
import { nestingLimit } from '../output/Format.Parse.Grammar/index.js';

// E_NESTING (ADR 006), through the CLI: per form, depth = limit compiles,
// builds and runs; depth = limit + 1 is E_NESTING at the token that would
// exceed it. No run may print a raw RangeError or JavaScript stack frames.
const limit = nestingLimit;
const work = mkdtempSync(join(tmpdir(), 'bumpus-depth-'));
after(() => rmSync(work, { recursive: true, force: true }));

const cli = (verb, source) => {
  const input = join(work, 'input.bumpus');
  writeFileSync(input, source);
  const extra = verb === 'emit' ? [join(work, 'output.go')] : [];
  const result = spawnSync('node',
    ['scripts/bumpus.mjs', verb, input, ...extra],
    { encoding: 'utf8', timeout: 120000,
      env: { ...process.env, GOCACHE: resolve('.build/go-cache') } });
  assert.ifError(result.error);
  const output = result.stdout + result.stderr;
  assert.doesNotMatch(output, /RangeError|Stack overflow/, 'raw overflow');
  assert.doesNotMatch(output, /^\s+at /m, 'JavaScript stack frames');
  return result;
};

const position = offset => ({ line: 1, offset, column: offset + 1 });

const nestingAt = (program) => {
  const result = cli('emit', program.source);
  assert.equal(result.status, 1, `accepted: ${result.stderr}`);
  const diagnostic = JSON.parse(result.stderr);
  assert.deepEqual(
    { code: diagnostic.code, message: diagnostic.message,
      span: diagnostic.span },
    { code: 'E_NESTING', message: `Nesting exceeds ${limit} levels`,
      span: { start: position(program.at),
        end: position(program.at + program.text.length) } });
  assert.equal(program.source.slice(program.at,
    program.at + program.text.length), program.text, 'fixture offset');
};

const runs = (program) => {
  const result = cli('run', program.source);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, program.output);
};

// BACKLOG E005: `go build` is exponential in nested match arms (each a
// nested immediately invoked closure): 0.25 s at 16 levels, 34.6 s and
// 7.5 GB at 24, killed at 128. These compile at the limit and run at 16.
const goBlowup =
  { depth: 16, forms: new Set(['match-arm', 'compare-matches']) };

for (const [name, form] of Object.entries(forms)) {
  if (goBlowup.forms.has(name)) {
    test(`${name}: depth ${limit} compiles; depth ${goBlowup.depth} runs`,
      () => {
        assert.equal(cli('emit', form(limit).source).status, 0);
        runs(form(goBlowup.depth));
      });
  } else {
    test(`${name}: depth ${limit} compiles, builds and runs`, () => {
      runs(form(limit));
    });
  }

  test(`${name}: depth ${limit + 1} is E_NESTING`, () => {
    nestingAt(form(limit + 1));
  });
}

// Review Focus 1: the depth bookkeeping does not mask an ordinary error.
test(`a syntax error at depth ${limit - 1} is still E_SYNTAX`, () => {
  const depth = limit - 1;
  const before = `fn main(): Int = ${'('.repeat(depth)}`;
  const result = cli('emit', `${before}+${')'.repeat(depth)};`);
  assert.equal(result.status, 1);
  const diagnostic = JSON.parse(result.stderr);
  assert.deepEqual(
    { code: diagnostic.code, message: diagnostic.message,
      span: diagnostic.span },
    { code: 'E_SYNTAX', message: 'Expected an expression',
      span: { start: position(before.length),
        end: position(before.length + 1) } });
});

// Sibling subtrees do not add up: only one root-to-leaf path counts, and
// each declaration body starts afresh (g follows main, which is at the limit).
test('siblings and later declarations do not add depth', () => {
  const deep = `${'('.repeat(limit - 1)}1${')'.repeat(limit - 1)}`;
  const source = `fn f(x: Int, y: Int): Int = x + y; `
    + `fn main(): Int = f(${deep}, ${deep}); `
    + `fn g(): Int = ${deep} + 1;`;
  const result = cli('run', source);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, '2\n');
});
