// Realistic bodies for the packed calling convention (FN001 Task 1, round
// 2). Parameters cycle through three Go types (Int, Bool, a pointer to a
// declared value), and the body reads every parameter twice in a scattered
// order (access t reads parameter t × stride mod n), as an ordinary Bumpus
// body would. Three conventions share that body:
// - `directMixed`: today's n-ary function, called directly;
// - `packedArray`: the chain node has one field per Go type; the entry
//   walks the chain once, in a loop driven by per-position tables, into
//   one array per type; the body reads `ints[j]`, `bools[j]`, `cells[j]`;
// - `packedStruct`: the entry copies the chain into a struct with one
//   field per parameter, one statement per parameter; the body reads
//   `a.pK`.
import { blockDriver, blockSize, range } from './stage-blocks.mjs';

const stride = 7919;
const kinds = ['int32', 'bool', '*cell'];
const fields = ['i', 'b', 'c'];
const kindOf = k => k % 3;
const slotOf = k => Math.floor(k / 3);

const header = ['package main', 'import (\n"fmt"\n"time"\n)',
  'type cell struct { v int32 }',
  'func pick(b bool, w int32) int32 { if b { return w }; return 0 }'];

const argument = p => [`round*31 + ${p}`, `(round+${p})%2 == 0`,
  `&cell{round + ${p}}`][kindOf(p)];

const functionTypes = n => [
  `type T1 func(${kinds[kindOf(n - 1)]}) int32`,
  ...range(2, n + 1).map(m =>
    `type T${m} func(${kinds[kindOf(n - m)]}) T${m - 1}`)
];

const contribution = (k, read) => [read, `pick(${read}, ${k + 1})`,
  `${read}.v`][kindOf(k)];

const body = (n, read) => [
  'var total int32',
  ...range(0, 2 * n).map(t => {
    const k = (t * stride) % n;
    return `total += int32(${t + 1}) * ${contribution(k, read(k))}`;
  }),
  'return total'
];

const counts = n => [0, 1, 2].map(kind =>
  range(0, n).filter(k => kindOf(k) === kind).length);

const node = 'type node struct { i int32; b bool; c *cell; previous *node }';

const stages = (n, last) => [
  node,
  `func fValue(x ${kinds[0]}) T${n - 1} `
    + `{ return fStage2(&node{${fields[0]}: x}) }`,
  ...range(2, n).map(k => `func fStage${k}(e *node) T${n - k + 1} `
    + `{ return func(x ${kinds[kindOf(k - 1)]}) T${n - k} `
    + `{ return fStage${k + 1}(&node{${fields[kindOf(k - 1)]}: x, `
    + 'previous: e}) } }'),
  `func fStage${n}(e *node) T1 { return func(x ${kinds[kindOf(n - 1)]}) `
    + `int32 { return fEntry(&node{${fields[kindOf(n - 1)]}: x, `
    + 'previous: e}) } }',
  ...last
];

const packedArray = n => stages(n, [
  `var kindTable = [${n}]uint8{${range(0, n).map(kindOf).join(', ')}}`,
  `var slotTable = [${n}]int32{${range(0, n).map(slotOf).join(', ')}}`,
  'func fEntry(e *node) int32 {',
  ...counts(n).map((count, kind) =>
    `var ${['ints', 'bools', 'cells'][kind]} [${count}]${kinds[kind]}`),
  `for p := ${n - 1}; p >= 0; p-- {`,
  'switch kindTable[p] { case 0: ints[slotTable[p]] = e.i; '
    + 'case 1: bools[slotTable[p]] = e.b; default: cells[slotTable[p]] = e.c }',
  'e = e.previous',
  '}',
  ...body(n, k => `${['ints', 'bools', 'cells'][kindOf(k)]}[${slotOf(k)}]`),
  '}'
]);

const packedStruct = n => stages(n, [
  `type fArgs struct { ${range(0, n).map(k => `p${k} ${kinds[kindOf(k)]}`)
    .join('; ')} }`,
  'func fEntry(e *node) int32 {',
  'var a fArgs',
  ...range(0, n).reverse().flatMap(k =>
    [`a.p${k} = e.${fields[kindOf(k)]}`, 'e = e.previous']),
  'return fBody(&a)',
  '}',
  'func fBody(a *fArgs) int32 {',
  ...body(n, k => `a.p${k}`),
  '}'
]);

const directMixed = (n, rounds) => [
  `func f(${range(0, n).map(k => `p${k} ${kinds[kindOf(k)]}`)
    .join(', ')}) int32 {`,
  ...body(n, k => `p${k}`),
  '}',
  'func main() {',
  'start := time.Now()',
  'var checksum int32',
  `for round := int32(0); round < ${rounds}; round++ {`,
  `checksum += f(${range(0, n).map(argument).join(', ')})`,
  '}',
  'fmt.Println(time.Since(start).Nanoseconds(), checksum)',
  '}'
];

const idleMain = ['func main() {', 'start := time.Now()',
  'var held any = fValue',
  'fmt.Println(time.Since(start).Nanoseconds(), held != nil)', '}'];

export const mixedShapes = ['directMixed', 'packedArray', 'packedStruct'];

// The checksum computed without Go, int32 wrapping throughout.
const expected = (n, rounds) => {
  let total = 0;
  for (let round = 0; round < rounds; round++) {
    let applied = 0;
    for (let t = 0; t < 2 * n; t++) {
      const k = (t * stride) % n;
      const value = [(Math.imul(round, 31) + k) | 0,
        (round + k) % 2 === 0 ? k + 1 : 0, (round + k) | 0][kindOf(k)];
      applied = (applied + Math.imul(t + 1, value)) | 0;
    }
    total = (total + applied) | 0;
  }
  return total;
};

const staged = { packedArray, packedStruct };

// Modes: `full` for directMixed; `idle` (build only) or `bNN` (applied in
// blocks of NN) for the packed conventions.
export const mixed = (shape, n, rounds, mode) => {
  const block = blockSize(mode);
  const parts = shape === 'directMixed' ? directMixed(n, rounds)
    : [...functionTypes(n), ...staged[shape](n), ...(block
      ? blockDriver({ n, rounds, block,
        typeAt: p => p < n ? `T${n - p}` : 'int32', argAt: argument })
      : idleMain)];
  const timed = shape === 'directMixed' || block !== null;
  return { go: [...header, ...parts].join('\n') + '\n',
    expected: timed ? expected(n, rounds) : null };
};
