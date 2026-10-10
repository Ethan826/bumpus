import test from 'node:test';
import assert from 'node:assert/strict';
import { census, shortfalls, table } from './fx-census.mjs';
import { goOutcome, same, saveEvidence } from './fx-diff-support.mjs';
import { rejection } from './fx-gen-reject.mjs';
import { runGoBatch } from './go-batch.mjs';
import { outcome } from './fx-oracle.mjs';
import { generate, render } from './fx-programs.mjs';
import { shrink } from './fx-shrink.mjs';
import { checked, rejectedAt } from './support.mjs';

// FX001 Task 10: generated programs run in Go against the reference
// interpreter (test/fx-oracle.mjs), comparing stdout, stderr and exit
// status exactly (design §2-§5). Serial (ruling F11): 500 programs build in
// five Go batches. WAXWING_FX_SEED and WAXWING_FX_PROGRAMS choose another
// run (docs/engineering.md); a program is reproduced by
// generate(seed + index, index). Fewer programs than the default cannot
// meet the census minimums and fail by design.
const integer = (name, fallback) => {
  const value = Number(process.env[name] ?? fallback);
  assert.ok(Number.isInteger(value) && value >= 0, `${name} must be an integer`);
  return value;
};
const baseSeed = integer('WAXWING_FX_SEED', 20261010);
const total = integer('WAXWING_FX_PROGRAMS', 500);
const chunkSize = 100;
const rejectionVariants = 25;

const programs = Array.from({ length: total }, (_, index) =>
  generate(baseSeed + index, index));
const label = ({ seed }, index) => `seed ${seed} index ${index}`;
const expectations = programs.map(({ source }) => outcome(source));

test('the corpus meets the census minimums', t => {
  const rows = census(expectations);
  const failing = expectations.filter(({ status }) => status !== 0).length;
  t.diagnostic(`seeds ${baseSeed}..${baseSeed + total - 1}, ${total} programs, `
    + `${failing} ending in a defect report`);
  for (const row of table(rows).split('\n')) t.diagnostic(row);
  saveEvidence('last-run', { '.json': JSON.stringify(programs.map(
    ({ seed, focus }, index) => ({ index, seed, focus })), null, 1) });
  assert.deepEqual(shortfalls(rows), [], table(rows));
});

test(`${rejectionVariants} failing defers are rejected with the Task 8 texts`, () => {
  for (let index = 0; index < rejectionVariants; index++) {
    const variant = rejection(baseSeed + index, index);
    const diagnostic = rejectedAt(variant.source, 'E_EFFECT', variant.text);
    assert.equal(diagnostic.message, variant.message,
      `seed ${baseSeed + index} index ${index}`);
  }
});

// A differing program: evidence on disk, a minimized source beside it, and
// a failure naming the seed. Shrinking runs Go for every well-typed
// candidate, so only the first few differences of a run are shrunk.
const shrinkLimit = 3;
let shrunk = 0;
const report = (found, index, expected, actual) => {
  const name = `seed-${found.seed}-index-${index}`;
  const differs = candidate => {
    const source = render(candidate);
    try { checked(source); } catch { return false; }
    return !same(outcome(source), goOutcome(source));
  };
  const files = { '.wxw': found.source,
    '.json': JSON.stringify({ expected, actual }, null, 2) };
  if (shrunk++ < shrinkLimit) {
    files['-min.wxw'] = render(shrink(found.program, differs));
  }
  saveEvidence(name, files);
  return `${label(found, index)} differs; see .build/fx001-differential/${name}`;
};

const chunks = Array.from({ length: Math.ceil(total / chunkSize) },
  (_, chunk) => chunk);
for (const chunk of chunks) {
  const start = chunk * chunkSize;
  const slice = programs.slice(start, start + chunkSize);
  test(`programs ${start}-${start + slice.length - 1} agree with the interpreter`, () => {
    const batch = runGoBatch(import.meta.url, slice.map(({ source }, at) =>
      [`p${start + at}`, source]), `chunk${chunk}`);
    const differences = [];
    slice.forEach((found, at) => {
      const index = start + at;
      let actual;
      try { actual = batch.result(`p${index}`); } catch (error) {
        if (String(error.message).startsWith('go batch')) {
          assert.fail(`chunk ${chunk}: ${error.message}`);
        }
        assert.fail(`${label(found, index)}: the generator produced a `
          + `program the compiler rejects: ${error.message}\n${found.source}`);
      }
      const seen = { stdout: actual.stdout, stderr: actual.stderr, status: actual.status };
      if (!same(expectations[index], seen)) {
        const { events, ...expected } = expectations[index];
        differences.push(report(found, index, expected, seen));
      }
    });
    assert.deepEqual(differences, []);
  });
}
