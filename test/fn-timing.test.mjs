import test from 'node:test';
import assert from 'node:assert/strict';
import { runGoBatch } from './go-batch.mjs';
import { run } from './poly-oracle.mjs';
import { panicOnEntry, traceCalls } from './support.mjs';

// FN001 Task 6, Step 1a: evaluation timing of function values (design §4,
// §5) on the real lowering. Each probe function panics on entry with its
// label (support.mjs panicOnEntry), so the first body a program enters is
// the only label in its output; no probe body ever runs past its panic,
// so nothing recurses. Function ids are declaration positions (all
// declarations are monomorphic).
const probes = (...pairs) => go => pairs.reduce(
  (text, [index, label]) => panicOnEntry(text, index, label), go);

const ints = count => Array(count).fill('Int').join(', ');
const numbers = (count, at, text) => Array.from({ length: count },
  (_, index) => (index === at ? text : String(index + 1))).join(', ');

const timing = 'fn add(x: Int, y: Int): Int = x + y; '
  + 'fn stuck(n: Int): Int -> Int = stuck(n); '
  + 'fn drop1(f: Int -> Int): Int = 0; '
  + 'fn use(f: Int -> Int -> Int): Int = drop1(f(1)); ';

// [name, source, probe ids and labels, the label that must appear]
const cases = [
  // Review Focus 1: f(1) saturates stuck (declared arity 1).
  ['named value', `${timing}fn main(): Int = use(stuck);`, [[1, 'stuck']],
    'stuck'],
  // A lambda's body runs when its last parameter is applied.
  ['lambda', `${timing}fn main(): Int = use(fn(x) => stuck(x));`,
    [[1, 'stuck']], 'stuck'],
  // Review Focus 2: a partial application evaluates its arguments now.
  ['partial strictness', 'fn probe(n: Int): Int = n; '
    + 'fn k3(a: Int, b: Int, c: Int): Int = a; '
    + 'fn ignore(f: Int -> Int -> Int): Int = 0; '
    + 'fn main(): Int = ignore(k3(probe(1)));', [[0, 'probe']], 'probe'],
  // Review Focus 3: the left operand of a pipe first.
  ['pipe order', 'fn probe1(n: Int): Int = n; fn probe2(n: Int): Int = n; '
    + 'fn g(a: Int, b: Int): Int = a + b; '
    + 'fn main(): Int = probe1(1) |> g(probe2(2));',
  [[0, 'probe1'], [1, 'probe2']], 'probe1'],
  // Design §13 rule 6: a 65-argument application is split into helpers
  // that evaluate each argument in place, so w's body (entered at its
  // second stage) runs before the third argument's probe.
  ['helper order', 'fn probe2(n: Int): Int = n; '
    + `fn w(a: Int, b: Int): (${ints(63)}) -> Int = w(a, b); `
    + `fn use(f: (${ints(65)}) -> Int): Int = `
    + `f(${numbers(65, 2, 'probe2(3)')}); fn main(): Int = use(w);`,
  [[0, 'probe2'], [1, 'w']], 'w']
];

// Review Focus 2, sharing: one partial application, applied twice, enters
// probe (function 0) once. main prints its value and the entry trace.
const sharing = 'fn probe(n: Int): Int = n; '
  + 'fn k3(a: Int, b: Int, c: Int): Int = a + b + c; '
  + 'fn twice(g: Int -> Int -> Int): Int = g(1, 2) + g(3, 4); '
  + 'fn main(): Int = twice(k3(probe(10)));';
const traced = go => traceCalls(go).replace(
  /^func main\(\) \{ fmt\.Println\((.*)\) \}$/m,
  (line, call) => 'var waxwingTrace []string\n\n'
    + 'func waxwingTraced() []string { return waxwingTrace }\n\n'
    + `func main() { fmt.Println(${call}, waxwingTraced()) }`);

const batch = runGoBatch(import.meta.url, [
  ...cases.map(([name, source, pairs]) =>
    [name, { source, transform: probes(...pairs) }]),
  ['sharing', { source: sharing, transform: traced }]
]);

for (const [name, , , label] of cases) {
  test(`timing probe: ${name} enters ${label} first`, () => {
    const result = batch.result(name);
    assert.ifError(result.error);
    assert.notEqual(result.status, 0, `exit status: ${result.stdout}`);
    const output = result.stdout + result.stderr;
    assert.deepEqual([...output.matchAll(/waxwing-probe: (\w+)/g)]
      .map(match => match[1]), [label], output);
  });
}

test('timing probe: a shared partial enters its argument once', () => {
  assert.equal(batch.run('sharing'), '30 [3 0 2 1 1]\n');
});

// FN001 Task 7: the independent interpreter (test/poly-oracle.mjs) enters
// the same probe first as the Go run, and traces the same entries for the
// shared partial (main, probe, twice, k3, k3 as declaration positions).
for (const [name, source, pairs, label] of cases) {
  test(`interpreter agrees: ${name} enters ${label} first`, () => {
    const result = batch.result(name);
    const entered = (result.stdout + result.stderr)
      .match(/waxwing-probe: (\w+)/)?.[1];
    assert.equal(run(source, pairs.map(([, probe]) => probe)).probe,
      entered, label);
  });
}

test('interpreter agrees: a shared partial enters its argument once', () => {
  const result = run(sharing);
  assert.equal(`${result.printed} [${result.enters.join(' ')}]\n`,
    batch.run('sharing'));
});
