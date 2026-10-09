import test from 'node:test';
import assert from 'node:assert/strict';
import { Left, Right } from '../output/Data.Either/index.js';
import { parse } from '../output/Format.Parse/index.js';
import { resolve } from '../output/Features.Resolve/index.js';
import { check } from '../output/Features.Check/index.js';
import { wire } from '../output/Format.Diagnostic/index.js';
import { compile } from '../output/Program.Compile/index.js';

const checked = source => {
  const parsed = parse(source);
  if (parsed instanceof Left) return parsed;
  const resolved = resolve(parsed.value0);
  return resolved instanceof Left ? resolved : check(resolved.value0);
};
const accepted = source => {
  const result = checked(source);
  assert.ok(result instanceof Right, JSON.stringify(result));
};
const rejected = (source, code, message) => {
  const result = checked(source);
  assert.ok(result instanceof Left, source);
  const diagnostic = wire(result.value0);
  assert.equal(diagnostic.code, code);
  assert.equal(diagnostic.message, message);
};
const rejectedAt = (source, code, message, fragment, occurrence = 0) => {
  const result = checked(source);
  assert.ok(result instanceof Left, source);
  const diagnostic = wire(result.value0);
  assert.equal(diagnostic.code, code);
  assert.equal(diagnostic.message, message);
  const offset = source.indexOf(fragment, occurrence);
  assert.notEqual(offset, -1, fragment);
  const position = at => {
    const prefix = source.slice(0, at);
    const lineStart = prefix.lastIndexOf('\n') + 1;
    return {
      line: prefix.split('\n').length,
      offset: at,
      column: at - lineStart + 1
    };
  };
  assert.deepEqual(diagnostic.span, {
    start: position(offset),
    end: position(offset + fragment.length)
  });
};
const clock = 'effect Clock { fn now(): Int; }; ';
const errors = 'type DbError = DbError; type ValidationError = ValidationError; ';
const main = ' fn main(): Int = 0;';
const state = 'effect State(s) { fn get(): s; fn put(v: s): Unit; }; ';

for (const [name, source] of [
  ['handler installation', clock + 'fn main(): Int = '
    + 'with handler Clock { now() => 42 } { now() };'],
  ['first-class handler', clock + 'fn run(h: Handler(Clock)): Int = '
    + 'with h { now() }; fn main(): Int = run(handler Clock { now() => 42 });'],
  ['handler clauses forward to the outside row', clock
    + 'fn main(): Int with Console = with handler Clock '
    + '{ now() => { print(1); 42 } } { now() };'],
  ['failure is answer-type independent', errors + 'fn main(): Int = '
    + 'handle fail(DbError) { fail(error: DbError) => 42 };'],
  ['Fail clause binder is not a reserved name', errors
    + 'fn main(): Int = handle fail(DbError) { fail(problem: DbError) => 42 };'],
  ['different error families are separate keys', errors
    + 'fn main(): Int = handle handle fail(DbError) '
    + '{ fail(error: ValidationError) => 1 } { fail(error: DbError) => 2 };'],
  ['partial handling forwards the unmentioned family', errors
    + 'fn f(): Int with Fail(DbError) = handle fail(DbError) '
    + '{ fail(error: ValidationError) => 1 };' + main],
  ['deferred failure payload resolves after the lambda is applied', errors
    + 'fn main(): Int = { let raise = fn(error) => fail(error); '
    + 'handle raise(DbError) { fail(error: DbError) => 42 } };'],
  ['row-parameterized field', clock + 'effect Log { fn log(n: Int): Unit; }; '
    + 'type Job(a, ...effects) = Job(Int -> a with ...effects); '
    + 'fn identity(job: Job(Int, Log + Clock)): Job(Int, Log + Clock) = job;'
    + main],
  ['row argument follows the type argument', clock
    + 'effect Log { fn log(n: Int): Unit; }; '
    + 'type Job(a, ...effects) = Job(Int -> a with ...effects); '
    + 'fn use(job: Job(Int, Log + Clock)): Int = 1;' + main],
  ['row arguments include a bare label and pure', 'effect Log { fn log(): Unit; }; '
    + 'type Job(a, ...effects) = Job(Int -> a with ...effects); '
    + 'fn use(job: Job(Int, Log)): Job(Int, Log) = job; '
    + 'fn empty(job: Job(Int, pure)): Job(Int, pure) = job;' + main],
  ['multiple row parameters retain canonical type slots', 'effect Log { fn log(): Unit; }; '
    + 'effect Clock { fn now(): Int; }; '
    + 'type Job(...first, a, ...second) = Job(a -> a with ...first); '
    + 'fn use(job: Job(Log, Int, Clock)): Job(Log, Int, Clock) = job;' + main],
  ['nested State handlers retain type arguments', state
    + 'fn readInt(): Int with State(Int) = with handler State(Int) '
    + '{ get() => 1, put(value) => () } { get() }; '
    + 'fn readBool(): Bool with State(Bool) = with handler State(Bool) '
    + '{ get() => true, put(value) => () } { get() };' + main],
  ['handler type accepts a declared effect key', clock
    + 'fn apply(h: Handler(Clock)): Int = with h { now() };' + main],
  ['Handler with a declared type name remains an ADT',
    'type Foo = Foo; type Handler(a) = Handler(a); '
      + 'fn main(): Handler(Foo) = Handler(Foo);']
]) test(name, () => accepted(source));

for (const [name, source, code, message] of [
  ['missing clause', clock + 'fn main(): Int = '
    + 'with handler Clock {} { 0 };', 'E_HANDLER', 'Missing clause for now'],
  ['duplicate clause', clock + 'fn main(): Int = with handler Clock '
    + '{ now() => 1, now() => 2 } { 0 };', 'E_HANDLER', 'Duplicate clause for now'],
  ['foreign operation', clock + 'fn main(): Int = with handler Clock '
    + '{ put() => 1 } { 0 };', 'E_HANDLER', 'put is not an operation of Clock'],
  ['generic failure family', 'fn raise(error: a): Int with Fail(a) = '
    + 'fail(error);' + main, 'E_TYPE', 'Fail needs a concrete error family'],
  ['same payload family arguments must unify', 'type Error(a) = Error(a); '
    + 'fn main(): Int = handle fail(Error(1)) '
    + '{ fail(error: Error(Bool)) => 0 };', 'E_TYPE', 'Expected Bool, found Int'],
  ['nested unresolved failure payload is visited', 'fn id(x: Int): Int = x; '
    + 'fn f(e: a): Int with Fail(a) + Fail(Int) = fail(id(fail(e)));' + main,
    'E_TYPE', 'Fail needs a concrete error family'],
  ['deferred failure mismatch keeps semantic diagnostic', 'type Error(a) = Error(a); '
    + 'fn main(): Int = { let raise = fn(error) => fail(error); '
    + 'handle raise(Error(1)) { fail(problem: Error(Bool)) => 0 } };',
    'E_TYPE', 'Expected Bool, found Int'],
  ['rigid failure payload is rejected at fail', 'fn raise(error: a): Int '
    + 'with Fail(a) = fail(error);' + main, 'E_TYPE',
    'Fail needs a concrete error family'],
  ['row sort mismatch in a type application', clock
    + 'type Job(a, ...effects) = Job(Int -> a with ...effects); '
    + 'fn use(job: Job(Log + Clock, Int)): Int = 1;' + main,
    'E_TYPE', 'Expected a type, found an effect row'],
  ['type sort mismatch in a type application', clock
    + 'type Job(a, ...effects) = Job(a); '
    + 'fn use(job: Job(Int, Int)): Int = 1;' + main,
    'E_TYPE', 'Expected an effect row, found a type'],
  ['wrong type/row argument arity', 'type Job(a, ...effects) = Job(a); '
    + 'fn use(job: Job(Int)): Int = 1;' + main,
    'E_ARITY', 'Wrong number of type arguments for Job'],
  ['handler nested in ADT cannot be returned from main', clock
    + 'type Box(a) = Box(a); fn main(): Box(Handler(Clock)) = '
    + 'Box(handler Clock { now() => 1 });', 'E_ENTRY',
    'Expected fn main() with a printable result type'],
  ['handler nested in ADT cannot be printed', clock
    + 'type Box(a) = Box(a); fn main(): Int = '
    + '{ print(Box(handler Clock { now() => 1 })); 0 };', 'E_TYPE',
    'Expected a printable value, found Box(Handler(Clock))'],
  ['handler nested in ADT cannot be compared', clock
    + 'type Box(a) = Box(a); fn main(): Bool = '
    + 'Box(handler Clock { now() => 1 }) == '
    + 'Box(handler Clock { now() => 2 });', 'E_TYPE',
    'Type Box(Handler(Clock)) is not comparable'],
  ['main cannot return a handler', clock
    + 'fn main(): Handler(Clock) = handler Clock { now() => 1 };',
    'E_ENTRY', 'Expected fn main() with a printable result type'],
  ['general control', 'fn main(): Int = ctl();',
    'E_SYNTAX', 'General control (ctl/resume) is not supported yet'],
  ['general resume', 'fn main(): Int = resume(0);',
    'E_SYNTAX', 'General control (ctl/resume) is not supported yet'],
  ['general control inside a lambda', 'fn main(): Int = '
    + '((fn(x: Int) => ctl())(0));', 'E_SYNTAX',
    'General control (ctl/resume) is not supported yet']
]) test(name, () => rejected(source, code, message));

test('deferred missing Fail capability keeps effect diagnostic and span', () => {
  const source = 'type DbError = DbError; fn f(): Int with pure = { '
    + 'let raise = fn(error) => fail(error); raise(DbError) };' + main;
  rejectedAt(source, 'E_EFFECT',
    'f performs Fail(DbError), which its signature does not allow',
    'fail(error');
});

test('duplicate handler binders use the parameter diagnostic span', () => {
  const source = 'effect Add { fn add(x: Int, y: Int): Int; }; '
    + 'fn main(): Int = with handler Add { add(x, x) => x } { add(1, 2) };';
  rejectedAt(source, 'E_DUPLICATE', 'Duplicate parameter x', 'x',
    source.indexOf('add(x, x)') + 5);
});

test('checked handlers stop before specialization', () => {
  const result = compile(clock + 'fn main(): Int = '
    + 'with handler Clock { now() => 1 } { now() };');
  assert.ok(result instanceof Left);
  assert.equal(wire(result.value0).message, 'unlowered effect');
});

test('checked failures stop before specialization', () => {
  const result = compile('fn main(): Int = '
    + 'handle fail(1) { fail(problem: Int) => 0 };');
  assert.ok(result instanceof Left);
  assert.equal(wire(result.value0).message, 'unlowered effect');
});

test('handler types stop before specialization', () => {
  const result = compile('fn f(h: Handler(Console with pure)): Int = 0;' + main);
  assert.ok(result instanceof Left);
  assert.equal(wire(result.value0).message, 'unlowered effect');
});

test('handler types in later constructor fields stop before specialization', () => {
  const result = compile('type H = H(Int, Handler(Console with pure));'
    + main);
  assert.ok(result instanceof Left);
  assert.equal(wire(result.value0).message, 'unlowered effect');
});

test('long function-type spines are guarded without recursive traversal', () => {
  const arrows = Array.from({ length: 20000 }, () => 'Int').join(' -> ');
  const result = compile(`fn f(x: Handler(Console with pure) -> ${arrows})`
    + `: Int = 0;${main}`);
  assert.ok(result instanceof Left);
  assert.equal(wire(result.value0).message, 'unlowered effect');
});

test('nested State handlers keep distinct first-seen type arguments', () => {
  accepted(state + 'fn nested(): Int = with handler State(Int) '
    + '{ get() => 1, put(value) => () } { with handler State(Bool) '
    + '{ get() => true, put(value) => () } { get(); }; get() };' + main);
});

for (const [source, message, fragment, occurrence = 0] of [
  [clock + 'fn main(): Int = with handler Clock {} { 0 };',
    'Missing clause for now', 'handler Clock {}'],
  [clock + 'fn main(): Int = with handler Clock '
    + '{ now() => 1, now() => 2 } { 0 };',
    'Duplicate clause for now', 'now() => 2'],
  [clock + 'fn main(): Int = with handler Clock '
    + '{ put() => 1 } { 0 };',
    'put is not an operation of Clock', 'put() => 1']
]) test(`handler diagnostic span: ${message}`, () =>
  rejectedAt(source, 'E_HANDLER', message, fragment));

for (const [source, message, fragment, occurrence = 0] of [
  [clock + 'fn f(): Int with ...e + ...r = 0;' + main,
    'Only one row tail is allowed', '...r'],
  [clock + 'fn f(): Int with ...e + Clock = 0;' + main,
    'Row tail must be last', '...e'],
]) test(`row-tail diagnostic span: ${message}`, () =>
  rejectedAt(source, 'E_SYNTAX', message, fragment));

for (const [source, message, fragment, occurrence = 0] of [
  ['effect Clock { fn now(): Int; }; effect Clock { fn later(): Int; };' + main,
    'Duplicate effect Clock', 'effect Clock { fn later(): Int; };'],
  ['effect Clock { fn now(): Int; fn now(): Int; };' + main,
    'Duplicate operation now', 'fn now(): Int;', 16],
  ['effect State(a, a) { fn get(): a; };' + main,
    'Duplicate type parameter a', 'a',
    'effect State(a, '.length],
  ['effect State { fn put(a: Int, a: Bool): Unit; };' + main,
    'Duplicate parameter a', 'a', 30]
]) test(`duplicate declaration span: ${message}`, () =>
  rejectedAt(source, 'E_DUPLICATE', message, fragment, occurrence));
