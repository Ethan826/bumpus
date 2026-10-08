import test from 'node:test';
import assert from 'node:assert/strict';
import { bodyTree, bodyType, declared, failsAt, tree } from './fn-checked.mjs';
import { rejectedAt } from './support.mjs';

// FN001 Task 4: application, partial and over-application, lambdas and
// pipes through Parse, Resolve and Check (design §3-§5). Function ids:
// add 0, add3 1, k 2, id 3, take 4, f 5; constructors Nil 0, Cons 1.
const prelude = 'type List(a) = Nil | Cons(a, List(a)); '
  + 'type Box(a) = Box(a -> a); '
  + 'fn add(x: Int, y: Int): Int = x + y; '
  + 'fn add3(x: Int, y: Int, z: Int): Int = x; '
  + 'fn k(x: Int): Int -> Int = add(x); fn id(x: a): a = x; '
  + 'fn take(n: Int, xs: List(a)): List(a) = xs; ';
const main = ' fn main(): Int = 0;';
const ints = 'TFun(TInt, TInt)';
const list = 'TData(0, [TInt])';

// [definition of f, its body's tree, its body's type]
const accepted = [
  ['fn f(): Int -> Int = add(1);', 'Call(0, [], [Integer(1)])', ints],
  ['fn f(): Int -> Int -> Int = add3(1);', 'Call(1, [], [Integer(1)])',
    `TFun(TInt, ${ints})`],
  ['fn f(): List(Int) -> List(Int) = take(3);',
    'Call(4, [TInt], [Integer(3)])', `TFun(${list}, ${list})`],
  ['fn f(): List(Int) -> List(Int) = Cons(1);',
    'Construct(1, [TInt], [Integer(1)])', `TFun(${list}, ${list})`],
  ['fn f(): Int = add(1, 2);', 'Call(0, [], [Integer(1), Integer(2)])',
    'TInt'],
  // Over-application: the saturated call's result applied to the rest.
  ['fn f(): Int = k(1, 2);', 'Apply(Call(2, [], [Integer(1)]), [Integer(2)])',
    'TInt'],
  ['fn f(): Int = k(1)(2);', 'Apply(Call(2, [], [Integer(1)]), [Integer(2)])',
    'TInt'],
  ['fn f(): Int = id(add, 1, 2);', 'Apply(Call(3, '
    + `[TFun(TInt, ${ints})], [FunctionRef(0, [])]), [Integer(1), `
    + 'Integer(2)])', 'TInt'],
  ['fn f(): Int -> Int -> Int = add;', 'FunctionRef(0, [])',
    `TFun(TInt, ${ints})`],
  ['fn f(): Int -> List(Int) -> List(Int) = Cons;', 'CtorRef(1, [TInt])',
    `TFun(TInt, TFun(${list}, ${list}))`],
  ['fn f(): List(Int) = Nil;', 'Construct(0, [TInt], [])', list],
  ['fn f(g: Int -> Int -> Int): Int = g(1, 2);',
    'Apply(Local(0), [Integer(1), Integer(2)])', 'TInt'],
  ['fn f(g: Int -> Int -> Int): Int -> Int = g(1);',
    'Apply(Local(0), [Integer(1)])', ints],
  ['fn f(): Int -> Int = fn(x) => x + 1;',
    'Lambda([{local: Just(0), ty: TInt}], Add(Local(0), Integer(1)))', ints],
  ['fn f(): Bool -> Int -> Int = fn(_, y) => y;',
    'Lambda([{local: Nothing, ty: TBool}, {local: Just(0), ty: TInt}], '
    + 'Local(0))', `TFun(TBool, ${ints})`],
  ['fn f(x: a): a = (fn(y: a) => y)(x);',
    'Apply(Lambda([{local: Just(1), ty: TVar(Rigid(0))}], Local(1)), '
    + '[Local(0)])', 'TVar(Rigid(0))'],
  ['fn f(xs: List(Int)): List(Int) = xs |> take(3);',
    'Pipe(Local(0), Call(4, [TInt], [Integer(3)]))', list],
  // `x |> k(1)` is `k(1, x)`: k's result, a function, applied to x.
  ['fn f(x: Int): Int = x |> k(1);', 'Pipe(Local(0), Call(2, [], '
    + '[Integer(1)]))', 'TInt'],
  ['fn f(x: Int): Int = x |> add(1) |> (fn(y) => y);',
    'Pipe(Pipe(Local(0), Call(0, [], [Integer(1)])), '
    + 'Lambda([{local: Just(1), ty: TInt}], Local(1)))', 'TInt'],
  ['fn f(): Int = id(fn(x) => x + 1, 2);', 'Apply(Call(3, [' + ints + '], '
    + '[Lambda([{local: Just(0), ty: TInt}], Add(Local(0), Integer(1)))]), '
    + '[Integer(2)])', 'TInt']
];

for (const [definition, expectedTree, expectedType] of accepted) {
  test(`checks ${definition}`, () => {
    const source = prelude + definition + main;
    assert.equal(bodyTree(source, 'f'), expectedTree);
    assert.equal(bodyType(source, 'f'), expectedType);
  });
}

test('an unused lambda parameter becomes a hole', () => {
  const source = prelude + 'fn f(): Bool = match (fn(x) => 1) '
    + '{ g => true };' + main;
  const scrutinee = declared(source, 'f').body.value0.node.value0;
  assert.equal(tree(scrutinee.value0.ty), 'TFun(TVar(Hole(0)), TInt)');
});

// [definition of f, marker, text, code, message]
const rejections = [
  ['fn f(x: Int): Int = x(1);', 'x(', '1', 'E_TYPE',
    'Expected a function, found Int'],
  ['fn f(g: Int -> Int): Int = g(1, 2);', 'g(1', '2', 'E_TYPE',
    'Expected a function, found Int'],
  ['fn f(): Int = add(1, 2)(3);', ')(', '3', 'E_TYPE',
    'Expected a function, found Int'],
  ['fn f(x: a): a = x(1);', 'x(', '1', 'E_TYPE',
    'Expected a function, found a'],
  ['fn f(xs: List(Int)): Int = xs(1);', 'xs(', '1', 'E_TYPE',
    'Expected a function, found List(Int)'],
  ['fn f(x: Int): Int = x |> 2;', '= x |>', 'x', 'E_TYPE',
    'Expected a function, found Int'],
  ['fn f(b: Bool): Int = b |> add(1);', '= b |>', 'b', 'E_TYPE',
    'Expected Int, found Bool'],
  // Over-application past a result that is not a function keeps E_ARITY.
  ['fn f(): Int = add(1, 2, 3);', '= add', 'add(1, 2, 3)', 'E_ARITY',
    'Wrong number of arguments'],
  ['fn f(x: a): a = id(x, 1);', '= id', 'id(x, 1)', 'E_ARITY',
    'Wrong number of arguments'],
  ['fn f(): Int = id(1, 2);', '= id', 'id(1, 2)', 'E_ARITY',
    'Wrong number of arguments'],
  ['fn f(): List(Int) = Cons(1, Nil, 2);', '= Cons', 'Cons(1, Nil, 2)',
    'E_ARITY', 'Wrong number of arguments'],
  // Through a result variable the n arguments are checked first (design
  // §9, Task 4 review): pre-FN001 these were E_ARITY at the outer call.
  ['fn f(): Int = id(true + 1, 2);', '= id', 'true', 'E_TYPE',
    'Expected Int, found Bool'],
  ['fn f(): Int = id(id(1, 2), 3);', 'id(id', 'id(1, 2)', 'E_ARITY',
    'Wrong number of arguments'],
  // A pipe into a saturated call is that call over-applied; a declared
  // result that is no function is reported before the call's arguments.
  ['fn f(x: Int): Int = x |> add(1, 2);', '|> add', 'add(1, 2)', 'E_ARITY',
    'Wrong number of arguments'],
  ['fn f(): Int = 1 |> add(true, 2);', '|> add', 'add(true, 2)', 'E_ARITY',
    'Wrong number of arguments'],
  ['fn f(x: a, n: Int): a = (fn(y: a) => y)(n);', ')(n', 'n', 'E_TYPE',
    'Expected a, found Int'],
  ['fn f(): Int = match (fn(g) => g(g)) { _ => 0 };', '(g)) {', 'g',
    'E_TYPE', 'Infinite type: _ occurs in _ -> _']
];

for (const [definition, marker, text, code, message] of rejections) {
  test(`${code} ${message}: ${definition}`, () => {
    const diagnostic = failsAt(prelude + definition + main, marker, text);
    assert.equal(diagnostic.code, code);
    assert.equal(diagnostic.message, message);
  });
}

test('empty calls keep their errors', () => {
  const source = prelude + 'fn f(g: Int -> Int): Int = g();' + main;
  assert.equal(rejectedAt(source, 'E_NOT_CALLABLE', 'g()').message,
    'Local is not callable: g');
  assert.equal(rejectedAt(prelude + 'fn f(): Int = add();' + main, 'E_ARITY',
    'add()').message, 'Wrong number of arguments');
});
