# Task 8 context (controller; read after task-8-brief.md)

Branch claude/vibrant-cerf-3km61i in /home/user/waxwing (no worktree). Spec
docs/plans/2026-10-09-effects-design.md §3 (Evaluation order, Cleanup
context, Targeted aborts, Block exits, Cleanup failures, Defects, `crash`)
and §5's defect report are binding; read them in full. Plan Global
Constraints "Defect report" (in the brief) give the exact report lines.
Bumpus → Waxwing rename: `bumpus*` identifiers in plan text are `waxwing*`.

## What Tasks 2 and 7 left you
- Blocks: Checked/IR `Block (Array Item) Expr`, `Item = Let | Discard`;
  parse in src/Format/Parse/Block.purs, check in src/Features/Check/Block.purs,
  Go in src/Format/Go/Block.purs (lifted `waxwingFn{f}Block{k}` helpers).
- Task 7 runtime (src/Format/Go/Context.purs, emitted only in ctx mode):
  `waxwingCtx` immutable list, `waxwingInstall`, `waxwingFind`, non-zero-
  sized `waxwingMarker`, `waxwingAbort{target, payload}`, `waxwingFail[R]`,
  lifted `Handle{k}` helpers recovering only their own markers via
  `waxwingHandle`. Runtime keys: user effect = EffectId+1; Fail families
  -1 Int, -2 Bool, -3 Unit, -4-t declared type t. Missing handler is a plain
  Go `panic("no handler for <L>")` (ruling F7): your defect reporter must
  format it as the cause line `no handler for L`.
- Mode: ctx threads only when the emitted IR has an effect node; `defer`
  and `crash` must NOT force ctx (spec §4 "Uniform ctx": programs using
  `crash` or `defer` get the runtime pieces they need without `ctx`).
  Their runtime pieces (waxwingCleanup, waxwingDefect, main's recovery
  wrapper) are emitted only when used; all bootstrap/*.go stay
  byte-identical.

## Rulings binding Task 8 (ledger)
- F7 (above).
- F8 (superseded by the user 2026-10-09): `defer` must not fail. Spec §2
  `defer` rule and §3 "Cleanup failures" are revised — read them. A Fail
  label that the deferred expression performs and does not handle inside
  itself (deferred keys included) is E_EFFECT `defer must not fail, but it
  performs <L>` at the `defer` keyword's item span (state the exact span you
  chose in the report). Suggested approach: check the deferred expression
  under a fresh open row meta as its current row, settle, reject any Fail
  label in it, then consume that row into the current row. Only defects
  (crash, missing-handler guard, Go runtime panics) can fail cleanup; their
  causes are recorded after the pending cause as `cleanup failed: ` lines.
  The task brief was regenerated from the updated plan and already
  reflects this.
- F19: the brief's file list is compile-guided.
- `crash(value: a): b` is a built-in global (resolve like `print`),
  printable argument (reuse Check.Printable's rule and its E_TYPE text
  `Expected a printable value, found <t>`), no effect, uncatchable by
  `handle`. `<not printable>` for a non-printable Fail payload is decided
  statically from the payload type.

## Environment
- Build `node scripts/build.mjs`; focused `node --test test/x.test.mjs`;
  GOTOOLCHAIN=go1.26.4; gates test/style.test.mjs, test/structure.test.mjs,
  `purs-tidy check src tools/style/src`.
- Full `GOTOOLCHAIN=go1.26.4 npm run verify` once before committing
  (.build/fx001-task8-verify.log) AND `GOTOOLCHAIN=go1.26.4 node
  scripts/regression.mjs` (verify stops before it when the serial phase
  fails). Known environment timing failures (BACKLOG T007, identical on
  pre-change baselines): serial fn-linear-timing (up to 8), fn-scale
  5,000-parameter (2), fx-block.serial 20,000-let (at its 1,500 ms bound),
  occasionally large-source five-thousand-arm match (T004). Report them;
  never change a bound. Any other failure is yours.
- Commit with the brief's Step 5 message and trailers:
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01YZ4BVF4ByMDQWv2sZgis28
  Do not push; do not edit docs/.
