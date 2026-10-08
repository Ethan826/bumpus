import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { compile } from '../output/Program.Compile/index.js';
import { Left, Right } from '../output/Data.Either/index.js';
import { wire } from '../output/Format.Diagnostic/index.js';

export const checked = source => {
  const result = compile(source);
  if (!(result instanceof Right)) assert.fail(JSON.stringify(result));
  return result.value0;
};

export const rejected = (source, code) => {
  const result = compile(source);
  assert.ok(result instanceof Left, 'invalid program compiled');
  const diagnostic = wire(result.value0);
  assert.equal(diagnostic.code, code);
  assert.ok(diagnostic.message.length > 0);
  return diagnostic;
};

export const command = (name, args, options = {}) => {
  const result = spawnSync(name, args, {
    encoding: 'utf8', timeout: 60000,
    env: { ...process.env, GOCACHE: resolve('.build/go-cache') }, ...options
  });
  assert.ifError(result.error);
  assert.equal(result.status, 0, `${name}: ${result.stderr}\n${result.stdout}`);
  return result.stdout;
};

export const runGo = source => {
  const work = mkdtempSync(join(tmpdir(), 'bumpus-test-'));
  try {
    const go = join(work, 'main.go');
    const binary = join(work, 'program');
    writeFileSync(go, checked(source));
    command('go', ['build', '-o', binary, go]);
    return command(binary, []);
  } finally { rmSync(work, { recursive: true, force: true }); }
};

export const spanAt = (source, text, nth = 0) => {
  let start = -1;
  for (let found = 0; found <= nth; found++) {
    start = source.indexOf(text, start + 1);
    assert.notEqual(start, -1, `${text} occurrence ${nth} not found`);
  }
  const position = offset => ({ offset, line: 1, column: offset + 1 });
  return { start: position(start), end: position(start + text.length) };
};

export const rejectedAt = (source, code, text, nth = 0) => {
  const diagnostic = rejected(source, code);
  assert.deepEqual(diagnostic.span, spanAt(source, text, nth));
  return diagnostic;
};

// Records each Bumpus function's entry in bumpusTrace, in call order.
export const traceCalls = goSource => goSource.replace(
  /func bumpusFn(\d+)\([^\n]*\) [^\n]* \{\n/g,
  (header, index) => `${header}bumpusTrace = append(bumpusTrace, "${index}")\n`
);

// FN001 timing probes: bumpusFn<index> panics with `bumpus-probe: <label>`
// as its first statement, so a run shows which probe its body entered
// first. Exactly one header must match.
export const panicOnEntry = (goSource, functionIndex, label) => {
  const header = new RegExp(`^func bumpusFn${functionIndex}\\([^\\n]*\\) `
    + '[^\\n]* \\{\\n', 'gm');
  assert.equal((goSource.match(header) ?? []).length, 1,
    `one header for bumpusFn${functionIndex}`);
  return goSource.replace(header,
    found => `${found}panic("bumpus-probe: ${label}")\n`);
};

export const goTest =(source, testGo, transform = go => go) => {
  const work = mkdtempSync(join(tmpdir(), 'bumpus-gotest-'));
  try {
    writeFileSync(join(work, 'main.go'), transform(checked(source)));
    writeFileSync(join(work, 'main_test.go'), testGo);
    const result = spawnSync('go', ['test', 'main.go', 'main_test.go'], {
      encoding: 'utf8', timeout: 120000, cwd: work,
      env: { ...process.env, GOCACHE: resolve('.build/go-cache') }
    });
    assert.ifError(result.error);
    return { status: result.status, output: result.stdout + result.stderr };
  } finally { rmSync(work, { recursive: true, force: true }); }
};
