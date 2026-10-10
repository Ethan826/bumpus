// Running one generated program through the compiler and Go, and writing a
// differing program's evidence (FX001 differential corpus).
import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { checked } from './support.mjs';

export const evidenceDirectory = '.build/fx001-differential';

// What the compiled program prints and how it exits. A rejection throws.
export const goOutcome = source => {
  const work = mkdtempSync(join(tmpdir(), 'waxwing-fx-'));
  try {
    const go = join(work, 'main.go');
    writeFileSync(go, checked(source));
    const env = { ...process.env, GOCACHE: resolve('.build/go-cache') };
    const built = spawnSync('go', ['build', '-o', join(work, 'program'), go],
      { encoding: 'utf8', timeout: 120000, env });
    if (built.status !== 0) throw new Error(`go build: ${built.stderr}`);
    const ran = spawnSync(join(work, 'program'), [],
      { encoding: 'utf8', timeout: 60000, env });
    return { stdout: ran.stdout, stderr: ran.stderr, status: ran.status };
  } finally { rmSync(work, { recursive: true, force: true }); }
};

export const same = (expected, actual) => ['stdout', 'stderr', 'status']
  .every(field => expected[field] === actual[field]);

export const saveEvidence = (name, files) => {
  mkdirSync(evidenceDirectory, { recursive: true });
  for (const [suffix, content] of Object.entries(files)) {
    writeFileSync(join(evidenceDirectory, `${name}${suffix}`), content);
  }
};
