import { spawnSync } from 'node:child_process';
import { resolve } from 'node:path';
import { mkdirSync } from 'node:fs';
mkdirSync('.build/home', { recursive: true });
const result = spawnSync('spago', ['build', '--strict', '--pedantic-packages', ...process.argv.slice(2)], {
  stdio: 'inherit',
  env: { ...process.env, NODE_OPTIONS: `${process.env.NODE_OPTIONS ?? ''} --import=${resolve('scripts/cache.mjs')}` }
});
if (result.error) console.error(result.error.message);
process.exitCode = result.status ?? 1;
