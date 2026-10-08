// Measures, per nesting form, the smallest depth at which a cold
// `node scripts/bumpus.mjs emit` overflows the JavaScript stack (ADR 006).
// Run with the depth limit disabled: `node scripts/depth-probe.mjs [form…]`
// after temporarily setting `nestingLimit` in Format.Parse.Grammar to 10⁹
// and rebuilding; ADR 006 "Measurement" gives the exact, uncommitted steps.
// Every run is classified; only `overflow` drives the binary search, and any
// `diagnostic` or `timeout` below the overflow point is reported as an
// anomaly (a generator bug or a compiler defect), never as the limit.
import { spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { forms, functionForms } from './depth-forms.mjs';

// FN001 forms only when named: until Go emits them (FN001 Task 6) their
// runs below the overflow point end in a diagnostic, reported as anomalies.
const named = { ...forms, ...functionForms };

const timeout = 120000;
const start = 64;
const ceiling = 1 << 16;
const work = mkdtempSync(join(tmpdir(), 'bumpus-depth-'));

const classify = (result) => {
  const output = `${result.stdout}${result.stderr}`;
  if (result.error?.code === 'ETIMEDOUT') return 'timeout';
  // V8 may exhaust the stack while compiling a regular expression
  // (Data.Int.fromString) and report `SyntaxError: …: Stack overflow`.
  if (/RangeError|Maximum call stack size exceeded|: Stack overflow/
    .test(output)) return 'overflow';
  if (result.status === 0) return 'ok';
  if (/^\{"code":"E_/m.test(result.stderr)) return 'diagnostic';
  return `failed (${result.status}): ${output.slice(0, 200)}`;
};

const outcome = (form, depth) => {
  const input = join(work, 'probe.bumpus');
  writeFileSync(input, named[form](depth).source);
  const result = spawnSync('node',
    ['scripts/bumpus.mjs', 'emit', input, join(work, 'probe.go')],
    { encoding: 'utf8', timeout });
  return { depth, kind: classify(result), detail: result.stderr.trim() };
};

// Doubles until an overflow, then bisects between the last non-overflow and
// the first overflow. Returns every run so anomalies stay visible.
const measure = (form) => {
  const runs = [];
  const at = (depth) => {
    const run = outcome(form, depth);
    runs.push(run);
    return run.kind === 'overflow';
  };
  let low = 0;
  let high = start;
  while (high <= ceiling && !at(high)) {
    low = high;
    high *= 2;
  }
  if (high > ceiling) return { form, runs, overflow: null };
  while (high - low > 1) {
    const middle = Math.floor((low + high) / 2);
    if (at(middle)) high = middle; else low = middle;
  }
  return { form, runs, overflow: high };
};

const describe = (result) => {
  const below = result.runs.filter(run => result.overflow === null
    || run.depth < result.overflow);
  const anomalies = below.filter(run => run.kind !== 'ok');
  const kinds = [...new Set(result.runs.map(run => run.kind))].join(', ');
  console.log(`| ${result.form} | ${result.overflow ?? `none ≤ ${ceiling}`} `
    + `| ${result.runs.length} | ${kinds} |`);
  for (const run of anomalies) {
    console.log(`  ANOMALY ${result.form} depth ${run.depth}: ${run.kind} `
      + run.detail.slice(0, 200));
  }
  return anomalies.length;
};

const chosen = process.argv.slice(2);
const names = chosen.length > 0 ? chosen : Object.keys(forms);
console.log('| form | smallest overflowing depth | runs | outcomes |');
console.log('|---|---|---|---|');
try {
  const results = names.map(measure);
  const anomalies = results.map(describe).reduce((a, b) => a + b, 0);
  const depths = results.map(result => result.overflow ?? Infinity);
  const minimum = Math.min(...depths);
  const limit = 2 ** Math.floor(Math.log2(minimum / 2));
  console.log(`minimum overflow ${minimum}; limit rule (largest power of two`
    + ` ≤ half): ${limit}; anomalies: ${anomalies}`);
} finally { rmSync(work, { recursive: true, force: true }); }
