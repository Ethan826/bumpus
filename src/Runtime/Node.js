import { readFileSync, writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

// Port implementations answer through the `results` constructors, so no
// PureScript data representation is assumed here.
const attempt = (results, work) => {
  try { return work(); } catch (error) { return results.io(error.message); }
};

const external = (results, command, args, done) => {
  const result = spawnSync(command, args, { encoding: 'utf8' });
  if (result.error || result.status !== 0) {
    return results.tool(result.error?.message ?? result.stderr)(command);
  }
  return done(result.stdout);
};

// Builds `go` in a fresh temporary directory, which is always removed.
const withBuilt = (results, go, binaryIn, after) => () => {
  let work;
  try {
    work = mkdtempSync(join(tmpdir(), 'sprig-'));
    const source = join(work, 'main.go');
    const binary = binaryIn(work);
    writeFileSync(source, go);
    return external(results, 'go', ['build', '-o', binary, source], () => after(binary));
  } catch (error) {
    return results.io(error.message);
  } finally {
    if (work) rmSync(work, { recursive: true, force: true });
  }
};

export const commandArguments = () => process.argv.slice(2);
export const writeOutput = text => () => { process.stdout.write(text); };
export const writeError = text => () => { console.error(text); };
export const setExitCode = status => () => { process.exitCode = status; };
export const json = record => JSON.stringify(record);

export const readSourceWith = results => path => () =>
  attempt(results, () => results.right(readFileSync(path, 'utf8')));

export const writeTextWith = results => path => text => () =>
  attempt(results, () => { writeFileSync(path, text); return results.right(''); });

export const buildWith = results => go => output =>
  withBuilt(results, go, () => resolve(output), () => results.right(''));

export const runWith = results => go =>
  withBuilt(results, go, work => join(work, 'program'),
    binary => external(results, binary, [], results.right));
