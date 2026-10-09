// Builds one generated Go program and times `go build` alone (FN001 scale
// rule). The build runs in its own process group, killed as a group on
// timeout (as test/depth.test.mjs). A random comment appended to the Go
// makes Go's build cache miss for the program's own package on every run
// (only the standard library stays cached).
import { spawn, spawnSync } from 'node:child_process';
import { appendFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';

const groupBuild = (go, binary, timeoutMs) => new Promise((done, fail) => {
  const child = spawn('go', ['build', '-o', binary, go], {
    detached: true, stdio: ['ignore', 'ignore', 'pipe'],
    env: { ...process.env, GOCACHE: resolve('.build/go-cache') }
  });
  let errors = '';
  child.stderr.setEncoding('utf8');
  child.stderr.on('data', chunk => { errors += chunk; });
  const timer = setTimeout(() => {
    try { process.kill(-child.pid, 'SIGKILL'); } catch { /* group gone */ }
  }, timeoutMs);
  child.on('error', fail);
  child.on('close', (status, signal) => {
    clearTimeout(timer);
    done({ status, signal, errors });
  });
});

// `write(dir)` puts the program's Go in dir and returns its path. Returns
// { buildMs, killed, status, errors, stdout } with stdout from running it.
export const timedBuild = async (write, timeoutMs) => {
  const work = mkdtempSync(join(tmpdir(), 'bumpus-fn-scale-'));
  try {
    const go = write(work);
    appendFileSync(go, `// cache nonce ${process.pid} ${Date.now()}\n`);
    const binary = join(work, 'program');
    const started = performance.now();
    const built = await groupBuild(go, binary, timeoutMs);
    const buildMs = performance.now() - started;
    const result = { buildMs, killed: built.signal !== null,
      status: built.status, errors: built.errors, stdout: '' };
    if (built.status !== 0) return result;
    const ran = spawnSync(binary, [], { encoding: 'utf8', timeout: 60000 });
    return { ...result, stdout: ran.error ? String(ran.error) : ran.stdout };
  } finally { rmSync(work, { recursive: true, force: true }); }
};
