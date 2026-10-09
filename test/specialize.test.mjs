import test from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { Right } from '../output/Data.Either/index.js';
import { parse } from '../output/Format.Parse/index.js';
import { resolve } from '../output/Features.Resolve/index.js';
import { check } from '../output/Features.Check/index.js';
import { specialize } from '../output/Features.Specialize/index.js';
import {
  executedTrees, flatCases, nestedCases, parsedTrees, treeProgram
} from './generators.mjs';

const succeeded = (result, source) => {
  assert.ok(result instanceof Right, `${source}\n${JSON.stringify(result)}`);
  return result.value0;
};

// A checked type must be a ground TData with no arguments (type or row),
// and a checked call
// or construction must record no instantiation; both are dropped, so what
// remains must equal the monomorphic IR exactly.
const emptyField = new Set(['TData:value1', 'TData:value2', 'Call:value1',
  'Construct:value1']);
const plain = (node, checked) => {
  if (Array.isArray(node)) return node.map(item => plain(item, checked));
  if (node === null || typeof node !== 'object') return node;
  const tag = node.constructor.name;
  const entries = Object.entries(node).filter(([key, field]) => {
    if (!checked || !emptyField.has(`${tag}:${key}`)) return true;
    assert.deepEqual(field, [], `${tag} carries ${key}`);
    return false;
  });
  const fields = Object.fromEntries(entries.map(([key, field]) =>
    [key, plain(field, checked)]));
  return tag === 'Object' ? fields : { tag, fields: Object.values(fields) };
};

// Type parameters and field syntax are resolution data the monomorphic IR
// does not carry: a monomorphic type has no parameters, and each field keeps
// its one source reference. Both are checked, then dropped.
const typeInfo = ({ parameters, ...info }) => {
  assert.deepEqual(parameters, [], `${info.name} has parameters`);
  return info;
};
const ctorInfo = ({ fieldSyntax, ...info }) => {
  assert.equal(fieldSyntax.length, info.fields.length, info.name);
  return info;
};
const functionInfo = ({ row, ...info }) => {
  assert.deepEqual(row.value0, [], `${info.name} has effect labels`);
  assert.equal(row.value1.constructor.name, 'Just');
  assert.equal(row.value1.value0.constructor.name,
    info.name === 'main' ? 'Hole' : 'Rigid');
  return info;
};
const withoutResolution = ({ effects, ...program }) => {
  assert.deepEqual(effects, [], 'effect declarations');
  return { ...program, functions: program.functions.map(functionInfo),
    types: program.types.map(typeInfo), ctors: program.ctors.map(ctorInfo) };
};

const identical = source => {
  const resolved = succeeded(resolve(succeeded(parse(source), source)), source);
  const program = succeeded(check(resolved), source);
  const { funTypes, ...specialized } = succeeded(specialize(program), source);
  // A monomorphic program without arrows interns none (FN001 Task 5).
  assert.deepEqual(funTypes, [], 'arrow table');
  for (const table of ['types', 'ctors', 'functions']) {
    assert.equal(specialized[table].length, program[table].length, table);
  }
  assert.deepEqual(plain(specialized, false),
    plain(withoutResolution(program), true), source);
};

// examples/lists.wxw is polymorphic (P001 Task 7), so specialization
// copies it rather than returning it; test/poly-run.test.mjs runs it. So
// is examples/functions.wxw (FN001 Task 6; test/compiler.test.mjs).
const polymorphicExamples = new Set(['functions.wxw', 'lists.wxw']);
const examples = readdirSync('examples').filter(name => name.endsWith('.wxw'))
  .filter(name => !polymorphicExamples.has(name))
  .sort().map(name => readFileSync(join('examples', name), 'utf8'));

test('specialize is the identity on monomorphic programs', () => {
  const programs = [...examples,
    ...[...parsedTrees, ...executedTrees].map(treeProgram),
    ...[...nestedCases, ...flatCases].map(({ program }) => program)];
  assert.equal(programs.length, examples.length + 232);
  programs.forEach(identical);
});
