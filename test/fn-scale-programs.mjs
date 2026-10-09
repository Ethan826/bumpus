// FN001 Task 8: the scale programs, generated at any width so that the
// serial tests (5,000 or 1,000 parameters) and scripts/fn-milestone.mjs
// (20,000) build the same shapes. Each returns { source, expected }, the
// expected output of the built program. Bodies are bounded: they read a
// fixed handful of parameters of each kind, so the Go build measures
// FN001's machinery (staged wrapper, entry tables, the n-ary entry call,
// application helpers, named function types, the shared partial) and not
// a 2n-term `+` tree in one Go expression (BACKLOG G003; user decision B,
// 2026-10-09). test/fn-scale.serial.test.mjs keeps its mixed body.
const kinds = ['Int', 'Bool', 'List(Int)'];
const prelude = 'type List(a) = Nil | Cons(a, List(a)); '
  + 'fn head(xs: List(Int)): Int = match xs { Nil => 0, Cons(x, _) => x }; '
  + 'fn pick(b: Bool, w: Int): Int = if b then w else 0; ';

const kindOf = index => kinds[index % kinds.length];
const range = (low, high) => Array.from({ length: high - low },
  (_, step) => low + step);

// Parameters read by a bounded body: the first and last three.
const readIndices = count => [0, 1, 2, count - 3, count - 2, count - 1];
const term = index => [`p${index}`, `pick(p${index}, ${index})`,
  `head(p${index})`][index % kinds.length];
const argument = (index, variant) => [`${(index + variant) % 97}`,
  (index + variant) % 2 === 0 ? 'true' : 'false',
  `Cons(${(index + variant) % 89}, Nil)`][index % kinds.length];
const valueOf = (index, variant) => [(index + variant) % 97,
  (index + variant) % 2 === 0 ? index : 0,
  (index + variant) % 89][index % kinds.length];

const declaration = count => `fn f(${range(0, count)
  .map(index => `p${index}: ${kindOf(index)}`).join(', ')}): Int = `
  + `${readIndices(count).map(term).join(' + ')}; `;
const args = (low, high, variant) => range(low, high)
  .map(index => argument(index, variant)).join(', ');
const total = (count, variant) => readIndices(count)
  .reduce((sum, index) => sum + valueOf(index, variant), 0);
const arrow = (low, high) => `(${range(low, high).map(kindOf).join(', ')})`
  + ' -> Int';

// Called directly, passed as a value, and partially applied over the
// first half with the partial completed twice (shared).
export const wide = count => {
  const half = Math.floor(count / 2);
  const source = prelude + declaration(count)
    + `fn apply(g: ${arrow(0, count)}): Int = g(${args(0, count, 1)}); `
    + `fn twice(h: ${arrow(half, count)}): Int = h(${args(half, count, 0)})`
    + ` + h(${args(half, count, 2)}); fn main(): Int = f(${args(0, count, 0)})`
    + ` + apply(f) + twice(f(${args(0, half, 0)}));`;
  const partial = variant => readIndices(count).reduce((sum, index) =>
    sum + valueOf(index, index < half ? 0 : variant), 0);
  return { source, expected: `${total(count, 0) + total(count, 1)
    + partial(0) + partial(2)}\n` };
};

// f(1)(2)…(count): count - 1 partial applications, then the last call.
export const chain = count => ({
  source: `fn f(${range(0, count)
    .map(index => `p${index}: Int`).join(', ')}): Int = `
    + `${readIndices(count).map(index => `p${index}`).join(' + ')}; `
    + `fn main(): Int = f${range(0, count).map(index => `(${index + 1})`)
      .join('')};`,
  expected: `${readIndices(count).reduce((sum, index) => sum + index + 1, 0)}\n`
});

// A written curried arrow `Int -> Int -> … -> Int` of count parameters.
export const curried = count => ({
  source: `fn f(${range(0, count).map(index => `p${index}: Int`).join(', ')})`
    + `: Int = ${readIndices(count).map(index => `p${index}`).join(' + ')}; `
    + `fn apply(g: ${Array(count + 1).fill('Int').join(' -> ')}): Int = `
    + `g(${range(0, count).map(index => `${index + 1}`).join(', ')}); `
    + 'fn main(): Int = apply(f);',
  expected: `${readIndices(count).reduce((sum, index) => sum + index + 1, 0)}\n`
});

// The function type passed through a generic function and stored in a
// generic type, then called; its partial passes through them too.
export const generic = count => {
  const half = Math.floor(count / 2);
  const source = prelude + declaration(count)
    + 'type Box(a) = Box(a); fn id(x: a): a = x; '
    + 'fn open(b: Box(a)): a = match b { Box(x) => x }; '
    + `fn main(): Int = open(id(Box(f)))(${args(0, count, 0)})`
    + ` + open(id(Box(f(${args(0, half, 0)}))))(${args(half, count, 1)});`;
  const mixed = readIndices(count).reduce((sum, index) =>
    sum + valueOf(index, index < half ? 0 : 1), 0);
  return { source, expected: `${total(count, 0) + mixed}\n` };
};
