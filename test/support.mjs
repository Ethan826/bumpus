import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { compile } from '../output/Sprig.Compiler/index.js';
import { Left, Right } from '../output/Data.Either/index.js';
import { codeName } from '../output/Sprig.Model/index.js';

export const checked = source => {
  const result = compile(source);
  assert.ok(result instanceof Right, JSON.stringify(result));
  return result.value0;
};

export const rejected = (source, code) => {
  const result = compile(source);
  assert.ok(result instanceof Left, 'invalid program compiled');
  assert.equal(codeName(result.value0.code), code);
  assert.ok(result.value0.message.length > 0);
  return result.value0;
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
  const work = mkdtempSync(join(tmpdir(), 'sprig-test-'));
  try {
    const go = join(work, 'main.go');
    const binary = join(work, 'program');
    writeFileSync(go, checked(source));
    command('go', ['build', '-o', binary, go]);
    return command(binary, []);
  } finally { rmSync(work, { recursive: true, force: true }); }
};
