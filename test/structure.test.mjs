import test from 'node:test';
import assert from 'node:assert/strict';
import { graphFindings, textFindings } from '../scripts/structure.mjs';

test('layer gate rejects effects, reverse dependencies, and unchecked IR access', () => {
  for (const [name, dependency] of [
    ['Domain.Syntax', 'Effect'], ['Format.Parse', 'Program.Main'],
    ['Features.Resolve', 'Domain.IR.Internal'], ['Format.Lex', 'Unsafe.Coerce'],
    ['Domain.Syntax', 'Format.Go'], ['Format.Lex', 'Data.String.Unsafe'],
    ['Features.Resolve', 'Format.Parse'], ['Runtime.Node', 'Program.Main'],
    ['Program.Command', 'Effect'], ['Program.Command', 'Runtime.Node']
  ]) assert.equal(graphFindings({ [name]: { path: 'src/example.purs', depends: [dependency] } }).length, 1);
  assert.deepEqual(graphFindings({ 'Features.Check': { path: 'src/check.purs', depends: ['Domain.Syntax', 'Domain.IR.Internal', 'Data.Array'] } }), []);
  assert.deepEqual(graphFindings({ 'Program.Main': { path: 'src/main.purs', depends: ['Effect'] } }), []);
  assert.equal(graphFindings({ 'Unknown': { path: 'src/unknown.purs', depends: [] } }).length, 1);
  assert.equal(graphFindings({ 'Bumpus.Old': { path: 'src/Bumpus/Old.purs', depends: [] } }).length, 1);
});

test('length gate counts blank lines and includes tooling and tests', () => {
  assert.deepEqual(textFindings('test/x.mjs', '\n'.repeat(250)), []);
  assert.equal(textFindings('scripts/x.mjs', '\n'.repeat(251)).length, 1);
});

test('escape gate rejects partiality and test suppression', () => {
  assert.equal(textFindings('src/Bumpus/Foo.purs', 'unsafePartial\n').length, 1);
  assert.equal(textFindings('test/x.mjs', 'test.' + 'skip("x")\n').length, 1);
});

test('pure layers may loop with tailRecM and nothing else from Control', () => {
  const pure = dependency => graphFindings(
    { 'Format.Lex': { path: 'src/Format/Lex.purs', depends: [dependency] } });
  assert.deepEqual(pure('Control.Monad.Rec.Class'), []);
  for (const dependency of ['Control.Monad.ST', 'Control.Monad.Rec',
    'Control.Monad.Rec.ClassX', 'Control.Monad']) {
    assert.equal(pure(dependency).length, 1, dependency);
  }
});
