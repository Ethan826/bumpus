import test from 'node:test';
import assert from 'node:assert/strict';
import { graphFindings, textFindings } from '../scripts/structure.mjs';

test('layer gate rejects effects, reverse dependencies, and unchecked IR access', () => {
  for (const [name, dependency] of [
    ['Sprig.Model', 'Effect'], ['Sprig.Parse', 'Shell.CLI'],
    ['Sprig.Resolve', 'Sprig.IR.Internal'], ['Sprig.Lex', 'Unsafe.Coerce'],
    ['Sprig.Model', 'Sprig.Go'], ['Sprig.Lex', 'Data.String.Unsafe']
  ]) assert.equal(graphFindings({ [name]: { path: 'src/example.purs', depends: [dependency] } }).length, 1);
  assert.deepEqual(graphFindings({ 'Sprig.Check': { path: 'src/check.purs', depends: ['Sprig.Model', 'Sprig.IR.Internal', 'Data.Array'] } }), []);
  assert.equal(graphFindings({ 'Unknown': { path: 'src/unknown.purs', depends: [] } }).length, 1);
});

test('length gate counts blank lines and includes tooling and tests', () => {
  assert.deepEqual(textFindings('test/x.mjs', '\n'.repeat(250)), []);
  assert.equal(textFindings('scripts/x.mjs', '\n'.repeat(251)).length, 1);
});

test('escape gate rejects partiality and test suppression', () => {
  assert.equal(textFindings('src/Sprig/Foo.purs', 'unsafePartial\n').length, 1);
  assert.equal(textFindings('test/x.mjs', 'test.' + 'skip("x")\n').length, 1);
});
