import assert from 'node:assert/strict';
import { mkdirSync, readdirSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { checkStructure } from './structure.mjs';
mkdirSync('.build', { recursive: true });
const run = (command, args) => {
  const result = spawnSync(command, args, { stdio: 'inherit' });
  assert.ifError(result.error);
  assert.equal(result.status, 0, `${command} failed`);
};
const purs = spawnSync('purs', ['--version'], { encoding: 'utf8' });
assert.ifError(purs.error);
assert.equal(purs.status, 0);
assert.equal(purs.stdout.trim(), '0.15.16', 'use the pinned PureScript compiler');
const spago = spawnSync('spago', ['--version'], { encoding: 'utf8' });
assert.ifError(spago.error);
assert.equal(spago.status, 0);
assert.equal(spago.stdout.trim(), '1.0.4', 'use the pinned Spago');
const tidy = spawnSync('purs-tidy', ['--version'], { encoding: 'utf8' });
assert.ifError(tidy.error);
assert.equal(tidy.status, 0);
assert.equal((tidy.stdout + tidy.stderr).trim(), 'v0.11.1', 'use the pinned formatter');
run('purs-tidy', ['check', 'src', 'tools/style/src']);
run('node', ['scripts/build.mjs']);
assert.deepEqual(await checkStructure(), [], 'structural gates');
// Every test file runs; a hand-kept list could silently omit a new one.
const tests = readdirSync('test').filter(name => name.endsWith('.test.mjs'))
  .sort().map(name => `test/${name}`);
assert.ok(tests.length > 0, 'no test files found');
run('node', ['--test', ...tests]);
run('node', ['scripts/regression.mjs']);
console.log('Verified compiler, gates, executable programs, rejection diagnostics, properties, and regression proofs.');
