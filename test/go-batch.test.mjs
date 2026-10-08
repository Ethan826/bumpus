// Self-tests of the per-file Go batch harness (T001, test/go-batch.mjs).
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import {
  existsSync, mkdirSync, mkdtempSync, rmSync, writeFileSync
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import test from 'node:test';
import { checked, command, runGo } from './support.mjs';
import { asCasePackage, batchId, runGoBatch } from './go-batch.mjs';

const answer = 'fn main(): Int = 42;';
const nullary = 'type N = A | B; fn main(): N = A;';
// Builds a constructor no Bumpus program can: tag 9 of a two-constructor
// type, so printing main's value panics.
const malformed = go => {
  const ctor = 'return bumpusTy0{tag: 1}';
  assert.equal(go.split(ctor).length, 2, 'one tag-1 constructor');
  return go.replace(ctor, 'return bumpusTy0{tag: 9}');
};
const thrown = action => {
  try { action(); } catch (error) { return error; }
  return assert.fail('expected a throw');
};

test('a rejected case fails alone, with the runGo message', () => {
  const bad = 'fn main(): Int = true;';
  const batch = runGoBatch(import.meta.url, { good: answer, bad }, 'reject');
  assert.equal(batch.run('good'), '42\n');
  const expected = thrown(() => runGo(bad));
  const actual = thrown(() => batch.run('bad'));
  assert.equal(actual.constructor, expected.constructor);
  assert.equal(actual.message, expected.message);
});

test('ill-formed generated Go fails the batch, naming its case', () => {
  const broken = {
    source: answer, transform: go => `${go}\nfunc broken() { undefinedName }\n`
  };
  const batch = runGoBatch(import.meta.url,
    { healthy: answer, broken }, 'ill-formed');
  for (const name of ['healthy', 'broken']) {
    const error = thrown(() => batch.run(name));
    assert.match(error.message, /failed to compile/, name);
    assert.match(error.message, /offending case\(s\): "broken"$/m, name);
    assert.match(error.message, /undefinedName/, name);
  }
});

test('a panicking case matches its standalone program', () => {
  const batch = runGoBatch(import.meta.url, {
    sibling: answer, panics: { source: nullary, transform: malformed }
  }, 'panic');
  assert.equal(batch.run('sibling'), '42\n');
  const work = mkdtempSync(join(tmpdir(), 'bumpus-batch-test-'));
  try {
    writeFileSync(join(work, 'main.go'), malformed(checked(nullary)));
    command('go', ['build', '-o', join(work, 'program'), 'main.go'],
      { cwd: work });
    const alone = spawnSync(join(work, 'program'), [], { encoding: 'utf8' });
    const batched = batch.result('panics');
    assert.notEqual(alone.status, 0);
    assert.equal(batched.status, alone.status);
    assert.equal(batched.stdout, alone.stdout);
    const first = text => text.split('\n')[0];
    assert.equal(first(alone.stderr), 'panic: bumpus: malformed value');
    assert.equal(first(batched.stderr), first(alone.stderr));
    assert.match(thrown(() => batch.run('panics')).message,
      /panic: bumpus: malformed value/);
  } finally { rmSync(work, { recursive: true, force: true }); }
});

test('the rewrite guard rejects unexpected shapes, naming the case', () => {
  const go = checked(answer);
  assert.match(asCasePackage('fine', 'c0', go), /^package c0$/m);
  const shapes = {
    'two package clauses':
      go.replace('package main', 'package main\npackage main'),
    'another package': go.replace('package main', 'package other'),
    'two mains': `${go}\nfunc main() { fmt.Println(1) }\n`,
    'multiline main': go.replace(/^func main\(\) \{ /m, 'func main() {\n'),
    'existing Main': `${go}\nfunc Main() {}\n`
  };
  for (const [name, shape] of Object.entries(shapes)) {
    assert.throws(() => asCasePackage(name, 'c0', shape),
      new RegExp(`case "${name}" has an unexpected shape`), name);
  }
  const batch = runGoBatch(import.meta.url, { healthy: answer, odd: {
    source: answer,
    transform: shape => shape.replace('package main', 'package x')
  } }, 'guard');
  for (const name of ['healthy', 'odd']) {
    assert.match(thrown(() => batch.run(name)).message,
      /case "odd" has an unexpected shape/, name);
  }
});

test('a batch clears only its own deterministic directory', () => {
  const id = batchId(import.meta.url, 'own dir');
  assert.equal(id, 'go-batch.test.mjs-own-dir'.replace(/\./g, '-'));
  const root = resolve('.build/go-batches');
  const neighbour = join(root, batchId(import.meta.url, 'neighbour'));
  mkdirSync(neighbour, { recursive: true });
  writeFileSync(join(neighbour, 'marker'), '');
  mkdirSync(join(root, id), { recursive: true });
  writeFileSync(join(root, id, 'stale'), '');
  const batch = runGoBatch(import.meta.url, { answer }, 'own dir');
  assert.equal(batch.run('answer'), '42\n');
  assert.ok(existsSync(join(root, id, 'go.mod')), 'synthetic go.mod');
  assert.ok(!existsSync(join(root, id, 'stale')), 'own directory cleared');
  assert.ok(existsSync(join(neighbour, 'marker')), 'neighbour untouched');
  assert.throws(() => runGoBatch(import.meta.url, { answer }, 'own dir'),
    /already claimed/);
});
