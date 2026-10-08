// Seeded program generators shared by the property tests and the
// specialization identity test. A test file cannot be imported for them:
// importing it would register its tests and build its Go batch.

// Fixed seed gives replayable generated trees; no discarded inputs.
export const generator = seed => () => {
  seed = (Math.imul(seed, 1664525) + 1013904223) | 0;
  return seed;
};
export const tree = (next, depth) => {
  const choice = next() >>> 0;
  if (!depth || choice % 3 === 0) return { tag: 'int', value: next() };
  if (choice % 3 === 1) return { tag: 'add', left: tree(next, depth - 1), right: tree(next, depth - 1) };
  return { tag: 'if', flag: next() < 0, yes: tree(next, depth - 1), no: tree(next, depth - 1) };
};
export const print = node => {
  if (node.tag === 'int') return String(node.value);
  if (node.tag === 'add') return `(${print(node.left)} + ${print(node.right)})`;
  return `(if ${node.flag} then ${print(node.yes)} else ${print(node.no)})`;
};
// The trees of test/properties.test.mjs, drawn up front in its draw order.
export const parsedTrees = (() => {
  const next = generator(0x51a6);
  return Array.from({ length: 200 }, () => tree(next, 4));
})();
// Drawn up front, in the order the test used to draw them, so the 12
// programs build as one Go batch (T001); a case is named by its index.
export const executedTrees = (() => {
  const next = generator(0x7c95);
  return Array.from({ length: 12 }, () => tree(next, 3));
})();
export const treeProgram = node => `fn main(): Int = ${print(node)};`;

// Fixed seed gives replayable programs; every draw is used, none discarded.
const choose = (next, count) => (next() >>> 0) % count;
const literals = [0, 1, -1];

const intValue = next => choose(next, 2) ? literals[choose(next, 3)] : next();
const value = (next, depth) => {
  const choice = depth ? choose(next, 3) : choose(next, 2);
  if (choice === 0) return { tag: 'A' };
  if (choice === 1) return { tag: 'B', n: intValue(next) };
  return { tag: 'C', left: value(next, depth - 1), right: value(next, depth - 1) };
};
const printValue = v => {
  if (v.tag === 'A') return 'A';
  if (v.tag === 'B') return `B(${v.n})`;
  return `C(${printValue(v.left)}, ${printValue(v.right)})`;
};

// Binders are named in generation order, so names never repeat in a pattern.
const intPattern = (next, names) => {
  const choice = choose(next, 3);
  if (choice === 0) return { tag: '_', int: true };
  if (choice === 1) return { tag: 'lit', n: literals[choose(next, 3)] };
  return { tag: 'bind', name: `n${names.count++}`, int: true };
};
const ctorPattern = (next, depth, names) => {
  const choice = choose(next, 3);
  if (choice === 0) return { tag: 'A' };
  if (choice === 1) return { tag: 'B', n: intPattern(next, names) };
  const left = tPattern(next, depth - 1, names);
  return { tag: 'C', left, right: tPattern(next, depth - 1, names) };
};
const tPattern = (next, depth, names) => {
  const choice = depth ? choose(next, 3) : choose(next, 2);
  if (choice === 0) return { tag: '_' };
  if (choice === 1) return { tag: 'bind', name: `t${names.count++}`, int: false };
  return ctorPattern(next, depth, names);
};
const printPattern = p => {
  if (p.tag === '_') return '_';
  if (p.tag === 'lit') return String(p.n);
  if (p.tag === 'bind') return p.name;
  if (p.tag === 'A') return 'A';
  if (p.tag === 'B') return `B(${printPattern(p.n)})`;
  return `C(${printPattern(p.left)}, ${printPattern(p.right)})`;
};
export const intBinders = p => {
  if (p.tag === 'bind') return p.int ? [p.name] : [];
  if (p.tag === 'B') return intBinders(p.n);
  if (p.tag === 'C') return [...intBinders(p.left), ...intBinders(p.right)];
  return [];
};

// Most inputs instantiate one arm's pattern, so arms and binders are hit.
const instantiate = (next, p) => {
  if (p.tag === '_' || p.tag === 'bind') {
    return p.int ? intValue(next) : value(next, 1);
  }
  if (p.tag === 'lit') return p.n;
  if (p.tag === 'A') return { tag: 'A' };
  if (p.tag === 'B') return { tag: 'B', n: instantiate(next, p.n) };
  const left = instantiate(next, p.left);
  return { tag: 'C', left, right: instantiate(next, p.right) };
};

const armText = arm => `${printPattern(arm.pattern)} => `
  + [String(arm.constant), ...intBinders(arm.pattern)].join(' + ');
// Nested two-arm matches never make an arm redundant.
const printArms = arms => {
  if (!arms.length) return '0';
  const [arm, ...rest] = arms;
  return `match v { ${armText(arm)}, _ => ${printArms(rest)} }`;
};
// One flat match exercises sequential lowering of three or more arms.
const printFlat = arms => `match v { ${arms.map(armText).join(', ')}, _ => 0 }`;

const draw = (next, count) => {
  const arms = Array.from({ length: count }, () => ({
    pattern: ctorPattern(next, 2, { count: 0 }), constant: next()
  }));
  const input = choose(next, 4)
    ? instantiate(next, arms[choose(next, count)].pattern)
    : value(next, 3);
  return { arms, input };
};
const source = (body, input) => 'type T = A | B(Int) | C(T, T); '
  + `fn pick(v: T): Int = ${body}; `
  + `fn main(): Int = pick(${printValue(input)});`;

// Both properties' programs are drawn up front, in the same order as when
// each test drew its own, so the whole file builds as one Go batch (T001).
const drawn = (seed, count, arms, print) => {
  const next = generator(seed);
  return Array.from({ length: count }, () => {
    const { arms: drawnArms, input } = draw(next, arms(next));
    return { arms: drawnArms, input, program: source(print(drawnArms), input) };
  });
};
// The seed was chosen so the 12 programs include Int-binder arms, 32-bit
// wraparound, and arms reached only through two or more nested matches.
export const nestedCases = drawn(0x487, 12, next => 1 + choose(next, 4), printArms);
// The seed was chosen so no generated arm is redundant (the compiler would
// reject it), some inputs reach a third arm, and some reach the `_` tail.
export const flatCases = drawn(0x6443, 8, next => 2 + choose(next, 3), printFlat);
