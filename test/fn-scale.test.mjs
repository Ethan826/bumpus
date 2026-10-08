import test from 'node:test';
import assert from 'node:assert/strict';
import { spawn, spawnSync } from 'node:child_process';
import { appendFileSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';

// FN001 Task 6: the scale rule (design §13) for the adopted convention.
// A 5,000-parameter function with a mixed body (Int, Bool and list
// parameters, each read twice out of order) is called directly and used
// as a staged value; through the CLI, its generated program's `go build`
// takes at most 10 s. Task 8 adds the full scale set. A random comment
// appended to the Go makes Go's build cache miss for the program's own
// package on every run (only the standard library stays cached).
const parameterCount = 5000;
const buildBoundMs = 10_000;
const buildTimeoutMs = 120_000;
const kinds = ['Int', 'Bool', 'List(Int)'];
const stride = 7919;

const kindOf = index => kinds[index % kinds.length];
const indices = Array.from({ length: parameterCount }, (_, index) => index);
// As Task 1's mixed body (scripts/stage-shared.mjs): a Bool is read
// through a helper call.
const term = index => [`p${index}`, `pick(p${index}, ${index})`,
  `head(p${index})`][index % kinds.length];
// Each parameter twice, in a strided order, summed by a balanced tree.
const order = Array.from({ length: 2 * parameterCount },
  (_, step) => (step * stride) % parameterCount);
const balanced = (low, high) => (high - low === 1 ? term(order[low])
  : `(${balanced(low, low + Math.floor((high - low) / 2))} + `
    + `${balanced(low + Math.floor((high - low) / 2), high)})`);

const argument = (index, variant) => [`${(index + variant) % 97}`,
  (index + variant) % 2 === 0 ? 'true' : 'false',
  `Cons(${(index + variant) % 89}, Nil)`][index % kinds.length];
const valueOf = (index, variant) => [(index + variant) % 97,
  (index + variant) % 2 === 0 ? index : 0,
  (index + variant) % 89][index % kinds.length];
const call = variant => indices.map(index => argument(index, variant))
  .join(', ');
const expected = [0, 1].reduce((total, variant) => total
  + 2 * indices.reduce((sum, index) => sum + valueOf(index, variant), 0), 0);

const source = 'type List(a) = Nil | Cons(a, List(a)); '
  + 'fn head(xs: List(Int)): Int = match xs { Nil => 0, Cons(x, _) => x }; '
  + 'fn pick(b: Bool, w: Int): Int = if b then w else 0; '
  + `fn f(${indices.map(index => `p${index}: ${kindOf(index)}`).join(', ')})`
  + `: Int = ${balanced(0, order.length)}; `
  + `fn apply(g: (${indices.map(kindOf).join(', ')}) -> Int): Int = `
  + `g(${call(1)}); fn main(): Int = f(${call(0)}) + apply(f);`;

// `go build` in its own process group, killed as a group on timeout (as
// test/depth.test.mjs).
const groupBuild = (go, binary) => new Promise((done, fail) => {
  const child = spawn('go', ['build', '-o', binary, go], {
    detached: true, stdio: ['ignore', 'ignore', 'pipe'],
    env: { ...process.env, GOCACHE: resolve('.build/go-cache') }
  });
  let errors = '';
  child.stderr.setEncoding('utf8');
  child.stderr.on('data', chunk => { errors += chunk; });
  const timer = setTimeout(() => {
    try { process.kill(-child.pid, 'SIGKILL'); } catch { /* group gone */ }
  }, buildTimeoutMs);
  child.on('error', fail);
  child.on('close', (status, signal) => {
    clearTimeout(timer);
    done({ status, signal, errors });
  });
});

test('a 5,000-parameter function used as a value builds within 10 s',
  async t => {
    const work = mkdtempSync(join(tmpdir(), 'bumpus-fn-scale-'));
    try {
      const input = join(work, 'input.bumpus');
      const go = join(work, 'main.go');
      writeFileSync(input, source);
      const emitted = spawnSync('node', ['scripts/bumpus.mjs', 'emit', input,
        go], { encoding: 'utf8', timeout: buildTimeoutMs });
      assert.ifError(emitted.error);
      assert.equal(emitted.status, 0, emitted.stderr);
      appendFileSync(go, `// cache nonce ${process.pid} ${Date.now()}\n`);
      const binary = join(work, 'program');
      const started = performance.now();
      const built = await groupBuild(go, binary);
      const elapsed = performance.now() - started;
      t.diagnostic(`go build ${Math.round(elapsed)} ms, bound ${buildBoundMs}`);
      assert.equal(built.signal, null, `go build killed at ${buildTimeoutMs}`);
      assert.equal(built.status, 0, built.errors);
      assert.ok(elapsed <= buildBoundMs, `go build took ${elapsed} ms`);
      const ran = spawnSync(binary, [], { encoding: 'utf8', timeout: 60000 });
      assert.ifError(ran.error);
      assert.equal(ran.stdout, `${expected}\n`);
    } finally { rmSync(work, { recursive: true, force: true }); }
  });
