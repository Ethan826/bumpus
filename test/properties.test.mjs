import test from 'node:test';
import assert from 'node:assert/strict';
import { parse } from '../output/Format.Parse/index.js';
import { Integer, Add, If, Boolean as Bool } from '../output/Domain.Syntax/index.js';
import { Right } from '../output/Data.Either/index.js';
import { checked, rejected } from './support.mjs';
import { runGoBatch } from './go-batch.mjs';

// Fixed seed gives replayable generated trees; no discarded inputs.
const generator = seed => () => {
  seed = (Math.imul(seed, 1664525) + 1013904223) | 0;
  return seed;
};
const tree = (next, depth) => {
  const choice = next() >>> 0;
  if (!depth || choice % 3 === 0) return { tag: 'int', value: next() };
  if (choice % 3 === 1) return { tag: 'add', left: tree(next, depth - 1), right: tree(next, depth - 1) };
  return { tag: 'if', flag: next() < 0, yes: tree(next, depth - 1), no: tree(next, depth - 1) };
};
const print = node => {
  if (node.tag === 'int') return String(node.value);
  if (node.tag === 'add') return `(${print(node.left)} + ${print(node.right)})`;
  return `(if ${node.flag} then ${print(node.yes)} else ${print(node.no)})`;
};
const shape = node => {
  if (node instanceof Integer) return { tag: 'int', value: node.value1 };
  if (node instanceof Add) return { tag: 'add', left: shape(node.value1), right: shape(node.value2) };
  assert.ok(node instanceof If);
  assert.ok(node.value1 instanceof Bool);
  return { tag: 'if', flag: node.value1.value1, yes: shape(node.value2), no: shape(node.value3) };
};
const interpret = node => {
  if (node.tag === 'int') return BigInt(node.value);
  if (node.tag === 'add') return BigInt.asIntN(32, interpret(node.left) + interpret(node.right));
  return interpret(node.flag ? node.yes : node.no);
};

test('200 generated expression trees survive independent printing and parsing', () => {
  const next = generator(0x51a6);
  for (let index = 0; index < 200; index++) {
    const expected = tree(next, 4);
    const source = `fn main(): Int = ${print(expected)};`;
    const parsed = parse(source);
    assert.ok(parsed instanceof Right, source);
    assert.deepEqual(shape(parsed.value0.functions[0].body), expected);
    checked(source);
  }
});

// Drawn up front, in the order the test used to draw them, so the 12
// programs build as one Go batch (T001); a case is named by its index.
const executed = (() => {
  const next = generator(0x7c95);
  return Array.from({ length: 12 }, () => tree(next, 3));
})();
const batch = runGoBatch(import.meta.url,
  executed.map(expected => `fn main(): Int = ${print(expected)};`));

test('12 generated programs agree with an independent BigInt interpreter after Go execution', () => {
  executed.forEach((expected, index) => {
    assert.equal(batch.run(index), `${interpret(expected)}\n`);
  });
});

test('whitespace shifts error locations without changing name rejection', () => {
  const next = generator(0x113);
  for (let index = 0; index < 100; index++) {
    const lines = (next() >>> 0) % 8;
    const spaces = (next() >>> 0) % 12;
    const prefix = '\n'.repeat(lines) + ' '.repeat(spaces);
    const diagnostic = rejected(`${prefix}fn main(): Int = missing;`, 'E_UNBOUND');
    assert.deepEqual(diagnostic.span.start, { offset: prefix.length + 17, line: lines + 1, column: spaces + 18 });
  }
});
