// The shared-body case (FN001 Task 1, round 3). One n-ary function `F`,
// with an ordinary body reading every parameter twice out of order, is
// both called directly (today's Go call, unchanged) and used as a staged
// value. The value's entry fills one array per parameter type from the
// chain and makes one n-argument call to `F`, so the body exists once.
//
// Type diversity: parameter k has kind k mod t (Int, Bool, then pointers
// to t - 2 distinct declared types). Each stage allocates a node of its
// own argument's type, `{ value; previous any }`, so a node's size does
// not grow with t; the entry dispatches on a per-position kind table.
// Each round calls `F` directly, builds one partial application over the
// first half (blocks of 64), and completes it twice with different second
// halves. The program prints elapsed nanoseconds, the checksum and the
// bytes allocated per stage application.
import { range, segment, threaded } from './stage-blocks.mjs';

const stride = 7919;
const block = 64;

const goKind = kind => kind === 0 ? 'int32' : kind === 1 ? 'bool'
  : `*c${kind - 2}`;

// Argument p of a completion variant (0: direct call and shared prefix).
const argument = (t, p, variant) => {
  const kind = p % t;
  return kind === 0 ? `round*31 + ${p + 7 * variant}`
    : kind === 1 ? `(round+${p + variant})%2 == 0`
      : `&c${kind - 2}{round + ${p + variant}}`;
};

const contribution = (t, k, read) => {
  const kind = k % t;
  return kind === 0 ? read : kind === 1 ? `pick(${read}, ${k + 1})`
    : `${read}.v`;
};

const body = (t, n) => range(0, 2 * n).map(step => {
  const k = (step * stride) % n;
  return `total += int32(${step + 1}) * ${contribution(t, k, `p${k}`)}`;
});

const entry = (t, n) => {
  const used = range(0, t).filter(kind => kind < n);
  const count = kind => range(0, n).filter(p => p % t === kind).length;
  return [
    `var kindTable = [${n}]uint16{${range(0, n).map(p => p % t)
      .join(', ')}}`,
    `var slotTable = [${n}]int32{${range(0, n).map(p => Math.floor(p / t))
      .join(', ')}}`,
    'func fEntry(e any) int32 {',
    ...used.map(kind => `var a${kind} [${count(kind)}]${goKind(kind)}`),
    `for p := ${n - 1}; p >= 0; p-- {`,
    'switch kindTable[p] {',
    ...used.map(kind => `case ${kind}: v := e.(*n${kind}); `
      + `a${kind}[slotTable[p]] = v.value; e = v.previous`),
    '}',
    '}',
    `return F(${range(0, n).map(p => `a${p % t}[${Math.floor(p / t)}]`)
      .join(', ')})`,
    '}'
  ];
};

const stages = (t, n) => [
  ...range(0, t).map(kind =>
    `type n${kind} struct { value ${goKind(kind)}; previous any }`),
  `func fValue(x ${goKind(0)}) T${n - 1} { return fStage2(&n0{x, nil}) }`,
  ...range(2, n).map(k => `func fStage${k}(e any) T${n - k + 1} `
    + `{ return func(x ${goKind((k - 1) % t)}) T${n - k} `
    + `{ return fStage${k + 1}(&n${(k - 1) % t}{x, e}) } }`),
  `func fStage${n}(e any) T1 { return func(x ${goKind((n - 1) % t)}) int32 `
    + `{ return fEntry(&n${(n - 1) % t}{x, e}) } }`
];

const driver = (t, n, rounds) => {
  const half = Math.floor(n / 2);
  const typeAt = p => p < n ? `T${n - p}` : 'int32';
  const part = (prefix, from, to, variant) => segment({ prefix, from, to,
    block, typeAt, argAt: p => argument(t, p, variant) });
  const parts = [part('pre', 0, half, 0), part('ra', half, n, 1),
    part('rb', half, n, 2)];
  const shared = threaded(parts[0].names, `T${n}(fValue)`, 'p');
  const restA = threaded(parts[1].names, shared.output, 'x');
  const restB = threaded(parts[2].names, shared.output, 'y');
  const stagesPerRound = half + 2 * (n - half);
  return [
    ...parts.flatMap(each => each.helpers),
    'func main() {',
    'var memory runtime.MemStats',
    'runtime.ReadMemStats(&memory)',
    'before := memory.TotalAlloc',
    'start := time.Now()',
    'var checksum int32',
    `for round := int32(0); round < ${rounds}; round++ {`,
    `checksum += F(${range(0, n).map(p => argument(t, p, 0)).join(', ')})`,
    ...shared.lines, ...restA.lines, ...restB.lines,
    `checksum += ${restA.output} + ${restB.output}`,
    '}',
    'elapsed := time.Since(start).Nanoseconds()',
    'runtime.ReadMemStats(&memory)',
    'fmt.Println(elapsed, checksum, float64(memory.TotalAlloc-before) / '
      + `${rounds * stagesPerRound})`,
    '}'
  ];
};

// The checksum from the semantics, int32 wrapping throughout.
const expected = (t, n, rounds) => {
  const half = Math.floor(n / 2);
  const value = (round, k, variant) => {
    const kind = k % t;
    return kind === 0 ? (Math.imul(round, 31) + k + 7 * variant) | 0
      : kind === 1 ? ((round + k + variant) % 2 === 0 ? k + 1 : 0)
        : (round + k + variant) | 0;
  };
  const applied = (round, variantOf) => {
    let total = 0;
    for (let step = 0; step < 2 * n; step++) {
      const k = (step * stride) % n;
      total = (total + Math.imul(step + 1, value(round, k, variantOf(k))))
        | 0;
    }
    return total;
  };
  let checksum = 0;
  for (let round = 0; round < rounds; round++) {
    for (const variant of [0, 1, 2]) {
      checksum = (checksum + applied(round, k =>
        k < half || variant === 0 ? 0 : variant)) | 0;
    }
  }
  return checksum;
};

// Mode `tNN`: NN distinct parameter types (at least 3).
export const sharedBody = (n, rounds, mode) => {
  const t = Number(mode.slice(1));
  const go = [
    'package main',
    'import (\n"fmt"\n"runtime"\n"time"\n)',
    ...range(0, t - 2).map(index => `type c${index} struct { v int32 }`),
    'func pick(b bool, w int32) int32 { if b { return w }; return 0 }',
    `type T1 func(${goKind((n - 1) % t)}) int32`,
    ...range(2, n + 1).map(m =>
      `type T${m} func(${goKind((n - m) % t)}) T${m - 1}`),
    `func F(${range(0, n).map(p => `p${p} ${goKind(p % t)}`)
      .join(', ')}) int32 {`,
    'var total int32',
    ...body(t, n),
    'return total',
    '}',
    ...stages(t, n),
    ...entry(t, n),
    ...driver(t, n, rounds)
  ].join('\n') + '\n';
  return { go, expected: expected(t, n, rounds) };
};
