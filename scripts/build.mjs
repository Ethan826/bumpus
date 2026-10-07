import { spawnSync } from 'node:child_process';
import { resolve, join } from 'node:path';
import { mkdirSync, readdirSync, readFileSync, rmSync } from 'node:fs';
// Spago --strict reports a promoted warning only on the build that compiles
// the module (BACKLOG F004). Removing every workspace module's output makes
// each build recompile them, so a warning fails every build, not just the
// first. Dependency output stays cached.
const workspaceSources = ['src', 'tools/style/src'];
const moduleName = file => readFileSync(file, 'utf8').match(/^module\s+([\w.]+)/m)?.[1];
const pursFiles = root => readdirSync(root, { recursive: true })
  .filter(name => name.endsWith('.purs')).map(name => join(root, name));
for (const file of workspaceSources.flatMap(pursFiles)) {
  const name = moduleName(file);
  if (name === undefined) throw new Error(`${file}: no module header`);
  rmSync(join('output', name), { recursive: true, force: true });
}
mkdirSync('.build/home', { recursive: true });
const result = spawnSync('spago', ['build', '--strict', '--pedantic-packages', ...process.argv.slice(2)], {
  stdio: 'inherit',
  env: { ...process.env, NODE_OPTIONS: `${process.env.NODE_OPTIONS ?? ''} --import=${resolve('scripts/cache.mjs')}` }
});
if (result.error) console.error(result.error.message);
process.exitCode = result.status ?? 1;
