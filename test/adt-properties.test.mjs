import test from 'node:test';
import assert from 'node:assert/strict';
import { runGoBatch } from './go-batch.mjs';
import { flatCases, intBinders, nestedCases } from './generators.mjs';

// First-match reference semantics: bindings on success, null on failure.
const matches = (p, v) => {
  if (p.tag === '_') return {};
  if (p.tag === 'bind') return { [p.name]: v };
  if (p.tag === 'lit') return p.n === v ? {} : null;
  if (p.tag !== v.tag) return null;
  if (p.tag === 'A') return {};
  if (p.tag === 'B') return matches(p.n, v.n);
  const left = matches(p.left, v.left);
  const right = left && matches(p.right, v.right);
  return right && { ...left, ...right };
};
const interpret = (arms, v) => {
  for (const arm of arms) {
    const bound = matches(arm.pattern, v);
    if (bound) {
      return intBinders(arm.pattern).reduce(
        (total, name) => BigInt.asIntN(32, total + BigInt(bound[name])),
        BigInt(arm.constant));
    }
  }
  return 0n;
};

// Each case is named by its program text.
const batch = runGoBatch(import.meta.url,
  [...nestedCases, ...flatCases].map(({ program }) => [program, program]));
const run = program => batch.run(program);

test('12 generated match programs agree with a first-match interpreter', () => {
  for (const { arms, input, program } of nestedCases) {
    assert.equal(run(program), `${interpret(arms, input)}\n`, program);
  }
});

test('8 generated flat multi-arm matches agree with the interpreter', () => {
  const reached = [];
  for (const { arms, input, program } of flatCases) {
    assert.equal(run(program), `${interpret(arms, input)}\n`, program);
    reached.push(arms.findIndex(arm => matches(arm.pattern, input)));
  }
  assert.ok(reached.some(arm => arm >= 2), `no third arm: ${reached}`);
  assert.ok(reached.includes(-1), `no wildcard tail: ${reached}`);
});
