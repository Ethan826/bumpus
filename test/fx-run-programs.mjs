// Programs of test/fx-run.test.mjs: [name, source, expected stdout].
const log = 'effect Log { fn log(n: Int): Unit; }; ';
const clock = 'effect Clock { fn now(): Int; }; ';
const state = 'effect State(s) { fn get(): s; fn put(value: s): Unit; }; ';
const db = 'type DbError = DbError; ';
const list = 'type List(a) = Nil | Cons(a, List(a)); ';
const job = 'type Job(a, ...effects) = Job(Int -> a with ...effects); ';

export const cases = [
  ['clause context: intercept and forward', log
    + 'fn work(): Unit with Log = { log(1); log(2) }; '
    + 'fn main(): Unit with Console = with handler Log { log(n) => print(n) } '
    + '{ with handler Log { log(n) => log(n + 100) } { work() } };',
  '101\n102\n'],
  ['clause context: forwarding handler passed as a value', log
    + 'fn wrap(h: Handler(Log with Log + ...e)): Unit with Log + ...e = '
    + 'with h { log(7) }; fn main(): Unit with Console = { '
    + 'let fwd = handler Log { log(n) => log(n + 100) }; '
    + 'with handler Log { log(n) => print(n) } { wrap(fwd) } };',
  '107\n'],
  ['targeted abort passes an inner handle', db + log
    + 'fn main(): Unit with Console = handle { with handler Log '
    + '{ log(n) => fail(DbError) } { handle log(1) '
    + '{ fail(error: DbError) => print(1) } } } '
    + '{ fail(error: DbError) => print(2) };',
  '2\n'],
  ['a failure ends the body', db + 'fn boom(): Int with Fail(DbError) + Console = '
    + '{ print(1); fail(DbError); print(2); 3 }; '
    + 'fn main(): Int with Console = handle boom() '
    + '{ fail(error: DbError) => 9 };',
  '1\n9\n'],
  ['a failure payload reaches its clause', 'type Code = Code(Int); '
    + 'fn main(): Int = handle fail(Code(41)) '
    + '{ fail(error: Code) => match error { Code(n) => n + 1 } };',
  '42\n'],
  ['partial handling forwards the other family', db
    + 'type Other = Other; fn inner(): Int with Fail(DbError) = '
    + 'handle fail(DbError) { fail(error: Other) => 1 }; '
    + 'fn main(): Int = handle inner() { fail(error: DbError) => 2 };',
  '2\n'],
  ['one family, two payload instantiations', 'type Error(a) = Error(a); '
    + 'fn main(): Int = (handle fail(Error(true)) '
    + '{ fail(error: Error(Bool)) => 2 }) + (handle fail(Error(5)) '
    + '{ fail(error: Error(Int)) => 40 });',
  '42\n'],
  ['nested State(Int) and State(Bool)', state
    + 'fn main(): Unit with Console = with handler State(Int) '
    + '{ get() => 1, put(value) => print(value) } '
    + '{ with handler State(Bool) { get() => true, put(value) => print(value) } '
    + '{ put(get()) }; put(get() + 10) };',
  'true\n11\n'],
  ['generic constant handler', state
    + 'fn constant(v: s): Handler(State(s)) = '
    + 'handler State(s) { get() => v, put(x) => () }; '
    + 'fn main(): Unit with Console = { '
    + 'print(with constant(5) { get() + 1 }); '
    + 'print(with constant(true) { get() }) };',
  '6\ntrue\n'],
  ['fakes and real handlers passed as values', clock + log
    + 'fn stamp(label: Int): Int with Clock + Log = '
    + '{ let t = now(); log(label + t); t }; '
    + 'fn run(c: Handler(Clock with Console + ...e), '
    + 'l: Handler(Log with Clock + Console + ...e)): Int with Console + ...e = '
    + 'with c { with l { stamp(1000) } }; '
    + 'fn main(): Unit with Console = { '
    + 'print(run(handler Clock { now() => 5 }, '
    + 'handler Log { log(n) => print(n) })); '
    + 'print(run(handler Clock { now() => { print(0); 9 } }, '
    + 'handler Log { log(n) => () })) };',
  '1005\n5\n0\n9\n'],
  ['jobs in a list under two handler sets', clock + log + list + job
    + 'fn start(j: Job(Int, Log + Clock), n: Int): Int with Log + Clock = '
    + 'match j { Job(f) => f(n) }; '
    + 'fn runAll(jobs: List(Job(Int, Log + Clock)), n: Int): Int '
    + 'with Log + Clock = match jobs { Nil => 0, '
    + 'Cons(j, rest) => start(j, n) + runAll(rest, n) }; '
    + 'fn main(): Unit with Console = { '
    + 'let jobs = Cons(Job(fn(x) => { log(x); x + now() }), '
    + 'Cons(Job(fn(x) => x + x), Nil)); '
    + 'with handler Clock { now() => 100 } { with handler Log '
    + '{ log(n) => print(n) } { print(runAll(jobs, 1)) } }; '
    + 'with handler Clock { now() => 200 } { with handler Log '
    + '{ log(n) => print(n + 1000) } { print(runAll(jobs, 1)) } } };',
  '1\n103\n1001\n203\n'],
  ['a lambda made under one handler runs under another', clock
    + 'fn make(): Int -> Int with Clock = fn(x) => x + now(); '
    + 'fn run(f: Int -> Int with Clock): Int = '
    + 'with handler Clock { now() => 10 } { f(5) }; '
    + 'fn main(): Int = with handler Clock { now() => 1 } { run(make()) };',
  '15\n'],
  ['an operation is a function value', 'effect Add { fn add(x: Int, y: Int): Int; }; '
    + 'fn twice(f: Int -> Int -> Int, n: Int): Int = f(n, f(n, 1)); '
    + 'fn main(): Int = with handler Add { add(x, y) => x + y } '
    + '{ twice(add, 5) };',
  '11\n'],
  ['a partial operation call supplies its argument now', 'effect Add '
    + '{ fn add(x: Int, y: Int): Int; }; fn main(): Int with Console = '
    + 'with handler Add { add(x, y) => x + y } '
    + '{ let inc = add({ print(1); 1 }); print(2); inc(41) };',
  '1\n2\n42\n'],
  ['recursive handler installation', clock
    + 'fn loop(n: Int): Int with Clock = match n { 0 => now(), _ => '
    + 'with handler Clock { now() => n } { loop(n + -1) } }; '
    + 'fn main(): Int = with handler Clock { now() => 100 } { loop(3) };',
  '1\n'],
  ['handlers stored in data', clock + 'type Box = Box(Handler(Clock)); '
    + 'fn main(): Int = match Box(handler Clock { now() => 8 }) '
    + '{ Box(h) => with h { now() } };',
  '8\n'],
  ['a handler of a console effect layout compiles',
    'fn f(h: Handler(Console with pure)): Int = 1; fn main(): Int = 3;',
  '3\n'],
  ['staged values, matches, pipes and blocks thread the context', clock + list
    + 'fn map(f: a -> b, xs: List(a)): List(b) = match xs { Nil => Nil, '
    + 'Cons(x, rest) => Cons(f(x), map(f, rest)) }; '
    + 'fn sum(xs: List(Int)): Int = match xs { Nil => 0, '
    + 'Cons(x, rest) => x + sum(rest) }; '
    + 'fn add(x: Int, y: Int): Int = x + y; '
    + 'fn curried(x: Int): Int -> Int = fn(y) => x + y; '
    + 'fn main(): Int = with handler Clock { now() => 10 } { '
    + 'let k = now(); let xs = Cons(1, Cons(2, Nil)); '
    + '(map(add(k), xs) |> sum) + sum(map(fn(z) => z + k, xs)) + curried(1)(2) };',
  '49\n'],
  ['two clauses of one family: the first is innermost (payload types)',
    'type Error(a) = Error(a); fn main(): Int = handle fail(Error(5)) '
    + '{ fail(e: Error(Int)) => match e { Error(n) => n }, '
    + 'fail(e: Error(Bool)) => 2 };',
  '5\n'],
  ['two clauses of one family: the first is innermost (result)',
    'fn main(): Int = handle fail(3) { fail(e: Int) => e, fail(e: Int) => 2 };',
  '3\n'],
  ['a pure main beside an unused effectful function', clock
    + 'fn unused(): Int with Clock = now(); fn main(): Int = 7;',
  '7\n']
];

