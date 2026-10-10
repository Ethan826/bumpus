# Task 9 context (controller; read after task-9-brief.md)

Branch claude/vibrant-cerf-3km61i in /home/user/waxwing (no worktree).
Spec (binding): docs/plans/2026-10-09-effects-design.md §6 "Diagnostic
quality" in full, §5 "Row display", and §2's revised `defer` rule. The
brief already carries the 2026-10-09 amendments (rulings R3, R4: occurrence
links in Subst on every unification path; deferred-row origins kept apart
from the function row; the exact note texts and the wire's
`related: [{ span, message }]`). If the brief and the spec disagree, the
brief's amended text wins for exact texts; the spec wins for semantics —
report any conflict.

## What earlier tasks left you
- Task 3: `UnifyRow.unifyRows` reports `RowEvent`s (`Matched`, `Extended`)
  with `OccurrenceId = Written Span Int | Extended Int`; UnifyRow.purs is at
  249 lines — do not grow it (put hooks in new modules per the brief).
- Task 4: Domain.Syntax `Diagnostic` has `related ∷ Array Note`
  (`NoteReason = RequiredBy String`, unused); every existing diagnostic has
  `related: []` and must keep its text and span unchanged.
- Task 5: deferred Fail keys settle after body constraints
  (Features.Check.Failure.settleKeys, retried in Unify.purs).
- Task 8: Features.Check.Defer checks the deferred expression with its own
  row; Check.purs runs settleKeys → settleDeferred → settleKeys; problems
  DeferMayFail / DeferMayPerform.
- Pre-flight rulings: F9 (labels print capitalized, `Unhandled Fail(DbError)
  in main`), F10 ("(required by …)" becomes a note), F13 (origin hooks in a
  new module, not UnifyRow).
- Scale constraints: rows walked by loops; nothing grows per call during
  checking (spec §6); 20,000-arrow/let workloads in existing tests must stay
  within their bounds.

## Environment
- Build `node scripts/build.mjs`; focused `node --test test/x.test.mjs`;
  GOTOOLCHAIN=go1.26.4; gates test/style.test.mjs, test/structure.test.mjs,
  `purs-tidy check src tools/style/src`.
- Before committing: full `GOTOOLCHAIN=go1.26.4 npm run verify`
  (.build/fx001-task9-verify.log) and `GOTOOLCHAIN=go1.26.4 node
  scripts/regression.mjs` (.build/fx001-task9-regression.log). Ruling R1:
  passes when the only failures are the BACKLOG T007 serial timing set
  (fn-linear-timing up to 8, fn-scale 5,000-parameter 2, fx-block 20,000-let
  at its bound, occasionally large-source T004) and regression exits 0.
  Never change a bound.
- Commit with the brief's message and trailers:
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01YZ4BVF4ByMDQWv2sZgis28
  Do not push; do not edit docs/.
