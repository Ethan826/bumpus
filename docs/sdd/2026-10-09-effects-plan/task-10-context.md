# Task 10 context (controller; read after task-10-brief.md)

Branch claude/vibrant-cerf-3km61i, restarted from main 234d115 (Tasks 1-9
merged via Ethan826/waxwing#1). Work in /home/user/waxwing (no worktree).
The brief carries the 2026-10-09 amendments (rulings R5-R8: files,
interpreter semantics, generator, runs). Spec (binding semantics):
docs/plans/2026-10-09-effects-design.md §2 (rows, `defer` rule incl. the
strict rigid-tail rule), §3 (handler semantics, revised cleanup failures,
defects, crash), §5 (defect report). Where an interpreter detail is not
pinned by the spec, match the shipped compiler's documented contract and
say so in the report; a real compiler/interpreter disagreement is
reported, never papered over in either.

## Shipped facts the interpreter must mirror (Tasks 7-9)
- Runtime keys: user effect = EffectId+1 (State(Int) and State(Bool) share
  a key; first-occurrence typing makes the innermost frame's layout match);
  Fail families by the payload's declared head (Error(Int)/Error(Bool)
  share). The clauses of one `handle` are installed first clause innermost.
- Clause context: a clause runs in the context at its `with` (outer).
  Targeted aborts go to the innermost `handle` for the key in the context
  where `fail` executes.
- Cleanup: LIFO, exactly once per exiting activation, in the registration
  context. Defect report (Format/Go/Report.purs, Cleanup.purs): first line
  the original cause; later causes prefixed `cleanup failed: `; with no
  pending cause the first cleanup crash is the unprefixed first line; a
  pending typed abort is NOT delivered if cleanup raises a defect (it heads
  the report); Go runtime panics print `panic: <text>`; exit status 1.
  `<not printable>` payloads decided statically.
- Strict `defer`: typed failures can never escape cleanup in accepted
  programs; treat any typed abort escaping cleanup in the interpreter as a
  difference/bug signal (ruling R6).
- Evaluation order FN001 (arguments and stages interleave; over-application;
  `|>` left first).
- Existing executable expectations to validate the interpreter against
  first (brief Step 1): test/fx-run-programs.mjs, test/fx-cleanup.test.mjs,
  test/fx-console*/fx-block tests, fn-* run tests. Existing oracles for
  style/precedent: test/fn-oracle*.mjs, test/value-oracle.mjs,
  test/fn-programs.mjs (FN001 generator).

## Process
- This task is large: commit in coherent stages (interpreter validated
  against hand-written traces; then generator + census; then differential
  serial test + shrinker + sensitivity check), each with tests green, and
  keep the report file current as you go — the container has restarted
  several times today.
- Build `node scripts/build.mjs`; focused `node --test ...`;
  GOTOOLCHAIN=go1.26.4; gates test/style.test.mjs, test/structure.test.mjs
  (they also govern test/ and scripts/ files: 250-line cap etc.).
- Before the final commit: full `GOTOOLCHAIN=go1.26.4 npm run verify`
  (.build/fx001-task10-verify.log) and `node scripts/regression.mjs`
  (ruling R1: passes when only the BACKLOG T007/T004 timing set fails and
  regression exits 0). Never change a bound.
- Commit trailers:
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01YZ4BVF4ByMDQWv2sZgis28
  Do not push; do not edit docs/.
