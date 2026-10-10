// Task 7's executable end-to-end programs, shared by the tests that ran
// them inline (test/fx-specialize.test.mjs, test/fx-handler-check.test.mjs)
// and by test/fx-oracle.test.mjs: [name, source, expected stdout].
const clock = 'effect Clock { fn now(): Int; }; ';
const main = ' fn main(): Int = 0;';

// Task 7 deleted the post-Specialize guard: each program it stopped now
// builds and prints exactly what its handlers say.
export const specialized = [
  ['a handler over now()',
    clock + 'fn main(): Int = with handler Clock { now() => 1 } { now() };',
    '1\n'],
  ['an unused effectful function', clock + 'fn unused(): Int with Clock = now();' + main, '0\n'],
  ['a failure handled', 'fn main(): Int = handle fail(1) { fail(problem: Int) => 0 };', '0\n'],
  ['a lambda performing the handled effect', clock
    + 'fn f(c: Int -> Int with Clock): Int = 0; fn main(): Int = '
    + 'with handler Clock { now() => 1 } { f(fn(x) => now()) };', '0\n']
];

// Task 7, ruling F3: handler types and checked handlers run end to end.
export const checkedRuns = [
  ['a checked handler runs end to end', clock + 'fn main(): Int = '
    + 'with handler Clock { now() => 1 } { now() };', '1\n'],
  ['a checked failure runs end to end', 'fn main(): Int = '
    + 'handle fail(1) { fail(problem: Int) => 0 };', '0\n'],
  ['a handler type in a signature builds and runs',
    'fn f(h: Handler(Console with pure)): Int = 0;' + main, '0\n'],
  ['a handler type in a later constructor field builds and runs',
    'type H = H(Int, Handler(Console with pure));' + main, '0\n']
];
