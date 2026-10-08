// P001 regression probes, imported by test/regression.mjs. Each probe gets
// the compiler under test and helpers built from it, never the healthy
// build, so a restored defect cannot be masked by the fixed compiler.
const listPair = 'type List(a) = Nil | Cons(a, List(a)); '
  + 'type Pair(a, b) = Pair(a, b); ';

// Duplicates the occurs row of test/poly-check.test.mjs: `same(h, t)` asks
// h's type `_` to equal t's type `List(_)`.
const occursProgram = `${listPair}fn same(x: a, y: a): Int = 0; `
  + 'fn main(): Int = match Nil { Cons(h, t) => same(h, t), Nil => 0 };';

// Distinct generic arguments that agree on their outermost constructor:
// List(List(Int)) and List(List(Bool)) must stay two Go types.
const nestedKeys = `${listPair}fn length(xs: List(a)): Int = match xs `
  + '{ Nil => 0, Cons(_, rest) => 1 + length(rest) }; '
  + 'fn main(): Pair(Int, Int) = Pair(length(Cons(Cons(1, Nil), Nil)), '
  + 'length(Cons(Cons(true, Nil), Cons(Nil, Nil))));';

const pairOfIds = `${listPair}fn id(x: a): a = x; `
  + 'fn pair(x: a, y: b): Pair(a, b) = Pair(x, y); '
  + 'fn main(): Pair(Int, Bool) = pair(id(1), id(true));';

const fail = message => {
  console.error(message);
  process.exit(1);
};

// The wire form of a rejection, or null when the program was accepted.
const rejection = (context, source) => {
  const result = context.compile(source);
  return result instanceof context.Left
    ? context.wire(result.value0) : null;
};

const rejects = (source, code, message, failure) => context => {
  const found = rejection(context, source);
  if (found === null || found.code !== code || found.message !== message) {
    fail(`${failure}: ${JSON.stringify(found)}`);
  }
  console.log(`${context.probe} regression detects the defect`);
};

// The mutants reject the program or fail to build its Go; either way the
// expected output is missing, and the reason is printed with the message.
const runs = (source, expected, failure) => context => {
  let output;
  try { output = context.printed(source); } catch (error) {
    output = error.message;
  }
  if (output !== expected) fail(`${failure}: ${output}`);
  console.log(`${context.probe} regression detects the defect`);
};

export const polyProbes = {
  occurs: rejects(occursProgram, 'E_TYPE',
    'Infinite type: _ occurs in List(_)', 'occurs check missing'),
  rigid: rejects(`fn f(x: a): Int = x; fn main(): Int = 0;`, 'E_TYPE',
    'Expected Int, found a', 'rigid variable unified with Int'),
  instantiate: runs(pairOfIds, 'Pair(1, true)\n',
    'scheme metas shared across uses'),
  'spec-key': runs(nestedKeys, 'Pair(1, 2)\n',
    'nested specialization keys collided')
};
