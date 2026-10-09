import assert from 'node:assert/strict';
import { cpSync, mkdirSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { fnRows } from './regression-fn.mjs';
// Each row restores one defect in its own isolated copy of the sources.
const rows = [
  {
    name: 'branch', file: 'src/Features/Check/Infer.purs',
    needle: 'branches.no\n  checked ← require env second.state'
      + ' (Checked.typeOf first.value)',
    replacement: 'branches.no\n  checked ← require env second.state'
      + ' (Checked.typeOf second.value)',
    probe: 'branch', message: /branch type mismatch was accepted/
  },
  {
    name: 'nil-guard', file: 'src/Format/Go/Match.purs',
    needle: 'nilGuard path = path <> " != nil"',
    replacement: 'nilGuard _ = "true"',
    probe: 'nil-guard', message: /nil guard missing/
  },
  {
    name: 'exhaustive', file: 'src/Features/Check/Coverage.purs',
    needle: 'uncovered signature',
    replacement: 'const (const (Right Nothing))',
    probe: 'exhaustive', message: /non-exhaustive match was accepted/
  },
  {
    name: 'ctor-order', file: 'src/Format/Go/Compare.purs',
    needle: 'if a.tag < b.tag { return -1 }',
    replacement: 'if a.tag > b.tag { return -1 }',
    probe: 'ctor-order', message: /constructor order wrong/
  },
  {
    name: 'first-field', file: 'src/Format/Go/Compare.purs',
    needle: '(Array.mapWithIndex field member.ctor.fields)',
    replacement:
      '(Array.reverse (Array.mapWithIndex field member.ctor.fields))',
    probe: 'first-field', message: /first differing field ignored/
  },
  {
    name: 'show-fields', file: 'src/Format/Go/Show.purs',
    needle: 'fields = Array.mapWithIndex (showField id) ctor.fields',
    replacement:
      'fields = Array.take 1 (Array.mapWithIndex (showField id) ctor.fields)',
    probe: 'show-fields', message: /printed value lost fields/
  },
  {
    name: 'state-thread', file: 'src/Format/Parse/Grammar.purs',
    needle: 'given ← argument applied.rest',
    replacement: 'given ← argument state',
    probe: 'state-thread', message: /parser state not threaded/
  },
  {
    // E005: an outer binder read only by an inner match's scrutinee must
    // still be captured by the match lifted around that inner match.
    name: 'capture', file: 'src/Format/Go/Match.purs',
    needle: 'free: union [ subject.free, signature.captured ]',
    replacement: 'free: signature.captured',
    probe: 'capture', message: /captured local lost/
  },
  {
    // P001: a meta must not bind to a type that properly contains it.
    name: 'occurs', file: 'src/Features/Check/Binding.purs',
    needle: 'if mentions meta resolved then',
    replacement: 'if false then',
    probe: 'occurs', message: /occurs check missing/
  },
  {
    // P001: a signature's variable is fixed inside its function.
    name: 'rigid', file: 'src/Features/Check/Unify.purs',
    needle: 'TVar (Rigid one), TVar (Rigid other) | one == other'
      + ' → Right subst',
    replacement: 'TVar (Rigid _), _ → Right subst\n'
      + '  _, TVar (Rigid _) → Right subst',
    probe: 'rigid', message: /rigid variable unified with Int/
  },
  {
    // P001: every use of a scheme gets fresh metas.
    name: 'instantiate', file: 'src/Features/Check/Scheme.purs',
    needle: ', state: state { next = state.next + Array.length variables }',
    replacement: ', state: state',
    probe: 'instantiate', message: /scheme metas shared across uses/
  },
  {
    name: 'nested-fail', file: 'src/Features/Check/Failure.purs',
    needle: 'Checked.Fail payload → maybe\'\n'
      + '    (unkeyedPayload payload expression.span)\n'
      + '    Just\n    (firstUnkeyed subst payload)',
    replacement: 'Checked.Fail payload → unkeyedPayload payload'
      + ' expression.span unit',
    probe: 'nested-fail', message: /nested Fail payload:/
  },
  {
    name: 'duplicate-binder', file: 'src/Features/Resolve/Handler.purs',
    needle: '  validateClauseParameters clauses\n', replacement: '',
    probe: 'duplicate-binder',
    message: /duplicate handler binder:/
  },
  {
    name: 'duplicate-row-tail', file: 'src/Format/Parse/Row.purs',
    needle: 'ordinary = gathered <$> validatedParts inner',
    replacement: 'ordinary = gathered <$> sepBy1 "+" (rowPart inner)',
    probe: 'duplicate-row-tail', message: /duplicate row tail:/
  },
  {
    name: 'constructor-function', file: 'src/Features/Resolve/TypeValidation.purs',
    needle: 'globalFlags = repeated (map globalName globals)',
    replacement: 'globalFlags = Array.replicate (Array.length globals) false',
    probe: 'constructor-function',
    message: /constructor and function collision: program was accepted/
  },
  {
    name: 'duplicate-scan-timing',
    file: 'src/Features/Resolve/TypeValidation.purs',
    needle: 'uniqueCtor { repeats, entry }\n'
      + '    | repeats = reportEarliest globals entry.name\n'
      + '    | otherwise = Right unit',
    replacement: 'uniqueCtor { repeats, entry } = when repeats\n'
      + '    (reportEarliest globals entry.name)',
    probe: 'duplicate-scan-timing',
    message: /large-source duplicate regression took/
  },
  {
    name: 'duplicate-effect', file: 'src/Features/Resolve/Effect.purs',
    needle: 'effectAt index = maybe (Right unit) duplicate\n'
      + '    (Array.index declarations index)',
    replacement: 'effectAt index = if index < 0 then maybe (Right unit)'
      + ' duplicate\n    (Array.index declarations index) else Right unit',
    probe: 'duplicate-effect', message: /duplicate effect: wrong diagnostic code/
  },
  {
    name: 'duplicate-operation', file: 'src/Features/Resolve/Effect.purs',
    needle: 'duplicateOperation declaration = Left\n'
      + '    ( Syntax.problemAt\n'
      + '        (Duplicate DuplicateOperation declaration.name)\n'
      + '        declaration.span\n    )',
    replacement: 'duplicateOperation _ = Right unit',
    probe: 'duplicate-operation',
    message: /duplicate operation: wrong diagnostic code/
  },
  {
    name: 'duplicate-effect-parameter',
    file: 'src/Features/Resolve/Effect.purs',
    needle: 'duplicateEffectParameter parameter = Left\n'
      + '    ( Syntax.problemAt\n'
      + '        (Duplicate DuplicateTypeParameter parameter.name)\n'
      + '        parameter.span\n    )',
    replacement: 'duplicateEffectParameter _ = Right unit',
    probe: 'duplicate-effect-parameter',
    message: /duplicate effect parameter: wrong diagnostic code/
  },
  {
    name: 'duplicate-operation-parameter',
    file: 'src/Features/Resolve/Effect.purs',
    needle: 'duplicateParameter parameter = Left\n'
      + '    ( Syntax.problemAt\n'
      + '        (Duplicate DuplicateParameter parameter.name)\n'
      + '        parameter.span\n    )',
    replacement: 'duplicateParameter _ = Right unit',
    probe: 'duplicate-operation-parameter',
    message: /duplicate operation parameter: wrong diagnostic code/
  },
  {
    name: 'deferred-fail-effect', file: 'src/Features/Check/Failure.purs',
    needle: '_ → failureAt env span failure',
    replacement: '_ → Left (problemAt (Internal'
      + ' "Failure row settlement failed") span)',
    probe: 'deferred-fail-effect',
    message: /deferred Fail capability: wrong diagnostic code/
  },
  {
    name: 'handler-metadata', file: 'src/Features/Check/Unlowered.purs',
    needle: 'ctorSpecial ctor = firstArray (map (typeAt ctor.span) ctor.fields)',
    replacement: 'ctorSpecial ctor = firstTypeAt (Array.head ctor.fields)'
      + ' ctor.span',
    probe: 'handler-metadata',
    message: /handler type in later constructor field:/
  },
  {
    // P001 (R15): a key's arguments are numbered output types (FN001 Task
    // 5: arrows too, Features.Specialize.Intern). Dropping which type an
    // argument is (keeping only that it is a data type) merges
    // List(List(Int)) and List(List(Bool)) into one Go type.
    name: 'spec-key', file: 'src/Features/Specialize/Keys.purs',
    needle: '      key = Tuple declaration arguments\n'
      + '      remembered state = maybe\' (newType',
    replacement: '      key = Tuple declaration (map outermost arguments)\n'
      + '      outermost = case _ of\n'
      + '        IR.TData _ → IR.TData (TypeId 0)\n'
      + '        ground → ground\n'
      + '      remembered state = maybe\' (newType',
    probe: 'spec-key', message: /nested specialization keys collided/
  }
];
// `node scripts/regression.mjs [name…]` proves only the named rows.
const chosen = process.argv.slice(2);
const proved = [...rows, ...fnRows]
  .filter(row => chosen.length === 0 || chosen.includes(row.name));
const base = '.build/regression';
const commandTimeoutMs = 180_000;
const run = (command, args) => spawnSync(command, args, { encoding: 'utf8', timeout: commandTimeoutMs });
rmSync(base, { recursive: true, force: true });
for (const row of proved) {
  const root = `${base}/${row.name}`;
  mkdirSync(root, { recursive: true });
  cpSync('src', `${root}/src`, { recursive: true });
  const file = `${root}/${row.file}`;
  const original = readFileSync(file, 'utf8');
  assert.equal(original.split(row.needle).length, 2, `${row.name}: mutation must have exactly one target`);
  writeFileSync(file, original.replace(row.needle, row.replacement));
  const built = run('purs', ['compile', `${root}/src/**/*.purs`, '.spago/p/*/src/**/*.purs', '--output', `${root}/output`]);
  assert.ifError(built.error);
  assert.equal(built.status, 0, built.stderr);
  const healthy = run('node', ['test/regression.mjs', 'output/Program.Compile/index.js', 'output', row.probe]);
  assert.ifError(healthy.error);
  assert.equal(healthy.status, 0, healthy.stderr);
  const broken = run('node', ['test/regression.mjs', `${root}/output/Program.Compile/index.js`, `${root}/output`, row.probe]);
  assert.ifError(broken.error);
  assert.equal(broken.status, 1, broken.stdout + broken.stderr);
  assert.match(broken.stderr, row.message);
  console.log(`Regression proof (${row.name}): fixed compiler passes; restored defect fails.`);
}
