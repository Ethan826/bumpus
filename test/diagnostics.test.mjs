import test from 'node:test';
import assert from 'node:assert/strict';
import { rejected } from './support.mjs';

// Characterization: recorded from the compiler before diagnostics became
// structured data. Each row is one message family; text must not change.
const list = 'type IntList = Nil | Cons(Int, IntList);';
const pair = 'type P = Pair(Int, Int);';
const tail = ' fn main(): Int = 0;';

const rows = [
  ['fn main(): Int = @;', 'E_LEX', 17, 18, 'Unexpected character'],
  ['fn main(): ', 'E_SYNTAX', 11, 11, 'Expected a token'],
  ['fn main: Int = 1;', 'E_SYNTAX', 7, 8, "Expected '('"],
  ['fn 1(): Int = 1;', 'E_SYNTAX', 3, 4, 'Expected an identifier'],
  ['type t = A;', 'E_SYNTAX', 5, 6, 'Expected a capitalized name'],
  ['fn main(): int = 1;', 'E_SYNTAX', 11, 14, 'Expected a type'],
  ['fn main(): Int = match 1 { + => 1 };', 'E_SYNTAX', 27, 28,
    'Expected a pattern'],
  ['fn main(): Int = -true;', 'E_SYNTAX', 18, 22,
    'Expected digits after minus'],
  ['fn main(): Int = ;', 'E_SYNTAX', 17, 18, 'Expected an expression'],
  ['fn main(): Int = 2147483648;', 'E_INTEGER', 17, 27,
    'Integer literal is outside signed 32-bit range'],
  [`fn main(): Int = ${'('.repeat(129)}1${')'.repeat(129)};`, 'E_NESTING',
    146, 147, 'Nesting exceeds 128 levels'],
  ['fn x(): Int = 1;', 'E_ENTRY', 0, 0, 'Expected fn main()'],
  ['fn main(x: Int): Int = x;', 'E_ENTRY', 0, 25,
    'main must have no parameters'],
  ['type A = X; type A = Y;' + tail, 'E_DUPLICATE', 0, 11, 'Duplicate type A'],
  ['type A = X | X;' + tail, 'E_DUPLICATE', 9, 10,
    'Duplicate constructor X'],
  ['fn main(): Int = 1; fn main(): Int = 2;', 'E_DUPLICATE', 0, 19,
    'Duplicate function main'],
  ['fn f(x: Int, x: Bool): Int = 1;' + tail, 'E_DUPLICATE', 5, 6,
    'Duplicate parameter x'],
  [pair + ' fn f(p: P): Int = match p { Pair(a, a) => a };' + tail,
    'E_DUPLICATE', 58, 59, 'Duplicate binder a'],
  ['fn main(): Int = y;', 'E_UNBOUND', 17, 18, 'Unbound local y'],
  ['fn main(): Int = missing();', 'E_UNBOUND', 17, 26,
    'Unbound function missing'],
  ['fn f(x: Int): Int = match x { Q => 1 };' + tail, 'E_UNBOUND', 30, 31,
    'Unbound constructor Q'],
  ['fn f(x: Q): Int = 1;' + tail, 'E_UNBOUND', 8, 9, 'Unbound type Q'],
  ['fn f(x: Int): Int = x();' + tail, 'E_NOT_CALLABLE', 20, 23,
    'Local is not callable: x'],
  ['type L = N; fn f(): L = N();' + tail, 'E_NOT_CALLABLE', 24, 27,
    'Constructor is not callable: N'],
  ['fn f(x: Int): Int = x; fn main(): Int = f();', 'E_ARITY', 40, 43,
    'Wrong number of arguments'],
  [pair + ' fn f(p: P): Int = match p { Pair(a) => a };' + tail, 'E_ARITY',
    53, 60, 'Wrong number of fields'],
  [pair + ' fn f(): P = Pair;' + tail, 'E_ARITY', 37, 41,
    'Constructor Pair needs arguments'],
  ['fn main(): Int = true + 1;', 'E_TYPE', 17, 21, 'Expected Int, found Bool'],
  ['fn main(): Int = if 1 then 2 else 3;', 'E_TYPE', 20, 21,
    'Expected Bool, found Int'],
  [list + ' fn f(): IntList = 1;' + tail, 'E_TYPE', 59, 60,
    'Expected IntList, found Int'],
  [list + ' fn f(): Int = Nil;' + tail, 'E_TYPE', 55, 58,
    'Expected Int, found IntList'],
  ['fn f(x: Bool): Int = match x { 1 => 1 };' + tail, 'E_TYPE', 31, 32,
    'Expected Bool, found Int'],
  ['type L = N; fn f(x: Int): Int = match x { N => 1 };' + tail, 'E_TYPE',
    42, 43, 'Expected Int, found L'],
  ['fn f(x: Bool): Int = match x { _ => 1, true => 2 };' + tail,
    'E_REDUNDANT', 39, 43, 'Redundant match arm'],
  [list + ' fn f(x: IntList): Int = '
    + 'match x { Nil => 0, Cons(_, Cons(_, _)) => 1 };' + tail,
  'E_NON_EXHAUSTIVE', 65, 111, 'Missing pattern: Cons(_, Nil)'],
  ['fn f(x: Bool): Int = match x { true => 1 };' + tail, 'E_NON_EXHAUSTIVE',
    21, 42, 'Missing pattern: false'],
  ['fn f(x: Int): Int = match x { 0 => 1, 1 => 2 };' + tail,
    'E_NON_EXHAUSTIVE', 20, 46, 'Missing pattern: 2'],
  ['type P = Pair(Bool, Int); fn f(x: P): Int = '
    + 'match x { Pair(true, _) => 1 };' + tail,
  'E_NON_EXHAUSTIVE', 44, 74, 'Missing pattern: Pair(false, _)']
];

const position = offset => ({ offset, line: 1, column: offset + 1 });

test('every diagnostic family keeps its code, span and text', () => {
  for (const [source, code, start, end, message] of rows) {
    const diagnostic = rejected(source, code);
    assert.deepEqual(
      { span: diagnostic.span, message: diagnostic.message },
      { span: { start: position(start), end: position(end) }, message },
      source);
  }
});

// Structured problems carry data; only Format.Diagnostic writes their text.
const load = name => import(`../output/${name}/index.js`);

test('Format renders type names and witnesses from problem data', async () => {
  const { message, wire } = await load('Format.Diagnostic');
  const problem = await load('Domain.Problem');
  const { WAny, WCtor, WInt, WBool, DataName, IntName } = problem;
  const mismatch = problem.TypeMismatch.create(DataName.create('IntList'))(
    IntName.value);
  assert.equal(message(mismatch), 'Expected IntList, found Int');
  const nil = WCtor.create('Nil')([]);
  const cons = WCtor.create('Cons')([WAny.value, nil]);
  assert.equal(message(problem.NonExhaustive.create(cons)),
    'Missing pattern: Cons(_, Nil)');
  const literals = WCtor.create('Pair')([WInt.create(-1), WBool.create(true)]);
  assert.equal(message(problem.NonExhaustive.create(literals)),
    'Missing pattern: Pair(-1, true)');
  const span = { start: position(0), end: position(1) };
  assert.deepEqual(wire({ problem: problem.Internal.create('Broken'), span }),
    { code: 'E_INTERNAL', message: 'Broken', span });
});

// Ruling R5: a table miss is a compiler bug, never a vacuously complete match.
test('coverage reports an invalid type id as E_INTERNAL', async () => {
  const { coverage } = await load('Features.Check.Coverage');
  const { wire } = await load('Format.Diagnostic');
  const ir = await load('Domain.IR.Internal');
  const { TData, TInt } = await load('Domain.Resolved');
  const span = { start: position(0), end: position(1) };
  const missingType = TData.create(5);
  const expr = (ty, node) => ir.Expr.create({ ty, span, node });
  const pattern = ir.Pattern.create(
    { ty: missingType, span, shape: ir.Ctor.create(0)([]) });
  const arm = { pattern, body: expr(TInt.value, ir.Integer.create(0)), span };
  const body = expr(TInt.value,
    ir.Match.create(expr(missingType, ir.Local.create(0)))([arm]));
  const ctor = { name: 'C', owner: 5, fields: [], span };
  const result = coverage({ types: [], ctors: [ctor], entry: 0,
    functions: [{ id: 0, parameters: [], result: TInt.value, body, span }] });
  assert.equal(result.constructor.name, 'Left', 'invalid type id passed');
  assert.deepEqual(wire(result.value0),
    { code: 'E_INTERNAL', message: 'Invalid type id', span });
});

// Review Minor 7: resolution enforces arity, so a field count that disagrees
// with the constructor table is a compiler bug, never truncated or matched.
test('a constructor field-count mismatch is E_INTERNAL', async () => {
  const { coverage } = await load('Features.Check.Coverage');
  const { checkPattern } = await load('Features.Check.Match');
  const ir = await load('Domain.IR.Internal');
  const resolved = await load('Domain.Resolved');
  const { TData, TInt } = resolved;
  const span = { start: position(0), end: position(1) };
  const box = TData.create(0);
  const types = [{ name: 'Box', ctors: [0], span }];
  const ctors = [{ name: 'Wrap', owner: 0, fields: [TInt.value], span }];
  const wild = ir.Pattern.create({ ty: TInt.value, span, shape: ir.Wildcard.value });
  const wrap = fields => ir.Pattern.create(
    { ty: box, span, shape: ir.Ctor.create(0)(fields) });
  const expr = (ty, node) => ir.Expr.create({ ty, span, node });
  const arm = pattern => ({ pattern, body: expr(TInt.value, ir.Integer.create(0)), span });
  const body = expr(TInt.value, ir.Match.create(expr(box, ir.Local.create(0)))(
    [arm(wrap([wild, wild])), arm(wrap([wild]))]));
  const covered = coverage({ types, ctors, entry: 0,
    functions: [{ id: 0, parameters: [], result: TInt.value, body, span }] });
  assert.equal(covered.constructor.name, 'Left', 'over-long row was accepted');
  assert.deepEqual(covered.value0.problem,
    (await load('Domain.Problem')).Internal.create('Coverage field count mismatch'));
  const short = resolved.Ctor.create(span)(0)([]);
  const pattern = checkPattern({ types, ctors })(box)(short);
  assert.equal(pattern.constructor.name, 'Left', 'short pattern was truncated');
  assert.equal(pattern.value0.problem.value0, 'Resolved constructor arity mismatch');
});
