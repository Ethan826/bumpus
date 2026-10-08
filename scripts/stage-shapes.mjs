// Hand-written Go for FN001 Task 1 (design §13): a named function `f` of
// `n` Int parameters used as a staged function value, in three shapes.
// `linked` is the candidate lowering: one top-level stage function per
// argument, each returning a closure that captures one immutable
// environment node (the argument and a pointer to the previous node); the
// last stage reads the chain once and calls `f`. `copied` (an environment
// struct copied per stage) and `nested` (closures nested inside closures,
// design §7 as first approved) are reference points only.
//
// Every shape shares the named function types, `f` and the driver, so they
// differ only in the staged value. `f` consumes every argument (a
// position-weighted sum, wrapping like Go's int32), and the driver applies
// the value through all `n` stages `rounds` times with arguments that vary
// per round, timing only those rounds, and prints the elapsed nanoseconds
// and a checksum that `checksum` below recomputes independently.

const range = (from, to) =>
  Array.from({ length: Math.max(0, to - from) }, (_, index) => from + index);

// T1 takes one more argument and returns the result; Tm takes m more.
const functionTypes = n => [
  'type T1 func(int32) int32',
  ...range(2, n + 1).map(m => `type T${m} func(int32) T${m - 1}`)
];

const parameters = n => range(0, n).map(index => `p${index}`);

// A composite literal and a loop, not an n-term expression, so `f` itself
// costs linear text and no deep expression tree.
const sum = n => [
  `func f(${parameters(n).map(name => `${name} int32`).join(', ')}) int32 {`,
  `values := [${n}]int32{${parameters(n).join(', ')}}`,
  'var total int32',
  'for index, value := range values { total += int32(index+1) * value }',
  'return total',
  '}'
];

// One statement per stage, so the driver is linear text too.
const driver = (n, rounds) => [
  'func main() {',
  'start := time.Now()',
  'var checksum int32',
  `for round := int32(0); round < ${rounds}; round++ {`,
  's1 := fValue(round*31 + 0)',
  ...range(2, n + 1).map(stage =>
    `s${stage} := s${stage - 1}(round*31 + ${stage - 1})`),
  `checksum += s${n}`,
  '}',
  'fmt.Println(time.Since(start).Nanoseconds(), checksum)',
  '}'
];

// The last stage unpacks the chain from argument n-1 back to argument 1.
const unpack = n => range(1, n).reverse().flatMap(link => [
  `p${link - 1} := c${link}.value`,
  ...(link > 1 ? [`c${link - 1} := c${link}.previous`] : [])
]);

const linked = n => [
  'type fEnv1 struct { value int32 }',
  ...range(2, n).map(k =>
    `type fEnv${k} struct { value int32; previous *fEnv${k - 1} }`),
  `func fValue(x int32) T${n - 1} { return fStage2(&fEnv1{x}) }`,
  ...range(2, n).map(k => `func fStage${k}(e *fEnv${k - 1}) T${n - k + 1} `
    + `{ return func(x int32) T${n - k} `
    + `{ return fStage${k + 1}(&fEnv${k}{x, e}) } }`),
  `func fStage${n}(c${n - 1} *fEnv${n - 1}) T1 {`,
  'return func(x int32) int32 {',
  `p${n - 1} := x`,
  ...unpack(n),
  `return f(${parameters(n).join(', ')})`,
  '}',
  '}'
];

const fields = n => parameters(n - 1).map(name => `e.${name}`);

const copied = n => [
  `type fEnv struct { ${parameters(n - 1).map(name => `${name} int32`)
    .join('; ')} }`,
  `func fValue(x int32) T${n - 1} { var e fEnv; e.p0 = x; `
    + 'return fStage2(e) }',
  ...range(2, n).map(k => `func fStage${k}(e fEnv) T${n - k + 1} `
    + `{ return func(x int32) T${n - k} `
    + `{ next := e; next.p${k - 1} = x; return fStage${k + 1}(next) } }`),
  `func fStage${n}(e fEnv) T1 { return func(x int32) int32 `
    + `{ return f(${[...fields(n), 'x'].join(', ')}) } }`
];

const nested = n => {
  const inner = `return f(${parameters(n).join(', ')})`;
  const body = range(1, n).reverse().reduce((code, index) =>
    `return func(p${index} int32) ${index === n - 1 ? 'int32'
      : `T${n - 1 - index}`} { ${code} }`, inner);
  return [`func fValue(p0 int32) T${n - 1} { ${body} }`];
};

// Attribution baselines. `direct` has no staged value: its driver calls
// `f` with all `n` arguments, as today's Go does. `idle` keeps a shape's
// staged value but replaces the per-stage driver with one that only
// references it, so the two together separate the staged value's build
// cost from the driver's.
const direct = () => [];

const directDriver = (n, rounds) => [
  'func main() {',
  'start := time.Now()',
  'var checksum int32',
  `for round := int32(0); round < ${rounds}; round++ {`,
  `checksum += f(${range(0, n).map(index => `round*31 + ${index}`)
    .join(', ')})`,
  '}',
  'fmt.Println(time.Since(start).Nanoseconds(), checksum)',
  '}'
];

const idleDriver = () => [
  'func main() {',
  'start := time.Now()',
  'var held any = fValue',
  'fmt.Println(time.Since(start).Nanoseconds(), held != nil)',
  '}'
];

// Remedy candidates. `shared`: the linked chain with one environment node
// type for every stage (one per argument type in general; every argument
// here is Int) instead of one per stage. `packed`: `shared`, and the last
// stage hands the chain to `fPacked`, which reads it in a loop, instead of
// unpacking `n` locals and making an `n`-argument call (a wide-function
// calling convention).
const sharedStages = (n, last) => [
  'type node struct { value int32; previous *node }',
  `func fValue(x int32) T${n - 1} { return fStage2(&node{x, nil}) }`,
  ...range(2, n).map(k => `func fStage${k}(e *node) T${n - k + 1} `
    + `{ return func(x int32) T${n - k} `
    + `{ return fStage${k + 1}(&node{x, e}) } }`),
  ...last
];

const shared = n => sharedStages(n, [
  `func fStage${n}(c${n - 1} *node) T1 {`,
  'return func(x int32) int32 {',
  `p${n - 1} := x`,
  ...unpack(n),
  `return f(${parameters(n).join(', ')})`,
  '}',
  '}'
]);

const packed = n => sharedStages(n, [
  `func fStage${n}(e *node) T1 { return func(x int32) int32 `
    + '{ return fPacked(&node{x, e}) } }',
  'func fPacked(e *node) int32 {',
  `var total int32; for index := ${n}; e != nil; index-- `
    + '{ total += int32(index) * e.value; e = e.previous }',
  'return total',
  '}'
]);

export const shapes = { linked, copied, nested, direct, shared, packed };

// One chained expression, `fValue(a0)(a1)…`, the shape Format.Go emits
// for an application of a value to many arguments (plan Task 6).
const chainDriver = (n, rounds) => [
  'func main() {',
  'start := time.Now()',
  'var checksum int32',
  `for round := int32(0); round < ${rounds}; round++ {`,
  `checksum += fValue${range(0, n).map(index => `(round*31 + ${index})`)
    .join('')}`,
  '}',
  'fmt.Println(time.Since(start).Nanoseconds(), checksum)',
  '}'
];

// Only the shared prefix: function types, `f` and an empty driver.
const bareDriver = () => [
  'func main() {',
  'start := time.Now()',
  'fmt.Println(time.Since(start).Nanoseconds(), f != nil)',
  '}'
];

const drivers = { full: driver, direct: directDriver, idle: idleDriver,
  chain: chainDriver, bare: bareDriver };

export const program = (shape, n, rounds, mode = 'full') => [
  'package main',
  'import (\n"fmt"\n"time"\n)',
  ...functionTypes(n),
  ...sum(n),
  ...shapes[shape](n),
  ...drivers[shape === 'direct' && mode === 'full' ? 'direct' : mode](n,
    rounds)
].join('\n') + '\n';

// The driver's checksum, computed without Go: int32 wrapping throughout.
export const checksum = (n, rounds) => {
  let total = 0;
  for (let round = 0; round < rounds; round++) {
    let applied = 0;
    for (let index = 0; index < n; index++) {
      const argument = (Math.imul(round, 31) + index) | 0;
      applied = (applied + Math.imul(index + 1, argument)) | 0;
    }
    total = (total + applied) | 0;
  }
  return total;
};
