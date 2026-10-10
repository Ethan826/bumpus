# Task 10 context (controller; read after task-10-brief.md)

Branch claude/vibrant-cerf-3km61i in /home/user/waxwing (no worktree).
FX001 Tasks 1-9 are complete. Task 10 adds NO compiler (PureScript) code:
it is a test-side reference interpreter, program generator, shrinker and a
differential corpus. Spec (binding for semantics):
docs/plans/2026-10-09-effects-design.md (§2 evaluation/defer rule, §3
cleanup/defect semantics, §5 defect report and row display). ADR 005 gives
payload printing. If the brief and the spec disagree, the brief's exact
texts win; the spec wins on semantics; report any conflict.

## What earlier tasks left you
- Executable probes to validate against (import, never copy):
  test/fx-block-programs.mjs (`runs`), test/fx-console.test.mjs (Console
  probes; move inline cases into an importable module if needed),
  test/fx-run-programs.mjs (`cases`), and Task 8's run cases inline in
  test/fx-cleanup.test.mjs (248 lines) — move them unchanged to
  test/fx-cleanup-programs.mjs and import them back.
- test/poly-parse.mjs (226 lines) is an independent parser of the
  pre-effects language; extend it by import only, never edit it.
- Existing helpers for building many generated programs in one Go
  invocation: grep "go-batch" in test/ (e.g. test/poly-properties.test.mjs,
  test/adt-properties.test.mjs) and follow their pattern; serial files are
  test/*.serial.test.mjs (run in verify's serial phase).
- Strict defer (adopted 2026-10-09): `defer must not fail, but it performs
  <L>` / `defer must not fail, but it may perform any effect of <r>`
  (E_EFFECT, defer span). Relaxation is FX007 — generated defers must obey
  the strict rule as the brief describes.
- Runtime key scheme (Task 7): user effects keyed by effect identity
  regardless of type arguments; Fail keyed by the payload's declared type
  head; clauses of one `handle` are frames with the FIRST clause innermost.

## Rules (AGENTS.md applies to test/ tooling too)
- 250 physical lines maximum per file (about 100 target); split modules.
  test/style.test.mjs and test/structure.test.mjs gate this.
- Test-side JS must not import compiler output (output/ or src/).
- Never weaken an assertion, raise a bound or skip a test.
- Each new behavioural test seen failing first where meaningful; for the
  sensitivity check, the flag itself is the failing witness.

## Environment
- Build `node scripts/build.mjs` (already built; rebuild only if needed).
  Focused tests `node --test test/x.test.mjs`. GOTOOLCHAIN=go1.26.4 always.
- Before committing: `rm -rf output && GOTOOLCHAIN=go1.26.4 npm run verify
  > .build/fx001-task10-verify.log 2>&1` and `GOTOOLCHAIN=go1.26.4 node
  scripts/regression.mjs > .build/fx001-task10-regression.log 2>&1`.
  Ruling R1: passes when the only failures are the BACKLOG T007 serial
  timing set (fn-linear-timing up to 8, fn-scale 5,000-parameter 2,
  fx-block 20,000-let at its bound, occasionally large-source T004) and
  regression exits 0. Never change a bound. Your new differential serial
  test must itself pass (0 differences, coverage met).
- Record the default 500-program run's census, seed, counts and wall time
  in your report (the controller writes docs/progress.md).
- You may edit docs/engineering.md (corpus knobs) only; no other docs.
- Commit with message `test: FX001 reference interpreter and differential
  corpus` and trailers:
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01YZ4BVF4ByMDQWv2sZgis28
  Do not push. Never run two builds concurrently.
