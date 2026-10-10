import test from 'node:test';
import assert from 'node:assert/strict';
import * as rows from '../output/Format.Diagnostic.Row/index.js';
import { clock, database, diagnose, expectDiagnostic, length, log,
  maxCharacters, state }
  from './fx-diagnostics-support.mjs';

const chain = depth => {
  const body = index => index === depth ? 'query()' : `f${index + 1}()`;
  const functions = Array.from({ length: depth }, (_, at) =>
    `fn f${at + 1}(): Int with Database = ${body(at + 1)};`);
  return database + 'fn main(): Int = f1(); ' + functions.join(' ');
};
const hop = index => [
  `fn f${index}(): Int with Database = f${index + 1}();`, `f${index + 1}()`,
  `through f${index}`];

test('a 30-deep call chain missing Database at main: path, origin, boundary', () => {
  const source = chain(30);
  expectDiagnostic(source, {
    code: 'E_EFFECT', message: 'Unhandled Database in main', at: ['f1()'],
    notes: [hop(1), hop(2),
      ['fn f3(): Int with Database = f4();', 'f4()', '… 25 more calls'],
      hop(28), hop(29),
      ['fn f30(): Int with Database = query();', 'query()',
        'Database is performed here'],
      ['fn main(): Int = f1();', 'fn main(): Int = f1();',
        'main may perform only Console']]
  });
});

test('a 3-deep call chain prints every hop, with no elision', () => {
  expectDiagnostic(chain(3), {
    code: 'E_EFFECT', message: 'Unhandled Database in main', at: ['f1()'],
    notes: [hop(1), hop(2),
      ['fn f3(): Int with Database = query();', 'query()',
        'Database is performed here'],
      ['fn main(): Int = f1();', 'fn main(): Int = f1();',
        'main may perform only Console']]
  });
});

test('a longer chain elides the middle hops and stays bounded', () => {
  const source = chain(300);
  const { diagnostic } = diagnose(source);
  assert.equal(diagnostic.related.length, 7);
  assert.equal(diagnostic.related[2].message, '… 295 more calls');
});

const wrapper = 'fn keep(f: Int -> Int with ...e): Int -> Int with ...e = f; '
  + 'fn once(f: Int -> Int with pure): Int = f(1); ';

test('an operation in a lambda passed through three higher-order functions '
  + 'into a with-pure parameter', () => {
  const callback = 'fn(x) => { log(x); x }';
  const source = log + wrapper
    + `fn main(): Int = once(keep(keep(keep(${callback}))));`;
  expectDiagnostic(source, {
    code: 'E_EFFECT', message: 'This function must be pure, but it performs Log',
    at: [`keep(keep(keep(${callback})))`],
    notes: [[callback, 'log(x)', 'Log is performed here'],
      ['fn once(f: Int -> Int with pure)', 'with pure',
        'this parameter must be pure']]
  });
});

const labelCount = 50;
const pair = 'type Pair(a, b) = Pair(a, b); ';
const effects = Array.from({ length: labelCount }, (_, at) =>
  `effect E${at + 1}(a) { fn op${at + 1}(): a; };`).join(' ');
const argument = 'Pair(Int, Bool)';
const written = count => Array.from({ length: count }, (_, at) =>
  `E${at + 1}(${argument})`);
const wideBoth = 'fn both(f: Int -> Int with '
  + `${written(labelCount - 1).join(' + ')} + ...r, g: Int -> Int with `
  + `${written(labelCount).join(' + ')} + ...r): Int = 0;`;
const wide = pair + effects + ` ${wideBoth} `
  + 'fn main(): Int = { let h = fn(x) => x; both(h, h) };';

test('a 50-label row missing one label names it and the shared tail, bounded', () => {
  const full = rows.unabbreviated(diagnose(wide).problem);
  assert.ok(full.length > maxCharacters,
    `unabbreviated is ${full.length} characters`);
  const lead = `E50(${argument})`;
  expectDiagnostic(wide, {
    code: 'E_EFFECT',
    message: `${lead} + ${written(3).join(' + ')} + … 46 more + ...r and `
      + `${written(4).join(' + ')} + … 45 more + ...r `
      + 'cannot be made equal: both end in ...r',
    at: ['both(h, h)', 'h', 6],
    notes: [[wideBoth, wideBoth, '...r is declared here']]
  });
});

const both = 'fn both(f: Int -> Int with Clock + ...r, '
  + 'g: Int -> Int with Log + ...r): Int = 0; ';

test('the side condition names both rows and the shared tail', () => {
  const source = log + clock + both
    + 'fn main(): Int = { let h = fn(x) => x; both(h, h) };';
  expectDiagnostic(source, {
    code: 'E_EFFECT',
    message: 'Log + ...r and Clock + ...r cannot be made equal: both end in ...r',
    at: ['both(h, h)', 'h', 6],
    notes: [[both.trim(), both.trim(), '...r is declared here']]
  });
});

const handlers = 'get() => 1, put(v) => ()';
const boolHandlers = 'get() => true, put(v) => ()';

test('a same-key payload mismatch notes the innermost handler installation', () => {
  const inner = `with handler State(Bool) { ${boolHandlers} } { useInt() }`;
  const source = state + 'fn useInt(): Int with State(Int) = get(); '
    + `fn main(): Int = with handler State(Int) { ${handlers} } { ${inner} };`;
  expectDiagnostic(source, {
    code: 'E_TYPE', message: 'Expected State(Bool), found State(Int)',
    at: [inner, 'useInt()'],
    notes: [[inner, inner, 'the innermost State(Bool) is here']]
  });
});

test('a same-key payload mismatch notes the innermost signature entry', () => {
  const bad = 'fn bad(): Int with State(Bool) = useInt();';
  const source = state + 'fn useInt(): Int with State(Int) = get(); '
    + bad + ' fn main(): Int = 0;';
  expectDiagnostic(source, {
    code: 'E_TYPE', message: 'Expected State(Bool), found State(Int)',
    at: [bad, 'useInt()'],
    notes: [[bad, bad, 'the innermost State(Bool) is here']]
  });
});

test('a large payload mismatch elides the subterms off the differing path', () => {
  const nest = 'type Pair(a, b) = Pair(a, b); type List(a) = Nil | Cons(a, List(a)); ';
  const bad = 'fn bad(): Pair(Pair(Int, Bool), List(Int)) '
    + 'with State(Pair(Pair(Int, Bool), List(Bool))) '
    + '= useInt();';
  const source = nest + state + 'fn useInt(): Pair(Pair(Int, Bool), List(Int)) with '
    + 'State(Pair(Pair(Int, Bool), List(Int))) = get(); ' + bad
    + ' fn main(): Int = 0;';
  const { diagnostic } = diagnose(source);
  assert.equal(diagnostic.message,
    'Expected State(Pair(…, List(Bool))), found State(Pair(…, List(Int)))');
});

const longType = `T${'x'.repeat(2500)}`;
const longEffect = `type ${longType} = ${longType}; effect E(a) { fn op(): a; }; `;

test('a label with a 2,500-character argument keeps the whole diagnostic bounded', () => {
  const raise = `fn raise(): Int with E(${longType}) = { op(); 1 }; `;
  const { diagnostic } = diagnose(longEffect + raise
    + 'fn main(): Int = raise();');
  assert.equal(diagnostic.message, 'Unhandled E(…) in main');
  assert.ok(length(diagnostic) <= maxCharacters, `${length(diagnostic)}`);
});

test('long labels in a row conflict still name the label and the shared tail', () => {
  const source = longEffect + log + 'fn both(f: Int -> Int with '
    + `E(${longType}) + ...r, g: Int -> Int with Log + ...r): Int = 0; `
    + 'fn main(): Int = { let h = fn(x) => x; both(h, h) };';
  const { diagnostic } = diagnose(source);
  assert.equal(diagnostic.message, 'Log + ...r and E(…) + ...r '
    + 'cannot be made equal: both end in ...r');
  assert.ok(length(diagnostic) <= maxCharacters, `${length(diagnostic)}`);
});

test('a closed written row that lacks a label names its with, not an ambient row', () => {
  const stamp = 'fn stamp(): Int with Log = tick(); ';
  expectDiagnostic(log + clock + 'fn tick(): Int with Clock = now(); ' + stamp
    + 'fn main(): Int = 0;', {
    code: 'E_EFFECT',
    message: 'stamp performs Clock, which its signature does not allow',
    at: [stamp.trim(), 'tick()'],
    notes: [['fn tick(): Int with Clock = now();', 'now()',
      'Clock is performed here'],
    [stamp.trim(), 'with Log', 'the signature of stamp does not allow Clock']]
  });
});

// The guarantee is structural (Format.Diagnostic `noted` renders notes for
// effect and label problems only); these sources sample the other kinds.
test('diagnostics outside the effect system carry no notes', () => {
  for (const source of [
    'fn main(): Int = true;',
    'fn main(): Int = missing;',
    'fn main(): Int = f(1); fn f(): Int = 0;',
    'fn main(): Int = 1 + ;',
    'fn main(): Int = match 1 { 1 => 0 };',
    'fn main(): Unit = ();  fn main(): Unit = ();',
    'type L = Nil | Cons(Int, L); fn main(): Int = Cons(1);',
    'fn main(): Int = { print(fn(x) => x); 0 };',
    'fn main(): Int = 5 5;'
  ]) {
    const { diagnostic } = diagnose(source);
    assert.deepEqual(diagnostic.related, [], source);
  }
});
