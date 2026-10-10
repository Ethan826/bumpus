import test from 'node:test';
import assert from 'node:assert/strict';
import { cases, values } from './fx-console-programs.mjs';
import { runGo } from './support.mjs';

// Removing Console lowering or moving a stage past its next argument
// breaks these literal traces through the full compiler and Go runtime.
for (const [name, source, output] of [...cases, ...values]) {
  test(name, () => assert.equal(runGo(source), output));
}
