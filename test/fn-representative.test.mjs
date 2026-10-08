import test from 'node:test';
import assert from 'node:assert/strict';
import { Right } from '../output/Data.Either/index.js';
import { TBool, TInt } from '../output/Domain.Type/index.js';
import { specializeWith } from '../output/Features.Specialize/index.js';
import { checkedPoly } from './phases.mjs';
import { programs } from './poly-programs.mjs';

// FN001 Task 5: the representative-independence property (ADR 007,
// condition 4; design §6) gains lambdas with unused parameters. Each
// generated P001 program has every body wrapped in a lambda whose unused
// parameters are holes: applied at once to `Nil` (a parameter of type
// `List(_)`), or never applied (parameters of bare hole type) and matched
// on. Here on the IR: with Int and with Bool as the representative the
// copies differ, yet their computations are the same tree. Task 6
// executes them.
const wrappers = [
  body => `(fn(unusedParameter) => ${body})(Nil)`,
  body => `match (fn(unusedParameter, _) => 0) { _ => ${body} }`,
  body => `(fn(_, unusedParameter) => ${body})(Nil, Nil)`
];

// Every function declaration's body is the text after its first ` = `
// (type texts hold no `=`) up to its `;` (expressions hold none).
const withLambdas = source => source.split('; ').map((declaration, index) => {
  if (!declaration.startsWith('fn ')) return declaration;
  const split = declaration.indexOf(' = ') + ' = '.length;
  const end = declaration.endsWith(';') ? -1 : declaration.length;
  const wrap = wrappers[index % wrappers.length];
  return declaration.slice(0, split)
    + wrap(declaration.slice(split, end)) + declaration.slice(end);
}).join('; ');

const specialized = (source, representative) => {
  const result = specializeWith(representative)(checkedPoly(source));
  if (!(result instanceof Right)) assert.fail(`${source}\n${JSON.stringify(result)}`);
  return result.value0;
};

// The node a body applies or matches on (each wrapper's first part).
const wrapped = body => {
  const node = body.value0.node;
  return ['Apply', 'Match'].includes(node.constructor.name)
    ? node.value0.value0.node.constructor.name : node.constructor.name;
};

const skipped = new Set(['ty', 'span']);
const referenced = new Set(['Call', 'FunctionRef']);
const constructed = new Set(['Construct', 'Ctor', 'CtorRef']);

// Walks two IR programs in step from their entries, ignoring types and
// spans: nodes, literals, locals and constructor names must agree, and each
// pair of functions a reference reaches is compared once. Keys merged under
// one representative and kept apart under the other pair up many to one.
const sameComputation = (left, right) => {
  const pending = [[left.entry, right.entry]];
  const seen = new Set();
  const walk = (one, other, path) => {
    if (Array.isArray(one)) {
      assert.ok(Array.isArray(other) && one.length === other.length, path);
      one.forEach((item, index) => walk(item, other[index], path));
      return;
    }
    if (one === null || typeof one !== 'object') {
      assert.equal(one, other, path);
      return;
    }
    const tag = one.constructor.name;
    assert.equal(other.constructor.name, tag, path);
    const at = `${path}/${tag}`;
    if (referenced.has(tag)) pending.push([one.value0, other.value0]);
    else if (constructed.has(tag)) {
      assert.equal(left.ctors[one.value0].name,
        right.ctors[other.value0].name, at);
    }
    for (const key of Object.keys(one)) {
      const identity = key === 'value0'
        && (referenced.has(tag) || constructed.has(tag));
      if (!skipped.has(key) && !identity) walk(one[key], other[key], at);
    }
  };
  while (pending.length) {
    const [one, other] = pending.pop();
    if (seen.has(`${one} ${other}`)) continue;
    seen.add(`${one} ${other}`);
    walk(left.functions[one].body, right.functions[other].body,
      left.functions[one].name);
  }
};

test('representative independence on the IR with unused lambda parameters',
  () => {
    programs.forEach(({ source }, index) => {
      const lambdas = withLambdas(source);
      const asInt = specialized(lambdas, TInt.value);
      const asBool = specialized(lambdas, TBool.value);
      assert.notDeepEqual(asInt, asBool, `program ${index}: holes reach`);
      asInt.functions.forEach(({ name, body }) =>
        assert.equal(wrapped(body), 'Lambda', `program ${index} ${name}`));
      sameComputation(asInt, asBool);
    });
  });
