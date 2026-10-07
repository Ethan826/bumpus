// BACKLOG F004 proof: a promoted strict warning must fail every build, not
// only the build that first compiles the module. Runs in an isolated copy.
import assert from 'node:assert/strict';
import { appendFileSync, cpSync, mkdirSync, rmSync, symlinkSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { join, resolve } from 'node:path';
const root = '.build/strict-rebuild';
const copied = ['src', 'tools', 'scripts', 'spago.yaml', 'spago.lock', '.spago', 'output'];
const target = 'src/Domain/Host.purs';
// Shadows `x`: purs warns ShadowedName, which --strict promotes to an error.
const shadowing = '\nshadowProbe :: Int -> Int\nshadowProbe x = inner x\n'
  + '  where\n  inner x = x\n';
const buildTimeoutMs = 300_000;
const build = () => {
  const result = spawnSync('node', ['scripts/build.mjs'],
    { cwd: root, encoding: 'utf8', timeout: buildTimeoutMs });
  assert.ifError(result.error);
  return { status: result.status, output: result.stdout + result.stderr };
};
rmSync(root, { recursive: true, force: true });
mkdirSync(join(root, '.build'), { recursive: true });
for (const path of copied) cpSync(path, join(root, path), { recursive: true });
// Share the registry cache read by scripts/cache.mjs instead of copying it.
symlinkSync(resolve('.build/home'), join(root, '.build/home'));
const healthy = build();
assert.equal(healthy.status, 0, `unmodified copy must build\n${healthy.output}`);
appendFileSync(join(root, target), shadowing);
for (const attempt of ['first', 'second']) {
  const warned = build();
  assert.notEqual(warned.status, 0, `${attempt} build accepted a strict warning`);
  assert.match(warned.output, /ShadowedName/, `${attempt} build: other failure\n${warned.output}`);
}
rmSync(root, { recursive: true, force: true });
console.log('Strict rebuild proof: a promoted warning fails two consecutive builds.');
