import test from 'node:test';
import assert from 'node:assert/strict';
import { Right } from '../output/Data.Either/index.js';
import { lex } from '../output/Format.Lex/index.js';
import { parse } from '../output/Format.Parse/index.js';
import { nestingLimit } from '../output/Format.Parse.Grammar/index.js';
import { rejectedAt, spanAt } from './support.mjs';
import { resolved } from './phases.mjs';
import { shape } from './fn-shape.mjs';

// FN001 Task 3: function types, lambdas, postfix application and pipes,
// through Parse (and Resolve where a type is compared). Names are
// test/fn-names.test.mjs.
const main = ' fn main(): Int = 0;';

const parsedBody = source => {
  const result = parse(`fn f(x: Int): Int = ${source};`);
  assert.ok(result instanceof Right, JSON.stringify(result));
  return result.value0.functions[0].body;
};

const bodyShape = source => shape(parsedBody(source));
const bodySpan = (body, text) => spanAt(`fn f(x: Int): Int = ${body};`, text);

const parameterType = source => resolved(
  `fn f(g: ${source}): Int = 0;${main}`).functions[0].parameters[0].ty;

test('-> and |> lex longest first, beside a negative literal and |', () => {
  const result = lex('a->-1|>|b- >1');
  assert.ok(result instanceof Right);
  assert.deepEqual(result.value0.map(token => token.text),
    ['a', '->', '-', '1', '|>', '|', 'b', '-', '>', '1']);
});

test('-> is right-associative and a group is notation for a spine', () => {
  assert.equal(shape(parse('fn f(g: Int -> Bool -> Int): Int = 0;')
    .value0.functions[0].parameters[0].ty),
  'FunRef(IntRef, FunRef(BoolRef, IntRef))');
  const spine = parameterType('Int -> Bool -> Int');
  assert.deepEqual(parameterType('(Int, Bool) -> Int'), spine);
  assert.deepEqual(parameterType('Int -> (Bool -> Int)'), spine);
  assert.deepEqual(parameterType('(Int) -> (Bool) -> Int'), spine);
  assert.notDeepEqual(parameterType('(Int -> Bool) -> Int'), spine);
  assert.equal(shape(parameterType('(Int -> Bool) -> Int')),
    'TFun(TFun(TInt, TBool), TInt)');
});

const syntaxRows = [
  ['fn f(): (Int, Bool) = 1;', '=', 0, 'Expected ->'],
  ['fn f(g: (Int, Bool, a)): Int = 1;', ')', 1, 'Expected ->'],
  ['fn f(): () -> Int = 1;', ')', 1, 'Expected a type'],
  ['fn f(): Int -> = 1;', '=', 0, 'Expected a type'],
  ['fn f(): Int = (fn() => 1)(1);', ')', 1, 'Expected a parameter'],
  ['fn f(): Int = (fn(1) => 1)(1);', '1', 0, 'Expected a parameter'],
  ['fn f(): Int = (fn(X) => 1)(1);', 'X', 0, 'Expected a parameter'],
  ['fn f(): Int = (fn(x,) => 1)(1);', ')', 1, 'Expected a parameter'],
  ['fn f(): Int = fn x => 1;', 'x', 0, "Expected '('"],
  ['fn f(x: Int): Int = 1 + fn(y) => y;', 'fn', 1, 'Expected an expression'],
  ['fn f(x: Int): Int = x |> fn(y) => y;', 'fn', 1, 'Expected an expression'],
  ['fn f(x: Int): Int = x |> if true then x else x;', 'if', 0,
    'Expected an expression'],
  ['fn f(x: Int): Int = x |> match x { _ => x };', 'match', 0,
    'Expected an expression'],
  ['fn f(x: Int): Int = f(1)();', ')', 2, 'Expected an expression'],
  ['fn f(x: Int): Int = (f)();', ')', 2, 'Expected an expression']
];

for (const [source, text, nth, expected] of syntaxRows) {
  test(`E_SYNTAX ${expected}: ${source}`, () => {
    assert.equal(rejectedAt(source + main, 'E_SYNTAX', text, nth).message,
      expected);
  });
}

test('a lambda extends right; |> is looser than comparison, left first',
  () => {
    assert.equal(bodyShape('(fn(y) => y |> g)'),
      'Lambda([{name: Just(y), ty: Nothing}], Pipe(Variable(y), Variable(g)))');
    assert.equal(bodyShape('a < b |> g'),
      'Pipe(Compare(Less, Variable(a), Variable(b)), Variable(g))');
    assert.equal(bodyShape('a |> g < b'),
      'Pipe(Variable(a), Compare(Less, Variable(g), Variable(b)))');
    assert.equal(bodyShape('a |> g |> h(1)'),
      'Pipe(Pipe(Variable(a), Variable(g)), Call(h, [Integer(1)]))');
    assert.equal(bodyShape('a + 1 |> g'),
      'Pipe(Add(Variable(a), Integer(1)), Variable(g))');
    assert.equal(bodyShape('if a then b else c |> g'),
      'If(Variable(a), Variable(b), Pipe(Variable(c), Variable(g)))');
    assert.equal(bodyShape('g(fn(y) => y)'),
      'Call(g, [Lambda([{name: Just(y), ty: Nothing}], Variable(y))])');
  });

// A postfix chain is one Apply of every group's arguments in order: by
// design §5 `e(a)(b)` is `e(a, b)`, with the same order and boundaries.
test('postfix application repeats on any primary; a name call stays Call',
  () => {
    assert.equal(bodyShape('g(1)(2)(3, 4)'), 'Apply(Call(g, [Integer(1)]), '
      + '[Integer(2), Integer(3), Integer(4)])');
    assert.equal(bodyShape('(h)(1)(2)'),
      'Apply(Variable(h), [Integer(1), Integer(2)])');
    assert.equal(bodyShape('(g)(x)'), 'Apply(Variable(g), [Variable(x)])');
    assert.equal(bodyShape('make()(x)'),
      'Apply(Call(make, []), [Variable(x)])');
    assert.equal(bodyShape('(fn(y) => y)(1)'), 'Apply(Lambda([{name: '
      + 'Just(y), ty: Nothing}], Variable(y)), [Integer(1)])');
    assert.equal(bodyShape('1(2)'), 'Apply(Integer(1), [Integer(2)])');
  });

// The callee of a chain is one level deeper however long the chain is, so
// a long chain (plan Task 8: 1,000 partial applications) is one node.
const chainLength = 1000;
const chainSeconds = 5;
const millisecondsPerSecond = 1000;

test(`a chain of ${chainLength} postfix groups resolves to one Apply`, () => {
  const groups = Array.from({ length: chainLength }, (_, k) => `(${k})`);
  const started = performance.now();
  const program = resolved(`fn g(x: Int): Int = x; fn f(x: Int): Int = `
    + `g(0)${groups.join('')};${main}`);
  const seconds = (performance.now() - started) / millisecondsPerSecond;
  assert.ok(seconds < chainSeconds, `took ${seconds} s`);
  const body = program.functions[1].body;
  assert.equal(shape(body.value1), 'Call(0, [Integer(0)])');
  assert.equal(body.value2.length, chainLength);
  assert.equal(shape(body.value2.at(-1)), `Integer(${chainLength - 1})`);
});

test('lambda, application and pipe spans', () => {
  const lambda = 'fn(y: Int, _) => y + 1';
  assert.deepEqual(parsedBody(`(${lambda})`).value0, bodySpan(`(${lambda})`,
    lambda));
  const parameters = parsedBody(`(${lambda})`).value1;
  assert.deepEqual(parameters.map(parameter => parameter.span),
    [bodySpan(`(${lambda})`, 'y'), bodySpan(`(${lambda})`, '_')]);
  assert.equal(shape(parameters), '[{name: Just(y), ty: Just(IntRef)}, '
    + '{name: Nothing, ty: Nothing}]');
  const applied = parsedBody('g(1)(2)(3)');
  assert.deepEqual(applied.value0, bodySpan('g(1)(2)(3)', 'g(1)(2)(3)'));
  assert.deepEqual(applied.value1.value0, bodySpan('g(1)(2)(3)', 'g(1)'));
  // An application of a parenthesized callee starts at its `(` (FN001
  // Task 4 review; Task 3 started it inside the parentheses).
  assert.deepEqual(parsedBody('(g)(x)').value0, bodySpan('(g)(x)', '(g)(x)'));
  assert.deepEqual(parsedBody('((g))(x)(y)').value0,
    bodySpan('((g))(x)(y)', '((g))(x)(y)'));
  assert.deepEqual(parsedBody('(g)').value0, bodySpan('(g)', 'g'));
  assert.deepEqual(parsedBody('a + 1 |> g(2)').value0,
    bodySpan('a + 1 |> g(2)', 'a + 1 |> g(2)'));
});

test('arrow types parse in fields, results and lambda annotations', () => {
  const program = resolved('type Box(a) = Box(a -> a) | Both((a, Int) -> a);'
    + ' fn f(x: a): Int -> a = (fn(y: a -> Int, _: Bool) => x)(x);' + main);
  assert.equal(shape(program.ctors.map(ctor => ctor.fields)),
    '[[TFun(TVar(0), TVar(0))], [TFun(TVar(0), TFun(TInt, TVar(0)))]]');
  assert.equal(shape(program.functions[0].result), 'TFun(TInt, TVar(0))');
});

// ADR 006 with design §1's measure: a parameter side is one level deeper,
// a result side is not. Parentheses add nothing to the measure, but count
// toward the limit while parsed, so parsing never recurses past it.
const spineOf = length => `${'Int -> '.repeat(length)}Int`;
const parameterNest = depth =>
  `${'('.repeat(depth - 1)}Int -> Int${') -> Int'.repeat(depth - 1)}`;
const listed = (depth, inner) => `type L(a) = N; fn f(g: ${'L('.repeat(depth)}`
  + `${inner}${')'.repeat(depth)}): Int = 0;${main}`;
const spineLength = 200;

test(`a written spine of ${spineLength} parameters is one level`, () => {
  let ty = parameterType(spineOf(spineLength));
  for (let count = 0; count < spineLength; count++) ty = ty.value2;
  assert.equal(shape(ty), 'TInt');
  resolved(listed(nestingLimit - 1, spineOf(spineLength)));
});

test(`${nestingLimit} nested parameter positions resolve`, () => {
  resolved(`fn f(g: ${parameterNest(nestingLimit)}): Int = 0;${main}`);
});

test(`${nestingLimit + 1} nested parameter positions are E_NESTING`, () => {
  const source = `fn f(g: ${parameterNest(nestingLimit + 1)}): Int = 0;${main}`;
  const diagnostic = rejectedAt(source, 'E_NESTING', '->');
  assert.equal(diagnostic.message, `Nesting exceeds ${nestingLimit} levels`);
});

test('a parameter adds a level beneath type arguments, a result does not',
  () => {
    resolved(listed(nestingLimit, 'Int'));
    resolved(`type L(a) = N; fn f(g: Int -> ${'L('.repeat(nestingLimit)}Int`
      + `${')'.repeat(nestingLimit)}): Int = 0;${main}`);
    resolved(listed(0, `(Int -> ${'L('.repeat(nestingLimit - 1)}Int`
      + `${')'.repeat(nestingLimit - 1)}) -> Int`));
    const source = listed(nestingLimit, 'Int -> Int');
    assert.equal(rejectedAt(source, 'E_NESTING', '->').message,
      `Nesting exceeds ${nestingLimit} levels`);
  });

// `L(Int -> Int) -> Int` is three levels deep: its parameter, that
// parameter's argument, and the parameter inside the argument.
const innerParameter = depth => listed(depth, 'L(Int -> Int) -> Int');

test('a parameter inside a parameter counts both levels', () => {
  resolved(innerParameter(nestingLimit - 3));
  assert.equal(rejectedAt(innerParameter(nestingLimit - 2), 'E_NESTING',
    '->', 1).message, `Nesting exceeds ${nestingLimit} levels`);
});

const parenthesized = depth => `fn f(g: ${'('.repeat(depth)}Int`
  + `${')'.repeat(depth)}): Int = 0;${main}`;

test('parentheses count toward the limit while parsed', () => {
  resolved(parenthesized(nestingLimit));
  assert.equal(rejectedAt(parenthesized(nestingLimit + 1), 'E_NESTING', 'Int')
    .message, `Nesting exceeds ${nestingLimit} levels`);
});

// The (limit + 1)-th parenthesis is refused before its contents, at the
// next one, so parsing never recurses past the limit.
test('parentheses nested ten times past the limit are E_NESTING', () => {
  rejectedAt(parenthesized(10 * nestingLimit), 'E_NESTING', '(',
    nestingLimit + 2);
});
