import assert from 'node:assert/strict';
import { cpSync, mkdirSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
// Each row restores one defect in its own isolated copy of the sources.
const rows = [
  {
    name: 'branch', file: 'src/Features/Check.purs',
    needle: 'second ← infer env no\n  require env (IR.typeOf first) second',
    replacement: 'second ← infer env no\n  require env (IR.typeOf second) second',
    probe: 'branch', message: /branch type mismatch was accepted/
  },
  {
    name: 'nil-guard', file: 'src/Format/Go/Match.purs',
    needle: 'nilGuard path = path <> " != nil"',
    replacement: 'nilGuard _ = "true"',
    probe: 'nil-guard', message: /nil guard missing/
  },
  {
    name: 'exhaustive', file: 'src/Features/Check/Coverage.purs',
    needle: 'uncovered signature',
    replacement: 'const (const (Right Nothing))',
    probe: 'exhaustive', message: /non-exhaustive match was accepted/
  },
  {
    name: 'ctor-order', file: 'src/Format/Go/Compare.purs',
    needle: 'if a.tag < b.tag { return -1 }',
    replacement: 'if a.tag > b.tag { return -1 }',
    probe: 'ctor-order', message: /constructor order wrong/
  },
  {
    name: 'first-field', file: 'src/Format/Go/Compare.purs',
    needle: '(Array.mapWithIndex field ctor.fields)',
    replacement: '(Array.reverse (Array.mapWithIndex field ctor.fields))',
    probe: 'first-field', message: /first differing field ignored/
  }
];
const base = '.build/regression';
const commandTimeoutMs = 180_000;
const run = (command, args) => spawnSync(command, args, { encoding: 'utf8', timeout: commandTimeoutMs });
rmSync(base, { recursive: true, force: true });
for (const row of rows) {
  const root = `${base}/${row.name}`;
  mkdirSync(root, { recursive: true });
  cpSync('src', `${root}/src`, { recursive: true });
  const file = `${root}/${row.file}`;
  const original = readFileSync(file, 'utf8');
  assert.equal(original.split(row.needle).length, 2, `${row.name}: mutation must have exactly one target`);
  writeFileSync(file, original.replace(row.needle, row.replacement));
  const built = run('purs', ['compile', `${root}/src/**/*.purs`, '.spago/p/*/src/**/*.purs', '--output', `${root}/output`]);
  assert.ifError(built.error);
  assert.equal(built.status, 0, built.stderr);
  const healthy = run('node', ['test/regression.mjs', 'output/Program.Compile/index.js', 'output', row.probe]);
  assert.ifError(healthy.error);
  assert.equal(healthy.status, 0, healthy.stderr);
  const broken = run('node', ['test/regression.mjs', `${root}/output/Program.Compile/index.js`, `${root}/output`, row.probe]);
  assert.ifError(broken.error);
  assert.equal(broken.status, 1, broken.stdout + broken.stderr);
  assert.match(broken.stderr, row.message);
  console.log(`Regression proof (${row.name}): fixed compiler passes; restored defect fails.`);
}
