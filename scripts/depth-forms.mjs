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

// FN001 forms (ADR 006, Functions). Each has counted depth d and fails at
// d + 1 on its leaf (or, for parameter types, at the innermost `->`). They
// parse and resolve now; Check types them from FN001 Task 4 and Go emits
// them from Task 6, when they join `forms` (and test/depth.test.mjs). Until
// then test/fn-depth.test.mjs checks them through Resolve, and
// scripts/depth-probe.mjs measures them only when named.

// Generic, so the function's own signature adds no depth.
const apply = 'fn apply(f: a): Int = 0; ';
const lambdaText = 'fn(x: Int) => ';

// `apply(` is one level and each piece one more; `1` is the leaf.
const applied = pieces => {
  const before = apply + main('Int') + 'apply(' + pieces.join('');
  const opened = pieces.filter(piece => piece === '(').length;
  return {
    source: `${before}1${')'.repeat(opened + 1)};`, at: before.length,
    text: '1', output: '0\n'
  };
};

const alternating = count => Array.from({ length: count },
  (_, index) => (index % 2 === 0 ? '(' : lambdaText));

export const functionForms = {
  'lambda-bare': d => applied(Array(d - 1).fill(lambdaText)),
  'lambda-parens': d => applied(alternating(d - 1)),
  // (…(Int -> Int) -> Int…): d parameter positions, d - 1 parentheses.
  'parameter-types': d => {
    const before = `fn f(g: ${'('.repeat(d - 1)}Int `;
    return {
      source: `${before}-> Int${') -> Int'.repeat(d - 1)}): Int = 0; `
        + `${main('Int')}0;`,
      at: before.length, text: '->', output: '0\n'
    };
  },
  'type-parentheses': d => {
    const before = `fn f(g: ${'('.repeat(d)}`;
    return {
      source: `${before}Int${')'.repeat(d)}): Int = 0; ${main('Int')}0;`,
      at: before.length, text: 'Int', output: '0\n'
    };
  },
  // A lambda annotation L^(d-1)(Int) inside `apply(`, one level.
  'annotation-types': d => {
    const before = 'type L(a) = N; ' + apply + main('Int')
      + `apply(fn(y: ${'L('.repeat(d - 1)}`;
    return {
      source: `${before}Int${')'.repeat(d - 1)}) => 0);`, at: before.length,
      text: 'Int', output: '0\n'
    };
  }
};
