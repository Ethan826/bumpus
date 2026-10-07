import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import {
  checked, goTest, rejectedAt, runGo, traceCalls
} from './support.mjs';

const bool = body => `fn main(): Bool = ${body};`;

test('primitive comparisons run', () => {
  const rows = [
    ['1 < 2', 'true'], ['2 <= 2', 'true'], ['3 > 2', 'true'],
    ['2 >= 3', 'false'], ['1 == 1', 'true'], ['1 != 1', 'false'],
    ['false < true', 'true'], ['true < false', 'false'],
    ['true == true', 'true'], ['false >= true', 'false'],
    ['-2147483648 < 2147483647', 'true'],
    ['2147483647 + 1 < 0', 'true'],
    ['1 + 2 == 3', 'true'], ['(1 == 1) == true', 'true']
  ];
  for (const [body, expected] of rows) {
    assert.equal(runGo(bool(body)), `${expected}\n`, body);
  }
});

test('comparisons work in conditions, scrutinees and arguments', () => {
  assert.equal(runGo(
    'fn f(x: Int): Int = if x < 0 then 0 else x; fn main(): Int = f(-5);'
  ), '0\n');
  assert.equal(runGo(
    'fn main(): Int = match 1 < 2 { true => 1, false => 0 };'
  ), '1\n');
  assert.equal(runGo(
    'fn g(b: Bool): Int = if b then 7 else 8; fn main(): Int = g(2 > 1);'
  ), '7\n');
});

test('comparisons are rejected where malformed', () => {
  const chain = rejectedAt(bool('1 < 2 < 3'), 'E_SYNTAX', '<', 1);
  assert.equal(chain.message, 'Comparisons do not chain');
  const equal = rejectedAt(bool('1 == 2 == 3'), 'E_SYNTAX', '==', 1);
  assert.equal(equal.message, 'Comparisons do not chain');
  rejectedAt(bool('1 ! 2'), 'E_LEX', '!');
  rejectedAt(bool('1 == true'), 'E_TYPE', 'true');
  rejectedAt(bool('1 < if true then 1 else 2'), 'E_SYNTAX', 'if');
  rejectedAt('fn main(): Int = 1 < 2;', 'E_TYPE', '1 < 2');
});

const traced = (type, op, left, right) => {
  const source = `fn l(): ${type} = ${left}; fn r(): ${type} = ${right}; `
    + `fn main(): Bool = l() ${op} r();`;
  const result = goTest(source, `package main
import "testing"
import "fmt"
var sprigTrace []string
func TestTrace(t *testing.T) {
  sprigFn2()
  // The first entry is main itself; the rest are its operands in order.
  if got := fmt.Sprint(sprigTrace[1:]); got != "[0 1]" {
    t.Fatalf("trace %s", got)
  }
}
`, traceCalls);
  assert.equal(result.status, 0, result.output);
};

test('comparison operands evaluate once each, left first', () => {
  for (const op of ['<', '==']) {
    traced('Int', op, '1', '2');
    traced('Bool', op, 'false', 'true');
  }
});

test('Bool helper appears only when needed', () => {
  const helper = /func sprigCmpBool/g;
  assert.equal(checked(bool('false < true')).match(helper).length, 1);
  assert.equal(checked(bool('true == true')).match(helper), null);
  assert.equal(checked(bool('1 < 2')).match(helper), null);
});

test('existing bootstrap output is unchanged', () => {
  assert.equal(
    checked(readFileSync('examples/answer.sprig', 'utf8')),
    readFileSync('bootstrap/answer.go', 'utf8')
  );
});
