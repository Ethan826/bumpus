// Builds a test file's Go programs once (T001). Each case becomes one package
// of a synthetic module under .build/go-batches/<id>/, a dispatcher main
// imports them all, and each case then runs as its own process: the shared
// binary invoked with the case's package name. Failure contract
// (docs/engineering.md): a Waxwing rejection fails only its own case, with
// runGo's message; anything wrong with the generated Go (unexpected shape,
// compile error) fails every case of the batch, naming the offending case
// when Go's output identifies it.
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { basename, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { checked, command } from './support.mjs';

const modulePath = 'waxwingbatch';
const buildTimeoutMs = 300_000;
// The module's language version is the pinned toolchain's, as a
// command-line build of main.go would use.
const goVersion = JSON.parse(readFileSync('package.json', 'utf8'))
  .toolchain.go.split('.').slice(0, 2).join('.');
// Files run in parallel processes; ids are per file, so only a reuse inside
// one file could collide, and that is refused.
const claimed = new Set();

export const batchId = (file, label = '') => {
  const path = file.startsWith('file:') ? fileURLToPath(file) : file;
  return `${basename(path)}${label ? `-${label}` : ''}`
    .replace(/[^A-Za-z0-9_-]/g, '-');
};

// Checked, structural rewrite: the program must have exactly the emitted
// shape (Format.Go's entryMain) or the case is refused by name.
export const asCasePackage = (name, ident, go) => {
  const count = pattern => (go.match(pattern) ?? []).length;
  const expected = count(/^package \w+$/gm) === 1
    && count(/^package main$/gm) === 1
    && count(/^func main\b/gm) === 1
    && (count(/^func main\(\) \{ (defer waxwingReport\(\); )?fmt\.Println\(.*\) \}$/gm)
      + count(/^func main\(\) \{ (defer waxwingReport\(\); )?waxwingFn\d+\((nil)?\) \}$/gm)) === 1
    && count(/^func Main\b/gm) === 0;
  if (!expected) {
    throw new assert.AssertionError({ message: `go batch: case `
      + `${JSON.stringify(name)} has an unexpected shape (need one `
      + '"package main" and one canonical printed or Unit main)' });
  }
  return go.replace(/^package main$/m, `package ${ident}`)
    .replace(/^func main\(\) \{ /m, 'func Main() { ');
};

const dispatch = ident => `\tcase "${ident}":\n\t\t${ident}.Main()\n`;
const dispatcher = idents => `package main

import (
\t"fmt"
\t"os"
${idents.map(ident => `\t${ident} "${modulePath}/${ident}"\n`).join('')})

func main() {
\tif len(os.Args) != 2 {
\t\tfmt.Fprintln(os.Stderr, "usage: program <case>")
\t\tos.Exit(2)
\t}
\tswitch os.Args[1] {
${idents.map(dispatch).join('')}\tdefault:
\t\tfmt.Fprintln(os.Stderr, "unknown case", os.Args[1])
\t\tos.Exit(2)
\t}
}
`;

const batchFailure = (id, reason, offending, detail) =>
  new assert.AssertionError({
    message: `go batch ${id}: ${reason}; every case in the batch fails\n`
      + `offending case(s): ${offending}\n${detail}`
  });

// Names the cases whose packages Go's output blames.
const blamed = (output, names) => {
  const idents = new Set([...output.matchAll(
    /(?:^# waxwingbatch\/|(?:^|[\s/])(?=c\d+\/))(c\d+)/gm)].map(m => m[1]));
  const found = [...idents].filter(ident => names.has(ident))
    .map(ident => JSON.stringify(names.get(ident)));
  return found.length ? found.join(', ') : 'not identified';
};

const rewritten = entry => ({ ...entry, go: entry.transform(entry.go) });
const rewrite = entry =>
  ({ ...entry, go: asCasePackage(entry.name, entry.ident, entry.go) });

// Filesystem errors propagate as themselves; only the shape guard's refusal
// becomes a batch failure.
const write = (dir, packages) => {
  for (const entry of packages) {
    mkdirSync(join(dir, entry.ident));
    writeFileSync(join(dir, entry.ident, 'main.go'), entry.go);
  }
  writeFileSync(join(dir, 'go.mod'),
    `module ${modulePath}\n\ngo ${goVersion}\n`);
  writeFileSync(join(dir, 'main.go'),
    dispatcher(packages.map(entry => entry.ident)));
  return new Map(packages.map(entry => [entry.ident, entry.name]));
};

const build = (id, dir, entries) => {
  rmSync(dir, { recursive: true, force: true });
  mkdirSync(dir, { recursive: true });
  const transformed = entries.filter(entry => !entry.rejection).map(rewritten);
  let packages;
  // asCasePackage is pure text work; its refusal is the only throw here.
  try { packages = transformed.map(rewrite); } catch (refusal) {
    return { failure: batchFailure(id, 'generated Go was refused',
      'named below', refusal.message) };
  }
  const names = write(dir, packages);
  const result = spawnSync('go', ['build', '-o', 'program', '.'], {
    encoding: 'utf8', timeout: buildTimeoutMs, cwd: dir,
    env: { ...process.env, GOCACHE: resolve('.build/go-cache'), GOWORK: 'off' }
  });
  const failed = 'generated Go failed to compile';
  if (result.error) {
    return { failure: batchFailure(id, failed, 'not identified',
      String(result.error)) };
  }
  const output = `${result.stderr}${result.stdout}`;
  if (result.status !== 0) {
    return { failure: batchFailure(id, failed, blamed(output, names), output) };
  }
  return { binary: join(dir, 'program') };
};

// A rejection is recorded against its case alone, with runGo's error.
const compiled = entry => {
  try { return { ...entry, go: checked(entry.source) }; } catch (rejection) {
    return { ...entry, rejection };
  }
};

// Names are strings, as run() looks them up.
const describe = ([name, spec], index) => ({
  name: String(name), ident: `c${index}`, transform: go => go,
  ...(typeof spec === 'string' ? { source: spec } : spec)
});

// cases: an array of [name, source | { source, transform }] pairs; an array
// rather than an object, so a computed name collision cannot pass silently. transform (Go text → Go text) lets a self-test inject Go the
// compiler would not emit. Nothing is compiled or built until the first
// run/result call, so a file's own timed compiles keep their place.
export const runGoBatch = (file, cases, label = '') => {
  const id = batchId(file, label);
  assert.ok(!claimed.has(id), `go batch ${id} already claimed in this file`);
  assert.ok(Array.isArray(cases), `go batch ${id}: cases must be pairs`);
  const described = cases.map(describe);
  const seen = new Set();
  for (const { name } of described) {
    assert.ok(!seen.has(name),
      `go batch ${id}: duplicate case name ${JSON.stringify(name)}`);
    seen.add(name);
  }
  claimed.add(id);
  let entries;
  let outcome;
  const binaryFor = name => {
    entries ??= new Map(described.map(compiled).map(e => [e.name, e]));
    const found = entries.get(String(name));
    assert.ok(found, `go batch ${id}: no case ${name}`);
    if (found.rejection) throw found.rejection;
    outcome ??= build(id, resolve('.build/go-batches', id),
      [...entries.values()]);
    if (outcome.failure) throw outcome.failure;
    return [outcome.binary, found.ident];
  };
  return {
    // runGo's contract: stdout, asserting exit status 0.
    run: name => {
      const [binary, ident] = binaryFor(name);
      return command(binary, [ident]);
    },
    // The raw process outcome, for tests of panics and exit status.
    result: name => {
      const [binary, ident] = binaryFor(name);
      return spawnSync(binary, [ident], { encoding: 'utf8', timeout: 60000 });
    }
  };
};
