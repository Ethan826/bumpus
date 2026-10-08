// Separated baselines (FN001 Task 1, round 2): what a program with one
// `n`-parameter function costs `go build` before any staged value, split
// into the function types alone, the signature with a minimal body, the
// checksum body, and a direct call site. Each program contains only its
// part, so no part's cost hides inside another's.
import { range } from './stage-blocks.mjs';
import { checksum, directDriver, functionTypes, sum } from './stage-shapes.mjs';

const header = ['package main', 'import (\n"fmt"\n"time"\n)'];

// Build-only programs print a placeholder and are never run for timing.
const emptyMain = held => [
  'func main() {',
  'start := time.Now()',
  `fmt.Println(time.Since(start).Nanoseconds(), ${held})`,
  '}'
];

const signature = n => [
  `func f(${range(0, n).map(index => `p${index} int32`).join(', ')}) int32`
    + ' { return p0 }'
];

const baselines = {
  types: n => [...functionTypes(n), 'var held T1',
    ...emptyMain('held == nil')],
  signature: n => [...signature(n), ...emptyMain('f != nil')],
  body: n => [...sum(n), ...emptyMain('f != nil')],
  call: (n, rounds) => [...sum(n), ...directDriver(n, rounds)]
};

export const baselineShapes = Object.keys(baselines);

// `expected` is the checksum a timed run must print, or null if the
// program is build-only.
export const baseline = (shape, n, rounds) => ({
  go: [...header, ...baselines[shape](n, rounds)].join('\n') + '\n',
  expected: shape === 'call' ? checksum(n, rounds) : null
});
