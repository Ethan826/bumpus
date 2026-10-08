// Evaluation order across block boundaries (FN001 Task 1, round 2). `g`
// has declared arity m; its body runs on argument m - 1, records
// `enter g`, and returns `f2Value(sum of its arguments)`, a staged value of
// `f2` (arity n - m + 1) still awaiting arguments m … n - 1, whose body
// records `enter f2`. Every argument is `note("a<p><tag>", value)`, which
// records its evaluation. Both use the packed convention (one node type;
// the entry reads the chain in a loop).
//
// The program applies `g` to all n arguments in blocks, then builds one
// shared partial application over the first k > m arguments and completes
// it twice with different arguments. The expected trace and results are
// computed here from the semantics (design §5), not from Go.
import { range, segment, threaded } from './stage-blocks.mjs';

// A packed staged function: types `<name>T1…`, stages, `<name>Value`, and
// `<name>Entry`, which sums its arguments weighted by position and passes
// the total to `finish`.
const packedStaged = (name, arity, result, finish) => [
  `type ${name}T1 func(int32) ${result}`,
  ...range(2, arity + 1).map(m =>
    `type ${name}T${m} func(int32) ${name}T${m - 1}`),
  `type ${name}Node struct { value int32; previous *${name}Node }`,
  `func ${name}Value(x int32) ${name}T${arity - 1} `
    + `{ return ${name}Stage2(&${name}Node{x, nil}) }`,
  ...range(2, arity).map(k =>
    `func ${name}Stage${k}(e *${name}Node) ${name}T${arity - k + 1} `
    + `{ return func(x int32) ${name}T${arity - k} `
    + `{ return ${name}Stage${k + 1}(&${name}Node{x, e}) } }`),
  `func ${name}Stage${arity}(e *${name}Node) ${name}T1 `
    + `{ return func(x int32) ${result} `
    + `{ return ${name}Entry(&${name}Node{x, e}) } }`,
  `func ${name}Entry(e *${name}Node) ${result} {`,
  `trace = append(trace, "enter ${name}")`,
  'var total int32',
  `for index := int32(${arity}); e != nil; index-- `
    + '{ total += index * e.value; e = e.previous }',
  `return ${finish('total')}`,
  '}'
];

const weighted = values => values.reduce((total, value, index) =>
  (total + Math.imul(index + 1, value)) | 0, 0);

export const orderProgram = ({ n, m, k, block }) => {
  const rest = n - m;
  const typeAt = p => p < m ? `gT${m - p}` : p < n ? `f2T${n - p}` : 'int32';
  const value = (p, tag) => ({ '': 1, x: 100, y: 200 }[tag]) + p;
  const argAt = tag => p => `note("a${p}${tag}", ${value(p, tag)})`;
  const part = (prefix, from, to, tag) => segment({ prefix, from, to, block,
    typeAt, argAt: argAt(tag) });
  const full = part('full', 0, n, '');
  const prefix = part('prefix', 0, k, '');
  const x = part('restX', k, n, 'x');
  const y = part('restY', k, n, 'y');
  const fullRun = threaded(full.names, `gT${m}(gValue)`, 'v');
  const shared = threaded(prefix.names, `gT${m}(gValue)`, 'p');
  const runX = threaded(x.names, shared.output, 'x');
  const runY = threaded(y.names, shared.output, 'y');
  const go = [
    'package main',
    'import (\n"fmt"\n"strings"\n)',
    'var trace []string',
    'func note(label string, v int32) int32 '
      + '{ trace = append(trace, label); return v }',
    ...packedStaged('f2', rest + 1, 'int32', total => total),
    ...packedStaged('g', m, `f2T${rest}`, total => `f2Value(${total})`),
    ...full.helpers, ...prefix.helpers, ...x.helpers, ...y.helpers,
    'func main() {',
    'round := int32(0)',
    ...fullRun.lines,
    ...shared.lines,
    ...runX.lines,
    ...runY.lines,
    `fmt.Println(strings.Join(trace, " "))`,
    `fmt.Println(${fullRun.output}, ${runX.output}, ${runY.output})`,
    '}'
  ].join('\n') + '\n';
  return { go, expected: expectedOutput({ n, m, k, value }) };
};

// The semantics: arguments in order; `g`'s body after argument m - 1; the
// shared partial's prefix (and `g`'s body) once; `f2`'s body after each
// completion.
const expectedOutput = ({ n, m, k, value }) => {
  const labels = (from, to, tag) => range(from, to).map(p => `a${p}${tag}`);
  const values = (from, to, tag) => range(from, to).map(p => value(p, tag));
  const gTotal = weighted(values(0, m, ''));
  const result = tag => weighted([gTotal, ...values(m, k, ''),
    ...values(k, n, tag)]);
  const fullResult = weighted([gTotal, ...values(m, n, '')]);
  const trace = [...labels(0, m, ''), 'enter g', ...labels(m, n, ''),
    'enter f2', ...labels(0, m, ''), 'enter g', ...labels(m, k, ''),
    ...labels(k, n, 'x'), 'enter f2', ...labels(k, n, 'y'), 'enter f2'];
  return `${trace.join(' ')}\n${fullResult} ${result('x')} ${result('y')}\n`;
};
