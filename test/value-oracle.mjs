// A reference interpreter for values of generated type systems: two types
// T0 and T1 whose constructors take Int, Bool or either type. Constructor 0
// of each type has only Int and Bool fields, so bounded values always exist.
// A value is { ctor, fields } with ctor its 0-based declaration position.
import { choose, generator } from './coverage-oracle.mjs';

export { generator, choose } from './coverage-oracle.mjs';

// choose() reads an LCG's low bits through `%`, and those cycle with short
// periods (bit 0 alternates), which made consecutive choices correlated.
// Folding the high half down first keeps the shared LCG but mixes the bits.
export const mixedGenerator = seed => {
  const raw = generator(seed);
  return () => {
    const drawn = raw();
    return drawn ^ (drawn >>> 16);
  };
};

const typeCount = 2;
const intLiterals = [0, 1, -1, 2147483647, -2147483648];

const fieldType = (next, primitiveOnly) => {
  const choice = choose(next, primitiveOnly ? 2 : 2 + typeCount);
  return choice < 2 ? ['Int', 'Bool'][choice] : choice - 2;
};
const fieldText = field => typeof field === 'number' ? `T${field}` : field;
const ctorText = ctor => ctor.fields.length === 0 ? ctor.name
  : `${ctor.name}(${ctor.fields.map(fieldText).join(', ')})`;

export const typeSystem = next => {
  const types = [];
  for (let type = 0; type < typeCount; type++) {
    const ctors = [];
    const count = 1 + choose(next, 3);
    for (let index = 0; index < count; index++) {
      const fields = [];
      const width = choose(next, 3);
      for (let field = 0; field < width; field++) {
        fields.push(fieldType(next, index === 0));
      }
      ctors.push({ name: `K${type}_${index}`, fields });
    }
    types.push({ name: `T${type}`, ctors });
  }
  const declarations = types.map(type =>
    `type ${type.name} = ${type.ctors.map(ctorText).join(' | ')};`
  ).join(' ');
  return { declarations, types };
};

// Small Ints dominate so that equal fields, and later differences, occur.
const intValue = next => choose(next, 4) === 0 ? next() | 0
  : intLiterals[choose(next, intLiterals.length)];

const fieldValue = (next, system, field, depth) => {
  if (field === 'Int') return intValue(next);
  if (field === 'Bool') return choose(next, 2) === 0;
  return value(next, system, field, depth - 1);
};

export const value = (next, system, typeIndex, depth) => {
  const ctors = system.types[typeIndex].ctors;
  const ctor = depth <= 0 ? 0 : choose(next, ctors.length);
  const fields = ctors[ctor].fields.map(field =>
    fieldValue(next, system, field, depth));
  return { ctor, fields };
};

const sign = difference => difference < 0 ? -1 : difference > 0 ? 1 : 0;
const compareField = (system, a, b) => {
  if (typeof a === 'object') return compare3(system, a, b);
  return sign(Number(a) - Number(b));
};

// Spec section 3: declaration position first, then fields left to right.
export const compare3 = (system, a, b) => {
  if (a.ctor !== b.ctor) return sign(a.ctor - b.ctor);
  for (let index = 0; index < a.fields.length; index++) {
    const result = compareField(system, a.fields[index], b.fields[index]);
    if (result !== 0) return result;
  }
  return 0;
};

const typeOfCtor = (system, name) => {
  for (const type of system.types) {
    const ctor = type.ctors.findIndex(candidate => candidate.name === name);
    if (ctor !== -1) return { type, ctor };
  }
  throw new Error(`unknown constructor ${name}`);
};
// Values do not record their type; the printer follows the declared fields.
const show = (system, typeIndex, v) => {
  if (typeof v === 'number') return String(v);
  if (typeof v === 'boolean') return String(v);
  const ctor = system.types[typeIndex].ctors[v.ctor];
  if (ctor.fields.length === 0) return ctor.name;
  const fields = ctor.fields.map((field, index) =>
    show(system, field, v.fields[index]));
  return `${ctor.name}(${fields.join(', ')})`;
};
export const printValue = (system, v, typeIndex = 0) =>
  show(system, typeIndex, v);

// Each Int becomes a sum that wraps to it; every declared subterm sits in
// a parenthesized `if true then … else …` whose else branch is unused.
const intExpression = (next, n) => {
  const left = next() | 0;
  return `${left} + ${(n - left) | 0}`;
};
const express = (next, system, typeIndex, v) => {
  if (typeof v === 'number') return intExpression(next, v);
  if (typeof v === 'boolean') return String(v);
  const ctor = system.types[typeIndex].ctors[v.ctor];
  const fields = ctor.fields.map((field, index) =>
    express(next, system, field, v.fields[index]));
  const built = fields.length === 0 ? ctor.name
    : `${ctor.name}(${fields.join(', ')})`;
  const other = printValue(system, value(next, system, typeIndex, 0),
    typeIndex);
  return `(if true then ${built} else ${other})`;
};
export const expressionOf = (next, system, v, typeIndex = 0) =>
  express(next, system, typeIndex, v);

// Grammar of printed values: true, false, -?digits, Name, Name(v, ...).
export const parseValue = (system, text) => {
  let at = 0;
  const token = () => {
    const found = /^\s*(-?\d+|[A-Za-z_]\w*|[(),])/.exec(text.slice(at));
    if (!found) throw new Error(`bad value ${text} at ${at}`);
    at += found[0].length;
    return found[1];
  };
  const peek = () => text.slice(at).trim()[0];
  const parse = () => {
    const word = token();
    if (word === 'true' || word === 'false') return word === 'true';
    if (/^-?\d/.test(word)) return Number(word);
    const { ctor } = typeOfCtor(system, word);
    const fields = [];
    if (peek() === '(') {
      token();
      do fields.push(parse()); while (token() === ',');
    }
    return { ctor, fields };
  };
  const result = parse();
  if (text.slice(at).trim() !== '') throw new Error(`trailing ${text}`);
  return result;
};
