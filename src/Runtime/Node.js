import { readFileSync, writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const external = (command, args) => {
  const result = spawnSync(command, args, { encoding: 'utf8' });
  if (result.error || result.status !== 0) {
    return { ok: false, code: 'E_TOOL', message: result.error?.message ?? result.stderr, command };
  }
  return { ok: true, stdout: result.stdout };
};

export const launch = compile => () => {
  const [mode, input, destination, ...extra] = process.argv.slice(2);
  if (!['emit', 'build', 'run'].includes(mode) || !input || extra.length ||
      (mode !== 'run' && !destination) || (mode === 'run' && destination)) {
    console.error(JSON.stringify({ code: 'E_USAGE', message: 'sprig emit|build INPUT OUTPUT; sprig run INPUT' }));
    process.exitCode = 2;
    return;
  }
  let work;
  try {
    const result = compile(readFileSync(input, 'utf8'));
    if (!result.ok) {
      console.error(JSON.stringify({ ...result.diagnostics[0], file: input }));
      process.exitCode = 1;
      return;
    }
    if (mode === 'emit') {
      writeFileSync(destination, result.go);
      return;
    }
    work = mkdtempSync(join(tmpdir(), 'sprig-'));
    const go = join(work, 'main.go');
    const binary = mode === 'build' ? resolve(destination) : join(work, 'program');
    writeFileSync(go, result.go);
    const built = external('go', ['build', '-o', binary, go]);
    if (!built.ok) {
      console.error(JSON.stringify(built));
      process.exitCode = 1;
      return;
    }
    if (mode === 'run') {
      const ran = external(binary, []);
      if (ran.ok) process.stdout.write(ran.stdout);
      else { console.error(JSON.stringify(ran)); process.exitCode = 1; }
    }
  } catch (error) {
    console.error(JSON.stringify({ code: 'E_IO', message: error.message }));
    process.exitCode = 1;
  } finally {
    if (work) rmSync(work, { recursive: true, force: true });
  }
};
