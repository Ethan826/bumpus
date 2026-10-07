import test from 'node:test';
import assert from 'node:assert/strict';
import { runGo } from './support.mjs';

// Fixed seed gives replayable programs; every draw is used, none discarded.
// The seed was chosen so the 12 programs include Int-binder arms, 32-bit
// wraparound, and arms reached only through two or more nested matches.
const generator = seed => () => {
  seed = (Math.imul(seed, 1664525) + 1013904223) | 0;
  return seed;
};
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
const intBinders = p => {
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

test('12 generated match programs agree with a first-match interpreter', () => {
  const next = generator(0x487);
  for (let index = 0; index < 12; index++) {
    const { arms, input } = draw(next, 1 + choose(next, 4));
    const program = source(printArms(arms), input);
    assert.equal(runGo(program), `${interpret(arms, input)}\n`, program);
  }
});

// The seed was chosen so no generated arm is redundant (the compiler would
// reject it), some inputs reach a third arm, and some reach the `_` tail.
test('8 generated flat multi-arm matches agree with the interpreter', () => {
  const next = generator(0x6443);
  const reached = [];
  for (let index = 0; index < 8; index++) {
    const { arms, input } = draw(next, 2 + choose(next, 3));
    const program = source(printFlat(arms), input);
    assert.equal(runGo(program), `${interpret(arms, input)}\n`, program);
    reached.push(arms.findIndex(arm => matches(arm.pattern, input)));
  }
  assert.ok(reached.some(arm => arm >= 2), `no third arm: ${reached}`);
  assert.ok(reached.includes(-1), `no wildcard tail: ${reached}`);
});
