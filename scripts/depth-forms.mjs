// Nesting forms shared by scripts/depth-probe.mjs and test/depth.test.mjs.
// Each form maps a depth d to a well-typed, exhaustive program whose counted
// nesting (Format.Parse.Grammar `nested`) is exactly d, the token where
// E_NESTING is reported when d is one past the limit, and what `run` prints.

const list = 'type L = Nil | Cons(Int, L); ';
const wrap = 'type W = E | N(W); fn id(w: W): W = w; ';

// `head`, then `open` d times, `leaf`, `close` d times, `tail`. The failure
// token is `text` at offset `at` inside the d-th `open` (by default the
// leaf): the first token at level d, such as the d-th `if`'s condition.
const repeated = (shape) => (d) => {
  const before = shape.head + shape.open.repeat(d - 1);
  const source = before + shape.open + shape.leaf + shape.close.repeat(d)
    + shape.tail;
  const failure = shape.failure ?? { at: shape.open.length, text: shape.leaf };
  return {
    source, at: before.length + failure.at, text: failure.text,
    output: shape.output(d)
  };
};

const main = type => `fn main(): ${type} = `;
const one = () => '1\n';

const single = {
  'parens': repeated({ head: main('Int'), open: '(', leaf: '1', close: ')',
    tail: ';', output: one }),
  'if-condition': repeated({ head: main('Bool'), open: 'if ', leaf: 'true',
    close: ' then true else false', tail: ';', output: () => 'true\n' }),
  'if-branch': repeated({ head: main('Int'), open: 'if true then ',
    leaf: '1', close: ' else 0', tail: ';',
    failure: { at: 'if '.length, text: 'true' }, output: one }),
  'match-scrutinee': repeated({ head: main('Int'), open: 'match ',
    leaf: '1', close: ' { _ => 1 }', tail: ';', output: one }),
  'match-arm': repeated({ head: main('Int'), open: 'match 0 { _ => ',
    leaf: '1', close: ' }', tail: ';',
    failure: { at: 'match '.length, text: '0' }, output: one }),
  'call-argument': repeated({ head: 'fn id(x: Int): Int = x; ' + main('Int'),
    open: 'id(', leaf: '1', close: ')', tail: ';', output: one }),
  'constructor-argument': repeated({ head: list + main('L'),
    open: 'Cons(1, ', leaf: 'Nil', close: ')', tail: ';',
    failure: { at: 'Cons('.length, text: '1' },
    output: d => `${'Cons(1, '.repeat(d)}Nil${')'.repeat(d)}\n` }),
  'constructor-pattern': repeated({
    head: list + 'fn f(x: L): Int = match x { ', open: 'Cons(_, ',
    leaf: '_', close: ')', tail: ' => 1, _ => 0 }; fn main(): Int = f(Nil);',
    failure: { at: 'Cons('.length, text: '_' }, output: () => '0\n' }),
  'plus-chain': d => {
    const before = main('Int') + '1' + ' + 1'.repeat(d - 1);
    return {
      source: before + ' + 1;', at: before.length + 1, text: '+',
      output: `${d + 1}\n`
    };
  }
};

// Combined trees: per-form measurements do not show that mixes are safe.
const branches = j => 'if true then '.repeat(j) + '1' + ' else 0'.repeat(j);
const arms = j => 'match 0 { _ => '.repeat(j) + '1' + ' }'.repeat(j);

const mixed = {
  // A parenthesized `if` j deep, then k − 1 more `+` operands: each `+`
  // pushes the operands before it one level deeper (1 + j + k − 1 = d).
  'if-left-of-sum': d => {
    const k = Math.floor(d / 2);
    const before = `${main('Int')}(${branches(d - k)})${' + 1'.repeat(k - 2)}`;
    return {
      source: before + ' + 1;', at: before.length + 1, text: '+',
      output: `${k}\n`
    };
  },
  'parens-in-call-in-constructor': d => {
    const a = Math.floor(d / 3);
    const b = Math.floor(d / 3);
    const c = d - a - b;
    const before = wrap + main('W') + 'N('.repeat(a) + 'id('.repeat(b)
      + '('.repeat(c);
    return {
      source: before + 'E' + ')'.repeat(d) + ';', at: before.length,
      text: 'E', output: `${'N('.repeat(a)}E${')'.repeat(a)}\n`
    };
  },
  // `(m) < (m)` with m a match j deep: 2 + j = d. One past, the left
  // operand reaches the limit and `<` pushes it over.
  'compare-matches': d => {
    const before = `${main('Bool')}(${arms(d - 2)}) `;
    return {
      source: `${before}< (${arms(d - 2)});`, at: before.length, text: '<',
      output: 'false\n'
    };
  }
};

export const forms = { ...single, ...mixed };
