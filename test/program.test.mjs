import test from 'node:test';
import assert from 'node:assert/strict';
import { command } from '../output/Program.Command/index.js';
import { monadEffect } from '../output/Effect/index.js';
import { Left, Right } from '../output/Data.Either/index.js';
import { Just, Nothing } from '../output/Data.Maybe/index.js';
import { IoFailure, ToolFailure } from '../output/Domain.Host/index.js';
import { wireText } from '../output/Runtime.Node/index.js';
import { checked, rejected } from './support.mjs';

const answer = 'fn main(): Int = 42;';
const mistyped = 'fn main(): Int = true + 1;';

// A fake host records every port call and answers from a script of results.
const fakeHost = (results = {}) => {
  const calls = [];
  const port = (name, arity) => {
    const answer = results[name] ?? new Right(name === 'runProgram' ? '' : {});
    const record = args => () => { calls.push([name, ...args]); return answer; };
    return arity === 1 ? a => record([a]) : a => b => record([a, b]);
  };
  const host = {
    readSource: port('readSource', 1), writeText: port('writeText', 2),
    buildExecutable: port('buildExecutable', 2), runProgram: port('runProgram', 1)
  };
  return { host, calls };
};

const execute = (host, args) => {
  const outcome = command(monadEffect)(host)(args)();
  const stderr = outcome.stderr instanceof Just
    ? JSON.parse(wireText(outcome.stderr.value0)) : null;
  if (stderr === null) assert.ok(outcome.stderr instanceof Nothing);
  return { status: outcome.status, stdout: outcome.stdout, stderr };
};

const keysOf = value => Object.keys(value);

test('bad arguments are E_USAGE with status 2 and touch no port', () => {
  for (const args of [[], ['emit', 'a.sprig'], ['run', 'a', 'b'],
    ['build', '', 'out'], ['fly', 'a.sprig'], ['run', 'a', 'b', 'c']]) {
    const { host, calls } = fakeHost();
    const outcome = execute(host, args);
    assert.deepEqual(outcome, { status: 2, stdout: '', stderr: {
      code: 'E_USAGE',
      message: 'sprig emit|build INPUT OUTPUT; sprig run INPUT' } });
    assert.deepEqual(calls, []);
  }
});

test('an empty run destination is accepted as the original CLI did', () => {
  const { host } = fakeHost({ readSource: new Right(answer) });
  assert.equal(execute(host, ['run', 'a.sprig', '']).status, 0);
});

test('a failed read is E_IO with status 1 and calls nothing else', () => {
  const { host, calls } = fakeHost({
    readSource: new Left(IoFailure.create('ENOENT: missing')) });
  const outcome = execute(host, ['emit', 'in.sprig', 'out.go']);
  assert.deepEqual(outcome, { status: 1, stdout: '',
    stderr: { code: 'E_IO', message: 'ENOENT: missing' } });
  assert.deepEqual(calls, [['readSource', 'in.sprig']]);
});

test('a source diagnostic is status 1 with the wire fields and file', () => {
  const { host, calls } = fakeHost({ readSource: new Right(mistyped) });
  const outcome = execute(host, ['build', 'bad.sprig', 'program']);
  const expected = { ...rejected(mistyped, 'E_TYPE'), file: 'bad.sprig' };
  assert.deepEqual(outcome, { status: 1, stdout: '', stderr: expected });
  assert.deepEqual(keysOf(outcome.stderr), ['code', 'message', 'span', 'file']);
  assert.deepEqual(calls, [['readSource', 'bad.sprig']]);
});

test('emit writes exactly the checked Go text at the destination', () => {
  const { host, calls } = fakeHost({ readSource: new Right(answer) });
  const outcome = execute(host, ['emit', 'answer.sprig', 'answer.go']);
  assert.deepEqual(outcome, { status: 0, stdout: '', stderr: null });
  assert.deepEqual(calls, [['readSource', 'answer.sprig'],
    ['writeText', 'answer.go', checked(answer)]]);
});

test('a write failure during emit is E_IO with status 1', () => {
  const { host } = fakeHost({ readSource: new Right(answer),
    writeText: new Left(IoFailure.create('EACCES: denied')) });
  assert.deepEqual(execute(host, ['emit', 'a.sprig', 'a.go']), { status: 1,
    stdout: '', stderr: { code: 'E_IO', message: 'EACCES: denied' } });
});

test('a build tool failure is E_TOOL with ok false and the command', () => {
  const failure = new ToolFailure({ message: 'spawnSync go ENOENT', command: 'go' });
  const { host, calls } = fakeHost({ readSource: new Right(answer),
    buildExecutable: new Left(failure) });
  const outcome = execute(host, ['build', 'answer.sprig', 'answer']);
  assert.deepEqual(outcome, { status: 1, stdout: '', stderr: { ok: false,
    code: 'E_TOOL', message: 'spawnSync go ENOENT', command: 'go' } });
  assert.deepEqual(keysOf(outcome.stderr), ['ok', 'code', 'message', 'command']);
  assert.deepEqual(calls, [['readSource', 'answer.sprig'],
    ['buildExecutable', checked(answer), 'answer']]);
});

test('run prints the program output and never writes text', () => {
  const { host, calls } = fakeHost({ readSource: new Right(answer),
    runProgram: new Right('42\n') });
  const outcome = execute(host, ['run', 'answer.sprig']);
  assert.deepEqual(outcome, { status: 0, stdout: '42\n', stderr: null });
  assert.deepEqual(calls, [['readSource', 'answer.sprig'],
    ['runProgram', checked(answer)]]);
});

test('a run tool failure is E_TOOL with status 1 and no stdout', () => {
  const failure = new ToolFailure({ message: 'exit 2', command: '/tmp/program' });
  const { host } = fakeHost({ readSource: new Right(answer),
    runProgram: new Left(failure) });
  assert.deepEqual(execute(host, ['run', 'answer.sprig']), { status: 1,
    stdout: '', stderr: { ok: false, code: 'E_TOOL', message: 'exit 2',
      command: '/tmp/program' } });
});
