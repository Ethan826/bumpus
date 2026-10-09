import test from 'node:test';
import assert from 'node:assert/strict';
import { Left, Right } from '../output/Data.Either/index.js';
import { parse } from '../output/Format.Parse/index.js';
import { resolve } from '../output/Features.Resolve/index.js';
import { check } from '../output/Features.Check/index.js';
import { wire } from '../output/Format.Diagnostic/index.js';
import { compile } from '../output/Program.Compile/index.js';

const phase = source => {
  const parsed = parse(source);
  if (parsed instanceof Left) return parsed;
  const resolved = resolve(parsed.value0);
  return resolved instanceof Left ? resolved : check(resolved.value0);
};
const accepted = source => assert.ok(phase(source) instanceof Right,
  JSON.stringify(phase(source)));
const rejected = (source, code, message) => {
  const result = phase(source);
  assert.ok(result instanceof Left, source);
  const diagnostic = wire(result.value0);
  assert.equal(diagnostic.code, code);
  assert.equal(diagnostic.message, message);
  assert.deepEqual(diagnostic.related, []);
};

const clock = 'effect Clock { fn now(): Int; }; ';
const log = 'effect Log { fn log(x: Int): Unit; }; ';
const acceptedCases = [
  ['declared operation', clock + 'fn main(): Int with Clock = now();', false],
  ['ambient callback', 'fn map(f: Int -> Int, x: Int): Int = f(x); '
    + 'fn main(): Int with Console = map(fn(x) => { print(x); x }, 3);'],
  ['eta opens a pure local', log + 'fn use(f: Int -> Int with Log): Int with Log = f(1); '
    + 'fn adapt(g: Int -> Int with pure): Int with Log = use(fn(x) => g(x)); '
    + 'fn main(): Int = 0;'],
  ['named rows share', 'fn use(f: Int -> Int with ...e): Int with ...e = f(1); '
    + 'fn main(): Int with Console = use(fn(x) => { print(x); x });'],
  ['partial leaves body latent', clock + 'fn take(x: Int, y: Int): Int with Clock = now(); '
    + 'fn main(): Unit = { let f = take(1); (); };']
];
for (const [name, source, valid = true] of acceptedCases) {
  test(name, () => valid ? accepted(source)
    : rejected(source, 'E_EFFECT', 'Unhandled Clock in main'));
}
const rejectedCases = [
  ['rigid ambient cannot invent effects', clock + 'fn f(): Int = now(); fn main(): Int = 0;',
    'E_EFFECT', 'f performs Clock, which its signature does not allow'],
  ['pure callback', 'fn use(f: Int -> Int with pure): Int = f(1); '
    + 'fn main(): Int with Console = use(fn(x) => { print(x); x });',
    'E_EFFECT', 'This function must be pure, but it performs Console'],
  ['closed local cannot widen', log + 'fn use(f: Int -> Int with Log): Int with Log = f(1); '
    + 'fn adapt(g: Int -> Int with pure): Int with Log = use(g); fn main(): Int = 0;',
    'E_EFFECT', 'This function must be pure, but it performs Log'],
  ['type then row sort', 'fn f(x: e): Int with ...e = 0; fn main(): Int = 0;',
    'E_TYPE', 'Expected an effect row, found a type'],
  ['row then type sort', 'fn f(g: Int -> Int with ...e, x: e): Int = 0; fn main(): Int = 0;',
    'E_TYPE', 'Expected a type, found an effect row'],
  ['bare nullary operation', clock + 'fn main(): Int with Clock = now;',
    'E_ARITY', 'Expected now()'],
  ['print function', 'fn main(): Unit with Console = print(fn(x) => x);',
    'E_TYPE', 'Expected a printable value, found _ -> _']
];
for (const [name, source, code, message] of rejectedCases) {
  test(name, () => rejected(source, code, message));
}
test('user effects stop at the explicit pre-specialization guard', () => {
  const result = compile(clock + 'fn main(): Int = 1;');
  assert.ok(result instanceof Left);
  assert.equal(wire(result.value0).message, 'unlowered effect');
});

test('row variables erase from instantiations even before type variables', () => {
  const result = phase('fn choose(f: Int -> Int with ...e, x: a): a with ...e = '
    + '{ f(0); x }; fn main(): Int with Console = '
    + 'choose(fn(x) => { print(x); x }, 42);');
  assert.ok(result instanceof Right, JSON.stringify(result));
  const arguments_ = result.value0.functions[1].body.value0.node.value1;
  assert.equal(arguments_.length, 1);
  assert.equal(arguments_[0].constructor.name, 'TInt');
});
test('field and operation arrows can explicitly name declared effects', () => {
  accepted(clock + 'type Job = Job(Int -> Int with Clock); '
    + 'effect Relay { fn relay(f: Int -> Int with Clock): Int; }; '
    + 'fn main(): Int = 0;');
});

test('20,000 written arrows resolve without recursive row collection', () => {
  const source = `fn f(g: ${Array(20001).fill('Int').join(' -> ')})`
    + ': Int = 0; fn main(): Int = 0;';
  const result = resolve(parse(source).value0);
  assert.ok(result instanceof Right);
  assert.equal(result.value0.functions.length, 2);
});
