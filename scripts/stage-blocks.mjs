// Block-split application (FN001 Task 1, round 2). An application of a
// staged value to many arguments in one Go function builds in roughly
// quadratic time (design §13), so the chain is cut into top-level helpers
// of at most `block` stages. A helper receives the value reached so far and
// the locals its argument expressions read (`round` here), and evaluates
// each argument in place, immediately before the stage that receives it:
// no argument is evaluated earlier than in the unsplit chain, so stage
// bodies run between the same arguments as before.

export const range = (from, to) =>
  Array.from({ length: Math.max(0, to - from) }, (_, index) => from + index);

// `typeAt(p)` is the Go type of the value awaiting argument `p` (the
// result type at `to`); `argAt(p)` is argument `p`'s expression.
export const segment = ({ prefix, from, to, block, typeAt, argAt }) => {
  const helpers = [];
  const names = [];
  for (let start = from; start < to; start += block) {
    const end = Math.min(start + block, to);
    const name = `${prefix}${start}`;
    helpers.push(
      `func ${name}(s${start} ${typeAt(start)}, round int32) `
        + `${typeAt(end)} {`,
      ...range(start, end).map(p => `s${p + 1} := s${p}(${argAt(p)})`),
      `return s${end}`,
      '}'
    );
    names.push(name);
  }
  return { helpers, names };
};

// The caller's side: one statement per helper, threading the value.
export const threaded = (names, input, label) => {
  const lines = names.map((name, index) => `${label}${index + 1} := `
    + `${name}(${index === 0 ? input : `${label}${index}`}, round)`);
  return { lines, output: names.length ? `${label}${names.length}` : input };
};

// A driver applying `fValue` through all `n` stages per round, in blocks.
export const blockDriver = ({ n, rounds, block, typeAt, argAt }) => {
  const split = segment({ prefix: 'applyBlock', from: 0, to: n, block,
    typeAt, argAt });
  const applied = threaded(split.names, `T${n}(fValue)`, 'v');
  return [
    ...split.helpers,
    'func main() {',
    'start := time.Now()',
    'var checksum int32',
    `for round := int32(0); round < ${rounds}; round++ {`,
    ...applied.lines,
    `checksum += ${applied.output}`,
    '}',
    'fmt.Println(time.Since(start).Nanoseconds(), checksum)',
    '}'
  ];
};

// `b64` selects blocks of 64; any other mode is not a block mode.
export const blockSize = mode => /^b\d+$/.test(mode)
  ? Number(mode.slice(1)) : null;
