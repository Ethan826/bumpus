// Seeded polymorphic programs for the specialization properties (P001
// Task 8, design §8): List, Pair and a generated parameterized type G;
// generic functions whose bodies call earlier generic functions at
// instantiations drawn from the caller's variables (so type arguments are
// permuted and dropped) and from nested ground types; and a `main` that
// calls every function at an instantiation and at the same one with Int
// and Bool exchanged (`List(List(Int))` beside `List(List(Bool))`,
// `Pair(Int, Bool)` beside `Pair(Bool, Int)`), so wrongly sharing a key
// changes the output. Functions terminate: calls go only to earlier
// functions, and a self call passes a part of its recursion parameter,
// bound by matching on it, in that parameter's place. Every program has
// holes: a variable that appears only as `List(v)` is sometimes passed
// `Nil` and left open.
import { choose, generator } from './coverage-oracle.mjs';
import {
  data, declarationText, drawTypes, groundPool, hole, isData, substitute,
  swapLeaves, typeText, variable
} from './poly-types.mjs';
import { body, expression } from './poly-expressions.mjs';

const functionCount = 4;
const bodyDepth = 3;
const argumentDepth = 2;
const names = ['a', 'b', 'c'];

const pick = (next, items) => items[choose(next, items.length)];

// A type over the bare variables; `structured` forces a data type.
const shape = (next, types, bare, depth, structured = false) => {
  const leaves = [...bare.map(variable), 'Int', 'Bool'];
  if (!structured && (depth === 0 || choose(next, 2))) {
    return pick(next, leaves);
  }
  const inner = () => shape(next, types, bare, depth - 1);
  const declared = types.get(['List', 'Pair', 'G'][choose(next, 3)]);
  return data(declared.name, declared.parameters.map(inner));
};

const shuffle = (next, items) => {
  const result = [...items];
  for (let index = result.length - 1; index > 0; index--) {
    const other = choose(next, index + 1);
    [result[index], result[other]] = [result[other], result[index]];
  }
  return result;
};

// A variable is bare (some parameter has exactly its type) or list-only
// (it appears only as `List(v)`, so a caller may pass `Nil` and leave it a
// hole). Results mention only bare variables. Function 0 always has a
// list-only variable.
const drawSignature = (next, types, index) => {
  const count = (index === 0 ? 2 : 1) + choose(next, index === 0 ? 2 : 3);
  const variables = names.slice(0, count);
  const listOnly = count > 1 && (index === 0 || choose(next, 3) === 0)
    ? [variables[count - 1]] : [];
  const bare = variables.filter(name => !listOnly.includes(name));
  const parameters = shuffle(next, [...bare.map(variable),
    ...listOnly.map(name => data('List', [variable(name)])),
    ...Array.from({ length: 1 + choose(next, 2) },
      () => shape(next, types, bare, 1, true))]);
  const recursive = parameters.map((type, position) => ({ type, position }))
    .filter(({ type }) => isData(type) && type.data !== 'Pair');
  const recursion = recursive.length && choose(next, 4)
    ? pick(next, recursive).position : -1;
  return {
    name: `f${index}`, variables, bare, listOnly, parameters, recursion,
    result: shape(next, types, bare, 2)
  };
};

const parameterText = (type, index) => `p${index}: ${typeText(type)}`;
const functionText = (signature, body) => `fn ${signature.name}(`
  + `${signature.parameters.map(parameterText).join(', ')}): `
  + `${typeText(signature.result)} = ${body};`;

const context = (next, types, functions, self, calls) => ({
  next, types, functions, self, calls, pool: groundPool(types),
  bare: self ? self.bare : [], counter: { value: 0 },
  locals: self ? self.parameters.map((type, index) => ({
    name: `p${index}`, type, decreasing: index === self.recursion,
    smaller: false
  })) : []
});

// main's calls: for each function an instantiation, the same with Int and
// Bool exchanged, and, for two or more bare variables, one rotated. The first
// leaves each list-only variable a hole.
const instantiations = (next, signature, pool) => {
  const first = new Map(signature.variables.map(name => [name,
    signature.listOnly.includes(name) ? hole : pick(next, pool)]));
  const swapped = new Map([...first].map(([name, type]) =>
    [name, swapLeaves(type)]));
  const bare = signature.bare;
  const rotated = new Map([...first, ...bare.map((name, index) =>
    [name, first.get(bare[(index + 1) % bare.length])])]);
  return bare.length > 1 ? [first, swapped, rotated] : [first, swapped];
};

const mainText = (next, types, functions, calls) => {
  const made = [];
  for (const signature of functions) {
    for (const mapping of instantiations(next, signature, groundPool(types))) {
      const scope = context(next, types, functions, null, calls);
      const args = signature.parameters.map(type => expression(scope,
        substitute(type, mapping), argumentDepth));
      calls.push({ caller: null, callee: signature, mapping });
      made.push({ text: `${signature.name}(${args.join(', ')})`,
        type: substitute(signature.result, mapping) });
    }
  }
  const last = made.pop();
  const result = made.reduceRight((inner, call) => ({
    text: `Pair(${call.text}, ${inner.text})`,
    type: data('Pair', [call.type, inner.type])
  }), last);
  return `fn main(): ${typeText(result.type)} = ${result.text};`;
};

// One program: { source, reversed (declarations in reverse order),
// calls (each { caller, callee, mapping }) }.
export const drawProgram = next => {
  const types = drawTypes(next);
  const functions = [];
  const declarations = [...types.values()].map(declarationText);
  const calls = [];
  for (let index = 0; index < functionCount; index++) {
    const signature = drawSignature(next, types, index);
    const scope = context(next, types, functions, signature, calls);
    declarations.push(functionText(signature,
      body(scope, signature.result, bodyDepth)));
    functions.push(signature);
  }
  declarations.push(mainText(next, types, functions, calls));
  return {
    source: declarations.join(' '), calls,
    reversed: [...declarations].reverse().join(' ')
  };
};

export const programCount = 30;
export const programs = (() => {
  const next = generator(0x9e1f);
  return Array.from({ length: programCount }, () => drawProgram(next));
})();
