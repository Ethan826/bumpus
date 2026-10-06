# Bootstrap evidence and current checkpoint

2026-10-07. The completed documentation/style audit is merged into main through 1f760af.
Fresh review found no blockers; merged verification passed. Baseline 9624bec
is preserved in history. Audit branch/worktree removed after retaining their
evidence. Task 1 commit: 4410609. No publishing or push.
The audit plan is docs/plans/2026-10-07-bootstrap-audit.md.

## Historical pre-audit checkpoint

The following evidence was recorded before skill installation/execution;
new worktree evidence follows below. Earlier raw logs are in the original
checkout, not assumed to exist in the isolated worktree.

## Verified evidence

`node scripts/verify.mjs` (same implementation as `npm run verify`) completed
with zero source warnings/errors, strict/pedantic workspace builds, 19 passing
Node tests, no skipped tests, and a successful isolated regression proof.
Recent raw output is in ignored `.build/verify.log`; this summary survives it.

- CLI emit/build/run: example prints `42`.
- Negative fixture checks assert exact code, span, filename, and exit status.
- Type/arity/entry/duplicate/local-scope rejection cases run as language inputs.
- Int32 min/max/wrapping cases build and execute, including constant overflow.
- Untaken recursive branch is not evaluated; forward calls and Bool returns run.
- 200 generated trees roundtrip through an independent printer and parser.
- 12 generated programs execute in Go and match a BigInt reference interpreter.
- 100 generated whitespace prefixes preserve exact diagnostic positioning.
- CST style/structure gates are tested with positive and negative cases.
- Restoring missing conditional branch compatibility in an isolated copy makes
  the regression assertion fail; the healthy compiler passes the same assertion.

A clean-output `npm run verify` passed, followed by a final successful run
after the formatter-version, cache-portability, unsafe-import, and malformed
negative-literal fixes. Final log: `.build/verification-final.log` (exit 0).
The MileAhead patch passed `git apply --check` against the read-only reference.
Online installation and cross-platform execution remain unverified.

## Artifacts already on disk

PureScript compiler: src/Sprig/*.purs, src/Sprig/Parse/*.purs,
src/Sprig/IR/Internal.purs. Boundary: src/Shell/CLI.purs and CLI.js.
Style tooling: tools/style/src/Style/Check.purs (separate package).
Tests: test/*.test.mjs and the regression witness/script.
Example, three negative files, and bootstrap/answer.go (example snapshot).
Documentation: README, AGENTS/CLAUDE, plan, findings, architecture, language,
provenance, ADRs, engineering guidance, bootstrap roadmap, and local backlog.

## Current remaining actions

Local integration is complete; proceed to a separate bounded ADT design/plan. Closed ADTs/exhaustive
matching require a separate later design and plan. F001 (fresh compiler-tool
setup), F002 (unapplied external patch), E001/E002 and E003 remain explicit.

## Superpowers installation and backport

Historical installation steering: install skills, migrate, then plan the run.
15 skills installed project-locally via bunx at the revision in skills-lock.json;
list command confirmed Codex/project scope. The unfinished audit is migrated
to docs/plans/2026-10-07-bootstrap-audit.md with a durable historical ledger.
At migration, no audit task or feature had run and Git had no HEAD. User
subsequently approved inline execution/checkpoint/worktree. W001 is resolved;
prior compiler evidence above is preserved.

Fresh migration validation: `npm run verify` on 2026-10-07 exited 0.
Strict/pedantic build reported zero source/library warnings and errors;
formatting and architecture/CST gates passed; 19 tests passed, zero failures
and skips; isolated restored branch-check defect failed as required while
the fixed compiler passed. Output was read from this session's command output,
not saved to a new raw log. This validates the preserved compiler after the
installation/migration; it does not complete the pending documentation/style
audit or represent a clean-output rebuild in this session.

## Audit execution: Task 1

User approved checkpoint, isolated worktree, inline execution and final fresh
review. Checkpoint 9624bec is on main; audit/bootstrap-docs runs in
.worktrees/bootstrap-audit. Clean-output baseline compiled 269 modules with
zero source/library warnings/errors, then passed 19 tests and the isolated
regression proof. Raw evidence: worktree .build/audit-baseline.log.

| Review focus | Source and evidence | Result/limit |
|---|---|---|
| Setup claims | README; scripts/build.mjs/cache.mjs; baseline log | Cached dependency build verified from clean compiler output. Fresh PATH-tool install/cross-platform setup remains F001. |
| IR boundary | Check/IR.Internal/Go; structure.mjs; layer test | Only checking/lowering imports internal IR in source. Checker validates encountered local/call indices; forged entry/table structure is trusted and documented. |
| Automated vs manual style | Style.Check; structure.mjs; style/structure tests | Essential CST/import/format/line gates pass. Manual fallback/callback/branch issues corrected; ten-arm tag mapping target exception recorded as E003. Full lint automation stays E001. |
| Snapshot/seed | bootstrap/answer.go; compiler snapshot assertion; docs/bootstrap.md | Example bytes match canonical emission; Stage 1 compiler seed remains proposed. Stage 0 source and locks preserved in baseline. |
| Handoff/external edit | patch; planning-skills; backlog; migration ledger | Skills installed and real BASE created. MileAhead patch remains unapplied (F002); current execution status is synchronized in Task 2. |

Style-only refactors preserve the existing public source-language contract.
The passing pre-change suite is the baseline; post-change verification and
existing isolated mutation establish continued behavior. No synthetic RED
history is asserted for documentation or helper extraction. ADRs 001/002 are
unchanged: no semantic/representation decision changed in this audit.

Task 1 post-change `npm run verify` exited 0: strict/pedantic build with zero
warnings/errors, all gates, 19/19 tests and isolated branch mutation proof
passed. Raw evidence: .build/audit-task-1-green.log. The earlier accidental
IR alias edit failed the same build; its copied defect also failed compile
in isolation. docs/findings.md retains the complete failed-attempt account.

## Audit execution: Task 2

Handoff files now identify the real baseline, audit branch, completed tasks
and final fresh review. Historical no-HEAD/no-commit statements are labeled
as historical. Review is complete; final completion verification is recorded below. No ADT source or plan was added.

Task 2 pre-review `npm run verify` exited 0 on 2026-10-07: zero strict-build
warnings/errors, 19/19 tests with no skips, style/layer gates and regression
proof passed. Raw log: .build/audit-task-2-pre-review.log in the audit worktree.

## Fresh review and closure

Fresh reviewer inspected 9624bec..56cbde1 read-only: no Critical/Important
findings. Two pre-existing test-title inaccuracies are deferred as E004;
no assertions were changed. Full review and exhaustive scope rulings are saved
in docs/plans/bootstrap-audit-review.md and bootstrap-audit-ledger.md.
The server restart interrupted delivery; the same reviewer resumed, avoiding
a second review or repeated implementation.

Two separate actual CLI emit invocations produced byte-identical output,
also equal to bootstrap/answer.go (cmp checks succeeded). The preserved
MileAhead patch again passed git apply --check without being applied. Stage 0,
locks, tests, example bytes and pure boundaries remain preserved. ADR 001/002
remain unchanged. At audit closure no language feature, merge, push or publication had occurred.

Raw failure evidence retained outside executor scratch:
.build/audit-task-1-failed-alias.log, .build/alias-regression/failure.log,
and .build/audit-task-1-fixed.log (the failed reproduction-helper attempt).
Successful raw evidence: .build/audit-baseline.log, audit-task-1-green.log,
audit-task-1-completion.log, and audit-task-2-pre-review.log in .build.

Final closure `npm run verify` exited 0 on 2026-10-07: strict/pedantic build
zero warnings/errors; 19/19 tests, zero skips; format/CST/layer gates and
isolated branch mutation proof passed. Raw final log: .build/audit-final.log.
Tasks 1/2 and original bootstrap tasks 7/8 are complete; no blocking review
finding remains. E004 minor titles are intentionally deferred. Integration into main was still pending at that checkpoint; it is now
complete as recorded below.

The installed task-done helper also verified Task 2 after commit f27b499:
19/19 tests, zero skips, strict build/gates/regression proof passed; commit
range 4410609..f27b499 is recorded in the durable ledger. Raw completion log:
.build/audit-task-2-completion.log. Executor scratch was copied in full to
.build/audit-executor-evidence before cleanup; durable ledger/review remain
committed in docs/plans. Only local branch integration is pending.

## Authorized local integration

User explicitly approved merge. Main fast-forwarded 9624bec..1f760af;
`npm run verify` on the merged checkout exited 0 on 2026-10-07: zero strict
warnings/errors, 19/19 tests, zero skips, formatting/CST/import gates and
isolated regression proof passed. Raw log: .build/merge-verification.log.

Audit raw logs, emitted files, isolated rename-defect copy and executor
artifacts were preserved under .build/merged-audit-evidence before removing
the merged audit worktree and branch. Historical worktree .build paths above
now resolve under that archive. Original checkout logs were not overwritten.
Durable ledger/review remain in docs/plans and all audit commits stay in main.
The pre-existing .vscode/settings.json spell-check additions are preserved
uncommitted. No push or publication occurred.
