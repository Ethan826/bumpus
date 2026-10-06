import assert from 'node:assert/strict';
import { pathToFileURL } from 'node:url';
import { resolve } from 'node:path';
const { compile } = await import(pathToFileURL(resolve(process.argv[2])));
const { Left } = await import(pathToFileURL(resolve(process.argv[3], 'Data.Either/index.js')));
const result = compile('fn main(): Int = if true then 1 else false;');
assert.ok(result instanceof Left, 'branch type mismatch was accepted');
assert.equal(result.value0.code.constructor.name, 'TypeMismatch');
console.log('branch mismatch regression detects the defect');
