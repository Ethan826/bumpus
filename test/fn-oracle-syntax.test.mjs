import test from 'node:test';
import assert from 'node:assert/strict';
import { parseProgram } from './poly-parse.mjs';

// FN001 Task 3: the reference interpreter's own parser (independent of the
// compiler) reads function types, lambdas, application and pipes. It
// evaluates them from Task 7.
const local = name => ({ tag: 'local', name });
const value = number => ({ tag: 'value', value: number });

test('the oracle parser reads arrow types, lambdas and postfix application',
  () => {
    const program = parseProgram('type B(a) = B(a -> a) | C((a, Int) -> a);'
      + ' fn f(g: (Int -> Int) -> Int, x: Int): Int -> Int ='
      + ' (fn(y: Int -> Int, _) => g(y)(x))(1)(-2);'
      + ' fn main(): Int = 0;');
    assert.deepEqual([...program.ctors.keys()], ['B', 'C']);
    assert.deepEqual(program.functions.get('f'), {
      parameters: ['g', 'x'],
      body: {
        tag: 'applyValue',
        callee: {
          tag: 'applyValue',
          callee: {
            tag: 'lambda',
            parameters: ['y', null],
            body: {
              tag: 'applyValue',
              callee: { tag: 'apply', name: 'g', args: [local('y')] },
              args: [local('x')]
            }
          },
          args: [value(1)]
        },
        args: [value(-2)]
      }
    });
  });

test('the oracle parser reads |> left first, looser than comparison', () => {
  const program = parseProgram(
    'fn f(x: Int): Int = x < 1 |> g |> h(2) == x; fn main(): Int = 0;');
  assert.deepEqual(program.functions.get('f').body, {
    tag: 'pipe',
    left: {
      tag: 'pipe',
      left: { tag: 'compare', operator: '<', left: local('x'),
        right: value(1) },
      right: local('g')
    },
    right: { tag: 'compare', operator: '==',
      left: { tag: 'apply', name: 'h', args: [value(2)] }, right: local('x') }
  });
});
