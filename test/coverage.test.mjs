import test from 'node:test';
import assert from 'node:assert/strict';
import { compile } from '../output/Program.Compile/index.js';
import { Left } from '../output/Data.Either/index.js';
import { codeName } from '../output/Format.Diagnostic/index.js';
import {
  choose, declarations, enumerate, expected, generator, intDomain, matches,
  parseWitness, pattern, print
} from './coverage-oracle.mjs';

const cases = 300;
const maximumArms = 4;

// Builds one match and records each arm pattern's source offset.
const build = (type, patterns) => {
  const prefix = `${declarations} fn f(v: ${type}): Int = `;
  let match = 'match v { ';
  const offsets = patterns.map(p => {
    const offset = prefix.length + match.length;
    match += `${print(p)} => 0, `;
    return offset;
  });
  match += '}';
  return { source: `${prefix}${match}; fn main(): Int = 0;`, offsets,
    start: prefix.length, end: prefix.length + match.length };
};

const outcome = source => {
  const result = compile(source);
  if (!(result instanceof Left)) return { code: null };
  return { code: codeName(result.value0.code), diagnostic: result.value0 };
};

test('coverage agrees with a brute-force first-match oracle', () => {
  const next = generator(0x5eed);
  const seen = { E_REDUNDANT: 0, E_NON_EXHAUSTIVE: 0, null: 0 };
  for (let index = 0; index < cases; index++) {
    const type = choose(next, 4) ? 'T' : 'Bool';
    const count = 1 + choose(next, maximumArms);
    const patterns = Array.from({ length: count },
      () => pattern(next, type, 1, { count: 0 }));
    const built = build(type, patterns);
    const domain = enumerate(type, intDomain(patterns));
    const want = expected(patterns, domain);
    const got = outcome(built.source);
    assert.equal(got.code, want.code, built.source);
    seen[want.code]++;
    if (want.code === 'E_REDUNDANT') {
      const offset = built.offsets[want.arm];
      const width = print(patterns[want.arm]).length;
      assert.equal(got.diagnostic.span.start.offset, offset, built.source);
      assert.equal(got.diagnostic.span.end.offset, offset + width, built.source);
    }
    if (want.code === 'E_NON_EXHAUSTIVE') {
      assert.equal(got.diagnostic.span.start.offset, built.start, built.source);
      assert.equal(got.diagnostic.span.end.offset, built.end, built.source);
      const text = got.diagnostic.message.replace(/^Missing pattern: /, '');
      const witness = parseWitness(text);
      const unmatched = domain.some(v => matches(witness, v)
        && !patterns.some(p => matches(p, v)));
      assert.ok(unmatched, `${text} is covered: ${built.source}`);
    }
  }
  for (const [code, count] of Object.entries(seen)) {
    assert.ok(count > 0, `no generated case expected ${code}`);
  }
});
