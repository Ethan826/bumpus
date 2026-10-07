// A brute-force coverage oracle over the all-inhabited type
// `type T = A | B(Bool) | C(T, Int);` and Bool. Values are enumerated one
// level deeper than any pattern head; deeper subtrees are an opaque leaf.
export const declarations = 'type T = A | B(Bool) | C(T, Int);';
export const literals = [0, 1, -1];
const maximumDepth = 2;
const opaque = { tag: 'opaque' };

export const generator = seed => () => {
  seed = (Math.imul(seed, 1664525) + 1013904223) | 0;
  return seed;
};
// An LCG mod 2^32 has short-period low bits (bit 0 alternates), so choices
// come from the high half, whose bits have long periods.
const discardedLowBits = 16;
export const choose = (next, count) =>
  (next() >>> discardedLowBits) % count;

// Heads appear only at levels 1..maximumDepth; below that, `_` or binders.
const head = (next, type, level, names) => {
  if (type === 'Int') return { tag: 'int', n: literals[choose(next, 3)] };
  if (type === 'Bool') return { tag: 'bool', b: choose(next, 2) === 0 };
  const choice = choose(next, 3);
  if (choice === 0) return { tag: 'A' };
  if (choice === 1) return { tag: 'B', fields: [pattern(next, 'Bool', level + 1, names)] };
  const left = pattern(next, 'T', level + 1, names);
  return { tag: 'C', fields: [left, pattern(next, 'Int', level + 1, names)] };
};
export const pattern = (next, type, level, names) => {
  const choice = level > maximumDepth ? choose(next, 2) : choose(next, 5);
  if (choice === 0) return { tag: '_' };
  if (choice === 1) return { tag: 'bind', name: `b${names.count++}` };
  return head(next, type, level, names);
};

export const print = p => {
  if (p.tag === '_') return '_';
  if (p.tag === 'bind') return p.name;
  if (p.tag === 'int') return String(p.n);
  if (p.tag === 'bool') return String(p.b);
  if (p.tag === 'A') return 'A';
  return `${p.tag}(${p.fields.map(print).join(', ')})`;
};

const intsIn = p => {
  if (p.tag === 'int') return [p.n];
  return (p.fields ?? []).flatMap(intsIn);
};

// The present literals plus the smallest non-negative Int not among them,
// which is also the only fresh Int a canonical witness can name.
export const intDomain = patterns => {
  const present = [...new Set(patterns.flatMap(intsIn))];
  let fresh = 0;
  while (present.includes(fresh)) fresh++;
  return [...present, fresh];
};

export const values = (type, depth, ints) => {
  if (depth === 0) return [opaque];
  if (type === 'Int') return ints.map(n => ({ tag: 'int', n }));
  if (type === 'Bool') return [true, false].map(b => ({ tag: 'bool', b }));
  const bools = values('Bool', depth - 1, ints);
  const trees = values('T', depth - 1, ints);
  const numbers = values('Int', depth - 1, ints);
  return [
    { tag: 'A', fields: [] },
    ...bools.map(b => ({ tag: 'B', fields: [b] })),
    ...trees.flatMap(t => numbers.map(n => ({ tag: 'C', fields: [t, n] })))
  ];
};
export const enumerate = (type, ints) => values(type, maximumDepth + 1, ints);

export const matches = (p, v) => {
  if (p.tag === '_' || p.tag === 'bind') return true;
  if (p.tag !== v.tag) return false;
  if (p.tag === 'int') return p.n === v.n;
  if (p.tag === 'bool') return p.b === v.b;
  return (p.fields ?? []).every((field, index) => matches(field, v.fields[index]));
};

// Witness text grammar: `_`, true, false, -?digits, Name, Name(w, ...).
export const parseWitness = text => {
  let at = 0;
  const token = () => {
    const found = /^\s*(-?\d+|[A-Za-z_]\w*|[(),])/.exec(text.slice(at));
    if (!found) throw new Error(`bad witness ${text} at ${at}`);
    at += found[0].length;
    return found[1];
  };
  const peek = () => text.slice(at).trim()[0];
  const parse = () => {
    const word = token();
    if (word === '_') return { tag: '_' };
    if (word === 'true' || word === 'false') return { tag: 'bool', b: word === 'true' };
    if (/^-?\d/.test(word)) return { tag: 'int', n: Number(word) };
    const fields = [];
    if (peek() === '(') {
      token();
      do fields.push(parse()); while (token() === ',');
    }
    return { tag: word, fields };
  };
  const result = parse();
  if (text.slice(at).trim() !== '') throw new Error(`trailing witness ${text}`);
  return result;
};

// First-match semantics decide the expected outcome of a whole match.
export const expected = (patterns, domain) => {
  const firsts = new Set(domain.map(v => patterns.findIndex(p => matches(p, v))));
  const redundant = patterns.findIndex((_, index) => !firsts.has(index));
  if (redundant !== -1) return { code: 'E_REDUNDANT', arm: redundant };
  if (firsts.has(-1)) return { code: 'E_NON_EXHAUSTIVE' };
  return { code: null };
};
