import test from 'node:test';
import assert from 'node:assert/strict';
import { graphFindings, textFindings } from '../scripts/structure.mjs';

test('layer gate rejects effects, reverse dependencies, and unchecked IR access', () => {
  for (const [name, dependency] of [
    ['Domain.Syntax', 'Effect'], ['Format.Parse', 'Program.Main'],
    ['Features.Resolve', 'Domain.IR.Internal'], ['Format.Lex', 'Unsafe.Coerce'],
    ['Domain.Syntax', 'Format.Go'], ['Format.Lex', 'Data.String.Unsafe'],
    ['Features.Resolve', 'Format.Parse'], ['Runtime.Node', 'Program.Main']
  ]) assert.equal(graphFindings({ [name]: { path: 'src/example.purs', depends: [dependency] } }).length, 1);
  assert.deepEqual(graphFindings({ 'Features.Check': { path: 'src/check.purs', depends: ['Domain.Syntax', 'Domain.IR.Internal', 'Data.Array'] } }), []);
  assert.deepEqual(graphFindings({ 'Program.Main': { path: 'src/main.purs', depends: ['Effect'] } }), []);
  assert.equal(graphFindings({ 'Unknown': { path: 'src/unknown.purs', depends: [] } }).length, 1);
  assert.equal(graphFindings({ 'Sprig.Old': { path: 'src/Sprig/Old.purs', depends: [] } }).length, 1);
});

test('length gate counts blank lines and includes tooling and tests', () => {
  assert.deepEqual(textFindings('test/x.mjs', '\n'.repeat(250)), []);
  assert.equal(textFindings('scripts/x.mjs', '\n'.repeat(251)).length, 1);
});

test('escape gate rejects partiality and test suppression', () => {
  assert.equal(textFindings('src/Sprig/Foo.purs', 'unsafePartial\n').length, 1);
  assert.equal(textFindings('test/x.mjs', 'test.' + 'skip("x")\n').length, 1);
});
