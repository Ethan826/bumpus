// FX001 Task 2 programs for test/fx-block.test.mjs: Unit, blocks and
// monomorphic `let` (design §1), with their expected output. Each runs
// through the CLI pipeline and Go, and through the independent
// interpreter (test/poly-oracle.mjs).

const box = 'type Box(a) = Box(a); type Pair(a, b) = Pair(a, b); ';

// [name, source, expected output without the newline]
export const runs = [
  ['a block is its last item', 'fn main(): Int = '
    + '{ let x = 1; let y = x + 2; y + x };', '4'],
  ['a later let shadows an earlier one', 'fn main(): Int = '
    + '{ let x = 1; let x = x + 10; x };', '11'],
  ['a let shadows a parameter', 'fn f(x: Int): Int = { let x = x + 1; x }; '
    + 'fn main(): Int = f(1);', '2'],
  ['pure is an ordinary name', 'fn pure(x: Int): Int = x; '
    + 'fn main(): Int = { let pure = pure(1); pure };', '1'],
  ['a let shadows a function name', 'fn g(n: Int): Int = n; '
    + 'fn main(): Int = { let g = 3; g };', '3'],
  ['an inner block does not leak its lets', 'fn main(): Int = '
    + '{ let x = 1; let y = { let x = 5; x }; x + y };', '6'],
  ['let _ and discarded items evaluate and bind nothing', 'fn main(): Int = '
    + '{ let _ = 5; 1; true; 3 };', '3'],
  ['a lambda captures a let by value', 'fn main(): Int = '
    + '{ let k = 1; let f = fn(x) => x + k; let k = 2; f(10) + k };', '13'],
  ['a match inside a block reads its lets', `${box}fn main(): Int = `
    + '{ let b = Box(4); let k = 1; match b { Box(n) => n + k } };', '5'],
  ['a block inside a match arm reads the binder', `${box}fn main(): Int = `
    + 'match Box(4) { Box(n) => { let m = n + n; m + 1 } };', '9'],
  ['a block as an argument and an operand', 'fn add(x: Int, y: Int): Int = '
    + 'x + y; fn main(): Int = add({ let a = 2; a }, 3) + ({ 4 });', '9'],
  ['{} and () are Unit and equal', 'fn u(): Unit = {}; fn v(): Unit = (); '
    + 'fn main(): Bool = u() == v();', 'true'],
  ['a trailing ; makes the block Unit', 'fn f(): Unit = { 1; }; '
    + 'fn main(): Bool = f() == ();', 'true'],
  ['Unit parameters and lambda parameters', 'fn f(u: Unit): Int = 1; '
    + 'fn main(): Int = f(()) + (fn(_: Unit) => 2)({});', '3'],
  ['Unit prints as () inside a type', `${box}fn main(): Pair(Box(Unit), Int) `
    + '= Pair(Box(()), 7);', 'Pair(Box(()), 7)']
];

// Unit has a single value, so every comparison of two Units is decided by
// the operator alone (ADR 005 structural order), directly and inside a
// type (its compare helper).
const comparisons = [['==', 'true'], ['!=', 'false'], ['<', 'false'],
  ['<=', 'true'], ['>', 'false'], ['>=', 'true']];
for (const [operator, expected] of comparisons) {
  runs.push([`Unit ${operator} Unit`, 'fn main(): Bool = '
    + `() ${operator} ({});`, expected]);
  runs.push([`Box(Unit) ${operator} Box(Unit)`, `${box}fn main(): Bool = `
    + `Box(()) ${operator} Box({});`, expected]);
}

// main returning Unit prints nothing at all (design §1, Entry).
export const silent = [
  ['a Unit main prints nothing', 'fn main(): Unit = ();'],
  ['a Unit block main prints nothing', 'fn main(): Unit = '
    + '{ let x = 1; x + 1; };']
];

// Divergence probes as FN001's (test/fn-timing.test.mjs): each probe
// panics on entry, so the first item evaluated is the only label shown.
// [name, source, probe ids and labels, the label that must appear]
const probes = 'fn probe1(n: Int): Int = n; fn probe2(n: Int): Int = n; ';
export const orders = [
  ['a let before a discard', `${probes}fn main(): Int = `
    + '{ let a = probe1(1); probe2(2); a };', 'probe1'],
  ['a discard before a let', `${probes}fn main(): Int = `
    + '{ probe2(1); let a = probe1(2); a };', 'probe2'],
  ['the items before the value', `${probes}fn main(): Int = `
    + '{ let a = probe2(1); probe1(a) };', 'probe2']
];
export const orderProbes = [[0, 'probe1'], [1, 'probe2']];

// `depth` nested blocks around `1`, each with one let.
export const nestedBlocks = depth => 'fn main(): Int = '
  + '{ let a = 0; '.repeat(depth) + '1' + ' }'.repeat(depth) + ';';

// `count` let items, each reading the one before.
export const manyLets = count => 'fn main(): Int = { let x0 = 1; '
  + Array.from({ length: count - 1 },
    (_, index) => `let x${index + 1} = x${index} + 1; `).join('')
  + `x${count - 1} };`;
