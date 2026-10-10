import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runs, silent, orders } from './fx-block-programs.mjs';
import { cases as consoleCases, values } from './fx-console-programs.mjs';
import { cases as cleanupCases } from './fx-cleanup-programs.mjs';
import { cases as runCases } from './fx-run-programs.mjs';
import { add, block, call, doItem, lit, print, text } from './fx-gen-ast.mjs';
import { outcome } from './fx-oracle.mjs';
import { generate, render } from './fx-programs.mjs';
import { shrink } from './fx-shrink.mjs';
import { checked } from './support.mjs';

// FX001 Task 10: the reference interpreter against the hand-derived traces
// of Tasks 2, 4, 7 and 8, then the shrinker and the sensitivity check of
// the generated corpus (test/fx-differential.serial.test.mjs).
const seen = (source, options) => {
  const { stdout, stderr, status } = outcome(source, options);
  return { stdout, stderr, status };
};

for (const [name, source, expected] of runs) {
  test(`hand trace, blocks: ${name}`, () => {
    assert.deepEqual(seen(source), { stdout: `${expected}\n`, stderr: '', status: 0 });
  });
}
for (const [name, source] of silent) {
  test(`hand trace, silent entry: ${name}`, () => {
    assert.deepEqual(seen(source), { stdout: '', stderr: '', status: 0 });
  });
}
for (const [name, source, expected] of [...consoleCases, ...values]) {
  test(`hand trace, Console: ${name}`, () => {
    assert.deepEqual(seen(source), { stdout: expected, stderr: '', status: 0 });
  });
}
for (const [name, source, expected] of runCases) {
  test(`hand trace, handlers: ${name}`, () => {
    assert.deepEqual(seen(source), { stdout: expected, stderr: '', status: 0 });
  });
}
for (const [name, prelude, body, status, stdout, stderr] of cleanupCases) {
  test(`hand trace, cleanup: ${name}`, () => {
    assert.deepEqual(seen(prelude + body), { stdout, stderr, status });
  });
}

// Cases whose Go is transformed after emission lie outside the interpreter's
// language; each is named here and must still exist where it is defined.
const excluded = [
  ['test/fx-cleanup.test.mjs', 'the missing-handler guard is a cause line'],
  ['test/fx-cleanup.test.mjs', 'an embedded newline is escaped'],
  ...orders.map(([name]) => ['test/fx-block-programs.mjs', name])
];
test('the cases excluded from the interpreter are the transformed ones', () => {
  for (const [file, name] of excluded) {
    assert.ok(readFileSync(file, 'utf8').includes(name), `${file}: ${name}`);
  }
});

test('a cleanup ending in a typed abort is an interpreter error', () => {
  const source = 'type E = E; effect Log { fn log(n: Int): Unit; }; '
    + 'fn main(): Unit with Console = handle with handler Log '
    + '{ log(n) => fail(E) } { defer log(1); print(2) } '
    + '{ fail(error: E) => print(9) };';
  const result = outcome(source);
  assert.equal(result.status, -1);
  assert.equal(result.stderr, 'oracle error: typed abort escaped cleanup\n');
});

test('a clause failing past an inner handle of its family reaches the outer', () => {
  const source = 'type E = E; effect Log { fn log(n: Int): Unit; }; '
    + 'fn main(): Unit with Console = handle with handler Log '
    + '{ log(n) => fail(E) } { handle log(1) { fail(error: E) => print(1) } } '
    + '{ fail(error: E) => print(2) };';
  assert.equal(seen(source).stdout, '2\n');
  assert.equal(seen(source, { clauseContext: 'inner' }).stdout, '1\n');
});

test('generation is a pure function of the seed and index', () => {
  assert.equal(generate(7, 3).source, generate(7, 3).source);
  assert.notEqual(generate(7, 3).source, generate(8, 3).source);
  for (const index of [0, 1, 2, 3, 4]) checked(generate(100 + index, index).source);
});

// The shrinker, on a synthetic predicate: a distinctive print stays
// reachable. Everything else must go, and every kept program compiles.
test('the shrinker removes items and keeps the program well-typed', () => {
  const found = generate(5, 5);
  const marker = doItem(block([doItem(print(add(lit(70), lit(7))))]));
  const program = { ...found.program, main: { ...found.program.main,
    body: { ...found.program.main.body, items:
      [...found.program.main.body.items, marker] } } };
  const keep = candidate => {
    const source = render(candidate);
    try { checked(source); } catch { return false; }
    return outcome(source).stdout.split('\n').includes('77');
  };
  assert.ok(keep(program), 'the synthetic predicate holds at the start');
  const smallest = shrink(program, keep);
  const source = render(smallest);
  checked(source);
  assert.ok(keep(smallest));
  assert.equal(smallest.fns.length, 0, 'functions dropped');
  assert.ok(smallest.main.body.items.length <= 1, 'items dropped');
  assert.ok(source.length < render(program).length / 2, 'much smaller');
});

// Subexpressions become literals of their type while the predicate holds;
// the only print stays, with its argument reduced to 0.
test('the shrinker replaces subexpressions by literals', () => {
  const main = { name: 'main', params: [], retText: 'Unit', rowText: 'Console',
    body: block([doItem(print(add(call('arg', [lit(5)], 'Int'), lit(2))))]) };
  const keep = candidate => {
    const source = render(candidate);
    try { checked(source); } catch { return false; }
    return text(candidate.main.body).includes('print(');
  };
  const smallest = shrink({ fns: [], main }, keep);
  assert.ok(render(smallest).endsWith('fn main(): Unit with Console = { print(0); };'),
    render(smallest));
});

// Running clauses in the context of the operation (the inner context) is a
// plausible interpreter mistake the corpus must catch: some of 50 programs
// must give a different outcome.
test('running clauses in the inner context changes some of 50 programs', () => {
  const different = Array.from({ length: 50 }, (_, index) => generate(20261010 + index, index))
    .filter(({ source }) => JSON.stringify(seen(source))
      !== JSON.stringify(seen(source, { clauseContext: 'inner' })));
  assert.ok(different.length >= 1, 'the flag was not detected');
});
