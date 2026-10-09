import test from 'node:test';
import assert from 'node:assert/strict';
import { check } from '../output/Style.Check/index.js';
const moduleSource = body => `module Fixture where\nimport Prelude\nimport Data.Maybe (Maybe(..))\n${body}\n`;

test('CST style gate rejects let-in, lambdas, Maybe routing, and branch blocks', () => {
  for (const [body, message] of [
    ['f x = let y = x in y', 'use where'],
    ['f = map (\\x -> x)', 'name transformations'],
    ['f x = case x of\n  Nothing -> 0\n  Just value -> value', 'use maybe/either'],
    ['f x = if x then do\n  pure unit\nelse pure unit', 'move branch work']
  ]) assert.ok(check(moduleSource(body)).some(finding => finding.includes(message)), body);
});

test('comments and strings cannot hide code or trigger style errors', () => {
  assert.deepEqual(check(moduleSource('f = "case x of Just y -> let z = y in z"\n-- let x = 1 in x')), []);
  assert.ok(check(moduleSource('f x = case x of\n  Just\n    value -> value\n  Nothing -> 0')).length > 0);
  assert.ok(check('this is not a PureScript module').length > 0);
});

test('named where helpers and lazy Maybe fallback are accepted', () => {
  assert.deepEqual(check(moduleSource('f x = maybe 0 found x\n  where\n  found value = value')), []);
});

// G001: parser productions are applicative. Only Format.Parse.Grammar (the
// Parser instances) and Format.Parse.Cursor thread the state monadically.
const inModule = (name, body) => `module ${name} where\nimport Prelude\n${body}\n`;
const doBlock = 'f x = do\n  y <- x\n  pure y';

test('parser productions reject do blocks and bind operators', () => {
  for (const name of ['Format.Parse', 'Format.Parse.Literal', 'Format.Parse.Pattern',
    'Format.Parse.Expression', 'Format.Parse.Declaration', 'Format.Parse.Type',
    'Format.Parse.Lambda', 'Format.Parse.Block']) {
    for (const body of [doBlock, 'f x = x >>= g', 'f x = g =<< x', 'f = (>>=)']) {
      assert.ok(check(inModule(name, body)).some(finding => finding.includes('applicative')), `${name}: ${body}`);
    }
  }
});

test('the grammar core, cursor and other modules may sequence monadically', () => {
  for (const name of ['Format.Parse.Grammar', 'Format.Parse.Cursor', 'Format.Lex', 'Format.Parse.Expressions']) {
    for (const body of [doBlock, 'f x = x >>= g']) assert.deepEqual(check(inModule(name, body)), [], `${name}: ${body}`);
  }
  assert.deepEqual(check(inModule('Format.Parse.Expression', 'f = g <$> x <*> y <* z')), []);
});

const parserModules = ['Format.Parse', 'Format.Parse.Literal', 'Format.Parse.Pattern',
  'Format.Parse.Expression', 'Format.Parse.Declaration', 'Format.Parse.Type',
  'Format.Parse.Lambda', 'Format.Parse.Block'];

// Prelude's Monad helpers and Control.Bind's names sequence through Bind too
// (G001 final review M1).
const monadicNames = ['ap', 'ifM', 'whenM', 'unlessM', 'liftM1', 'bindFlipped',
  'composeKleisli', 'composeKleisliFlipped'];

test('parser productions reach Bind by no other name', () => {
  for (const name of parserModules) {
    for (const body of ['f x = bind x g', 'f x = x `bind` g', 'f x = Prelude.bind x g',
      'f = g >=> h', 'f = g <=< h', 'f = (>=>)', 'f x = join x', 'f x = discard x g',
      ...monadicNames.map(text => `f = ${text}`)]) {
      assert.ok(check(inModule(name, body)).some(finding => finding.includes('applicative')), `${name}: ${body}`);
    }
  }
});

// Running a parser from a state is the one way to sequence on its result,
// so only the parser entry point (and Grammar, which defines it) may.
const runFinding = 'only Format.Parse runs a parser';
const importing = (name, line) => inModule(name, `${line}\nf = 1`);

test('only Format.Parse imports run or initialState', () => {
  for (const name of ['Format.Parse.Expression', 'Format.Parse.Declaration', 'Program.Compile']) {
    for (const line of ['import Format.Parse.Grammar (run)',
      'import Format.Parse.Grammar (Parser, initialState)', 'import Format.Parse.Cursor (initialState)',
      'import Format.Parse.Grammar', 'import Format.Parse.Grammar as Grammar',
      'import Format.Parse.Grammar hiding (token)', 'import Format.Parse.Cursor']) {
      assert.ok(check(importing(name, line)).some(finding => finding.includes(runFinding)), `${name}: ${line}`);
    }
  }
});

test('the parser entry point and Grammar may import the runner', () => {
  assert.deepEqual(check(importing('Format.Parse', 'import Format.Parse.Grammar (Parser, initialState, run)')), []);
  assert.deepEqual(check(importing('Format.Parse.Grammar', 'import Format.Parse.Cursor (Run, initialState)')), []);
  assert.deepEqual(check(importing('Format.Parse.Expression', 'import Format.Parse.Grammar (Parser, token)')), []);
  assert.deepEqual(check(importing('Format.Lex', 'import Data.Array (run)')), []);
});
