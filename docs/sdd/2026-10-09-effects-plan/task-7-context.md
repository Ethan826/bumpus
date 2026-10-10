# Task 7 context (controller; read after task-7-brief.md)

Branch claude/vibrant-cerf-3km61i, work in /home/user/waxwing (no worktree).
Spec: docs/plans/2026-10-09-effects-design.md §3 (handler semantics) and §4
(lowering) are binding; read both in full. The project was renamed Bumpus →
Waxwing: every `bumpus*` Go identifier in plan text is `waxwing*` (spec uses
`waxwingCtx`, `waxwingAbort`, ...).

## What Task 6 left you (IR, src/Domain/IR/Internal.purs)
- `Ty`: `THandler EffectKey`; program `effects ∷ Array EffectInfo`
  ({ effect ∷ EffectRef, name, arguments, operations ∷ [{name, parameters,
  result, span}], span }), indexed by EffectKey.
- Nodes: `OperationRef EffectKey Int` (bare operation with parameters: a
  function value, lower like FunctionRef/staging), `Perform EffectKey Int
  (Array Expr)` (may be partial, like Call), `HandlerValue EffectKey (Array
  Clause)`, `Install Expr Expr` (with h { body }), `Handle Expr (Array
  FailClause)` (FailClause has `family ∷ TypeHead`, `payload ∷ Ty`, `local`,
  `body`), `Abort TypeHead Expr` (fail). `effectParts` lists their children.
- Features.Specialize.Unlowered (the post-specialization guard) — Task 7
  deletes it and its call in src/Program/Compile.purs.
- Placeholders to replace: Format.Go.Data `THandler → "*waxwingEff{N}"`;
  Format.Go.Expression wildcard arm `_ → leaf next (unlowered term.ty)`;
  Format.Go.Usage wildcard arms over effectParts. Replace wildcards with the
  six constructors listed explicitly (deferred Task 6 review minor).

## Rulings binding Task 7 (ledger)
- F1: runtime context key is the EffectId for user effects; `handle` frames
  key failures by (Fail, TypeHead) — the IR FailClause.family / Abort's
  TypeHead. Do NOT use Fail *layouts* (keyed by full payload) as runtime keys.
- F2: OperationRef is lowered as a function value and counts in usesContext.
- F3: Handler(Console) / Handler(Fail(E)) layouts (no operations) emit an
  empty handler struct type so programs mentioning them compile.
- F4: deleting the guard: every test asserting 'unlowered effect'
  (grep test/ for it: fx-handler-check, fx-signature, fx-specialize and
  test/regression.mjs 'handler-metadata' with its scripts/regression.mjs
  row) is replaced by a STRONGER assertion (the program now compiles and
  runs with exact stdout, or the specific remaining rejection) — never
  deleted without a replacement. Re-target the regression row to a real
  Task 7 defect (e.g. ctx emitted for effect-free programs) — ask if unsure.
- F7: a missing-handler guard panic is a plain Go panic with the text
  `no handler for <L>`; Task 8 will format it in the defect report.
- F19: the brief's file list is compile-guided; touch what the build needs.
- Every bootstrap/*.go stays byte-identical; Console-only programs emit no
  ctx (existing tests check this; keep them green).

## Runtime shapes
Task 1 measured and adopted the Go shapes; their hand-written Go is in
scripts/effect-runtime.mjs (with scripts/effect-semantics.mjs probes) —
reuse those shapes (context list, perform walk to the key calling the clause
with `outer`, non-zero-sized markers, abort struct, lifted handle helper
recovering only its own markers and returning (result, abort)). Defer/crash/
cleanup are Task 8: do not emit them now.

## Environment
- Build: `node scripts/build.mjs`. Focused tests: `node --test test/x.test.mjs`.
  Go: GOTOOLCHAIN=go1.26.4. Gates: test/style.test.mjs, test/structure.test.mjs,
  `purs-tidy check src tools/style/src`.
- Full `GOTOOLCHAIN=go1.26.4 npm run verify` once before committing, output
  to .build/fx001-task7-verify.log. Known environment failures (BACKLOG
  T007, identical on the pre-Task-6 baseline): serial fn-linear-timing (7)
  and fn-scale 5,000-parameter (2) bounds, occasionally large-source
  five-thousand-arm match (T004). Report them; never change a bound. Since
  verify stops at the first failing phase, also run
  `GOTOOLCHAIN=go1.26.4 node scripts/regression.mjs` and report its result.
- Commit per the brief's Step 5 message, with these trailer lines:
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01YZ4BVF4ByMDQWv2sZgis28
  Do not push. Do not edit docs/ (controller does).
