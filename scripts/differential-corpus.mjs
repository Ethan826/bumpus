// Source generators for scripts/differential.mjs. Every generator draws
// from one seeded linear congruential stream, so a seed names a corpus.
// Adapted from the T003 review's harness (2026-10-08).

export const random = seed => {
  let state = seed | 0;
  const next = () => {
    state = (Math.imul(state, 1664525) + 1013904223) | 0;
    return ((state >>> 8) & 0xffffff) / 0x1000000;
  };
  const below = count => Math.floor(next() * count);
  const pick = items => items[below(items.length)];
  return { next, below, pick };
};

// Lexer edge material: every punctuation and two-character token, their
// split forms, keywords and near-keywords, integer bounds, and characters
// the lexer must reject.
const atoms = ['(', ')', ':', ',', '=', ';', '+', '-', '|', '{', '}', '<',
  '>', '=>', '==', '!=', '<=', '>=', '->', '|>', '!', 'fn', 'if', 'then',
  'else', 'true', 'false', 'Int', 'Bool', 'type', 'match', '_', 'x', 'x1',
  'fnx', 'If', 'Match', 'A', 'Cons', 'Nil', 'a_b', '_x', 'x_', '__', '0',
  '7', '123', '-5', '- 5', '2147483647', '2147483648', '-2147483648',
  '-2147483649', '007', '1x', 'é', '😀', '\0', '#', '"', '.', '/', '*',
  '\\', '[', ']', '~', '@', '$', '%', '&', '^', '`', "'", '?', '\v', '\f'];
const spaces = ['', '', ' ', '  ', '\n', '\r', '\r\n', '\t', ' \t\n '];
const soupLength = 25;

export const soups = (stream, count) => Array.from({ length: count }, () => {
  let source = stream.pick(spaces);
  const length = 1 + stream.below(soupLength);
  for (let index = 0; index < length; index++) {
    source += stream.pick(atoms) + stream.pick(spaces);
  }
  return source;
});

// Strings for `isName`, which the parser asks of most tokens.
export const nameProbes = (stream, count) => [...atoms, '', 'a', 'Z9',
  'a-b', 'aé', 'x y', '9a', '_a', ...Array.from({ length: count }, () =>
    Array.from({ length: stream.below(5) }, () =>
      stream.pick(['a', 'Z', '0', '_', '-', 'é', ' ', 'f', 'n'])).join(''))];

// Fixed cases: whitespace kinds and very long runs, split operators,
// integer bounds, names beside keywords, and a long addition chain.
const main = 'fn main(): Int = 42;';
const huge = 1_000_000;
export const targeted = () => ['', ' ', '\r\n', main,
  main.replace(/ /g, '\t'), main.replace(/ /g, '\r\n'),
  'fn main(): Int = - 1;', 'fn main(): Int = 1--1;',
  'fn main(): Bool = 1=>1;', 'fn main(): Bool = 1 ! = 1;',
  'fn main(): Int = 1 | > 2;', '=>=', '!==', '->-', '|>|', '<=>', '!!',
  'fn main(): Int = é;', 'fn main(): Int = 1;😀', '\uD800',
  'fn main(): Int = 2147483648;', 'fn main(): Int = -2147483648;',
  'fn main(): Int = 0007;', 'fn If(): Int = 1;', 'fn match(): Int = 1;',
  'fn a_(): Int = 1; fn main(): Int = a_();', main + ' '.repeat(huge),
  '\t'.repeat(huge / 2) + main + '#',
  `fn main(): Int = ${'1 + '.repeat(huge / 10)}1;`];

// Programs with nested matches over Int, Bool, a list and a pair type,
// binders at several depths, and arms that may be redundant or missing:
// Capture's free sets, coverage and checking all see them.
const declarations = 'type L = Nil | Cons(Int, L); type P = P(Int, L); '
  + 'type M(a) = No | So(a);';
const binderNames = ['a', 'b', 'c', 'd', 'h', 't'];
const depth = 4;

export const matchPrograms = (stream, count) =>
  Array.from({ length: count }, () => program(stream));

const program = stream => {
  const { below, pick, next } = stream;
  let fresh = 0;
  const bind = (type, extra) => {
    const name = pick(binderNames) + (next() < 0.7 ? fresh++ : '');
    extra.push({ name, type });
    return name;
  };
  const operand = (scope, left) => expression(scope, left - 1);
  const expression = (scope, left) => {
    const choice = left <= 0 ? below(3) : below(8);
    const ints = scope.filter(local => local.type === 'Int');
    if (choice === 0) return String(pick([0, 1, -1, 5, -7, 42]));
    if (choice === 1 && ints.length > 0) return pick(ints).name;
    if (choice <= 2) return pick(['n', '3']);
    if (choice === 3) {
      return `(${operand(scope, left)} + ${operand(scope, left)})`;
    }
    if (choice === 4) {
      return `(if ${operand(scope, left)} `
        + `${pick(['<', '==', '!=', '>=', '<=', '>'])} `
        + `${operand(scope, left)} then ${operand(scope, left)} `
        + `else ${operand(scope, left)})`;
    }
    if (choice === 5) return `g(${operand(scope, left)})`;
    return match(scope, left - 1);
  };
  const listPattern = (extra, left) => {
    const choice = below(left > 0 ? 4 : 3);
    if (choice === 0) return '_';
    if (choice === 1) return 'Nil';
    if (choice === 2) {
      return `Cons(${next() < 0.5 ? '_' : bind('Int', extra)}, `
        + `${next() < 0.5 ? '_' : bind('L', extra)})`;
    }
    return `Cons(${pick(['0', '1', '_', '-1'])}, `
      + `${listPattern(extra, left - 1)})`;
  };
  const subject = (scope, left) => {
    const lists = scope.filter(local => local.type === 'L');
    const kind = below(4);
    if (kind === 0 && lists.length > 0) {
      return [pick(lists).name, extra => listPattern(extra, 2)];
    }
    if (kind <= 1) {
      return [operand(scope, left), extra => next() < 0.2
        ? bind('Int', extra) : pick(['0', '1', '-1', '_', '5'])];
    }
    if (kind === 2) {
      return [`(${operand(scope, left)} < 3)`,
        () => pick(['true', 'false', '_'])];
    }
    return [`P(${operand(scope, left)}, xs)`, extra =>
      `P(${next() < 0.4 ? bind('Int', extra) : pick(['_', '0'])}, `
        + `${listPattern(extra, 1)})`];
  };
  const match = (scope, left) => {
    const [scrutinee, pattern] = subject(scope, left);
    const arms = [];
    const seen = new Set();
    let closed = false;
    for (let index = below(4); index >= 0 && !closed; index--) {
      const extra = [];
      const written = pattern(extra);
      const shape = written.replace(/[a-z]\d*/g, 'v');
      if (seen.has(shape) && next() < 0.9) continue;
      seen.add(shape);
      if (shape === '_' || shape === 'v') closed = next() < 0.9;
      arms.push(`${written} => ${operand([...scope, ...extra], left)}`);
    }
    if (!closed && next() < 0.75) arms.push(`_ => ${operand(scope, left)}`);
    return `(match ${scrutinee} { ${arms.join(', ')} })`;
  };
  const scope = [{ name: 'n', type: 'Int' }, { name: 'xs', type: 'L' }];
  return `${declarations} fn g(k: Int): Int = k + 1; `
    + `fn f(n: Int, xs: L): Int = ${match(scope, depth)}; `
    + `fn main(): Int = f(${pick([0, 1, 3])}, Cons(1, Cons(0, Nil)));`;
};

// One to three single-character insertions, deletions or replacements.
const mutationAlphabet = ['=', '>', '!', '-', '|', '<', ' ', '\n', '\t',
  '\r', 'é', '(', ')', '{', '}', ',', ';', '_', 'x', '0', '9', ':', 'fn ',
  'match ', '#'];

export const mutations = (stream, sources, count) => {
  const { below, pick } = stream;
  const mutate = source => {
    let text = source;
    for (let edit = below(3); edit >= 0; edit--) {
      const at = below(text.length + 1);
      const kind = below(3);
      const kept = kind === 1 ? at + 1 + below(3) : kind === 2 ? at + 1 : at;
      text = text.slice(0, at) + (kind === 1 ? '' : pick(mutationAlphabet))
        + text.slice(kept);
    }
    return text;
  };
  return sources.length === 0 ? []
    : Array.from({ length: count }, () => mutate(pick(sources)));
};
