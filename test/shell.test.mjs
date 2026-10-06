import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';

test('usage, filesystem, and Go tool failures remain distinct boundary tags', () => {
  for (const [args, code, status, options] of [
    [[], 'E_USAGE', 2, {}],
    [['run', '.build/does-not-exist.sprig'], 'E_IO', 1, {}],
    [['run', 'examples/answer.sprig'], 'E_TOOL', 1, { env: { ...process.env, PATH: '' } }]
  ]) {
    const result = spawnSync(process.execPath, ['scripts/sprig.mjs', ...args], { encoding: 'utf8', ...options });
    assert.ifError(result.error);
    assert.equal(result.status, status);
    assert.equal(JSON.parse(result.stderr).code, code);
  }
});
