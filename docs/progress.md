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

PureScript compiler: src/{Domain,Features,Format,Program}/**/*.purs and
src/Domain/IR/Internal.purs. Boundary: src/Runtime/Node.purs and Node.js.
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
| Automated vs manual style | Style.Check; structure.mjs; style/structure tests | Essential CST/import/format/line gates pass. Manual fallback/callback/branch issues corrected; ten-arm (now twelve; see BACKLOG E003) tag mapping target exception recorded as E003. Full lint automation stays E001. |
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

## A001 design (in progress)

2026-10-07: brainstorming for closed ADTs and exhaustive matching. User chose
recursive types, nested patterns with Maranget usefulness, type/match brace
syntax, tagged value-struct representation and sequential first-match
lowering. User review added CtorId identity, nil-guarded projections,
inhabitedness, canonical witnesses and two-pass type resolution. Approved spec:
docs/plans/2026-10-07-closed-adts-design.md. Documentation only; no compiler
source changed, so no verification run is claimed for this step.

2026-10-07: spec approved and committed (1d71f2f). writing-plans produced
docs/plans/2026-10-07-closed-adts-plan.md: five tasks (syntax; types and
construction; patterns and match; coverage; docs and review). Plan-time spec
amendments: E_DUPLICATE at the first duplicate (Stage 0 rule), depth-named
match parameters, and the Float row moving from E_SYNTAX to E_UNBOUND.
Documentation only; no compiler source changed.

2026-10-07: closed-ADT Task 1 (syntax) done. Added `|{}` and `=>` tokens,
reserved `type`/`match`/`_`, TypeRef, Parse.Declaration and Program dispatch;
Resolve maps NamedRef to E_UNBOUND transitionally. New test/adt-syntax.test.mjs
(7 tests) failed against pre-change source, then passed. `npm run verify`
exit 0 (26 tests, regression proof, answer.go unchanged).

2026-10-07: closed-ADT Task 2 (types and construction) done. Ty moved to Resolved
with TData; two-pass type table, shared global table, Construct through Check
and Go (Go.Data). test/adt-types.test.mjs (6 tests) failed before the change
(unbound-type errors), then passed. `npm run verify` exit 0 (32 tests, regression
proof, answer.go unchanged).

2026-10-07: closed-ADT Task 3 (patterns and match, no coverage) done. Parse.Literal
and Parse.Pattern, Resolve.Pattern with pre-order LocalIds, Check.Match, Go.Match
(depth-named IIFE, nil-guarded projections); examples/shapes.sprig with snapshot
bootstrap/shapes.go. test/adt-match (12) and test/adt-properties (1) failed before
the change (match was E_SYNTAX), then passed. Regression proof is a table: `branch`
and new `nil-guard` both fail on their mutants. `npm run verify` exit 0.
Fix round 1: pattern-constructor arity moved from Check.Match into
Resolve.Pattern (E_ARITY in pattern pre-order, before body and later-function
errors); two new rejection rows failed before (E_UNBOUND) and pass after.
`npm run verify` exit 0.

2026-10-07: closed-ADT Task 4 (coverage) done. Check.Usefulness (inhabitation fixed point, U(P,q), algorithm I) and Check.Coverage (E_REDUNDANT, E_NON_EXHAUSTIVE with canonical witness) run after checking; test/adt-coverage (6) and test/coverage (300-case oracle) failed before (non-exhaustive programs compiled), then passed; regression row `exhaustive` fails on its mutant. No existing test program changed. `npm run verify` exit 0 (52 tests, three regression proofs).

2026-10-07: closed-ADT Task 5 (five layers) done. Modules moved to Domain/Features/Format/Runtime/Program with git mv; Token, isUpper -> Format.Lex, codeName -> Format.Diagnostic; scripts/structure.mjs per-module table replaced by layer rules, four new structure cases failed before the gate. bootstrap/answer.go and shapes.go cmp identical, no stale Sprig./Shell. names. `npm run verify` exit 0 (52 tests, three regression proofs).

2026-10-07: closed-ADT Task 6 (structured diagnostics) done. Domain.Problem holds Problem/TypeName/Witness data; Features build no text; Format.Diagnostic code/message/wire render it, Program.Main uses wire. test/diagnostics characterization (39 families) passed at HEAD and unchanged after; its message/wire assertions failed before (no Domain.Problem); the R5 invalid-TypeId case compiled at HEAD returned Right (vacuously complete) and is now E_INTERNAL. Coverage table lookups split into Features.Check.Signature. bootstrap/answer.go and shapes.go cmp identical. `npm run verify` exit 0 (55 tests, three regression proofs; exhaustive mutant now `const (const (Right Nothing))`).

2026-10-07: closed-ADT Task 7 (capability ports) done. Domain.Host ports over abstract `m`; Format.Arguments (argv, usage text) and Format.Wire (plain/source/tool wire shapes); Program.Command over any Host; Runtime.Node is port implementations plus argv/stdout/stderr/exit and JSON only. test/program.test (9 fake-host cases) failed before (no Program.Command), then passed; two new structure rows (Program.Command importing Effect/Runtime) failed before the gate. Old/new CLI stdout, stderr and status byte-identical on 15 probes (usage, E_IO read/write, E_TYPE, E_TOOL with PATH='' and bad -o, emit/build/run); no temp dir leaked. bootstrap/answer.go and shapes.go cmp identical. Clean `rm -rf output && npm run verify` exit 0 (64 tests, three regression proofs).

2026-10-07: closed-ADT Task 8 (documentation and closure) done, review step excluded by controller ruling R6. Wrote ADRs 003 and 004; rewrote docs/language.md and docs/architecture.md; updated engineering, provenance (Maranget JFP 2007; MileAhead layers, conceptual only), README, BACKLOG (A001 Done; A002-A005, F005 added; E003 and F004 current), plan index and next-session. Clean `rm -rf output && npm run verify` (.build/a001-final.log): exit 0, 64 tests, 0 skips, regression proofs branch, nil-guard and exhaustive all passed. Two CLI emits of examples/shapes.sprig byte-equal each other and bootstrap/shapes.go; examples/answer.sprig emit equals bootstrap/answer.go (cmp). $TMPDIR still holds the same four stale `sprig-regression-*` directories after the run (F005). Final whole-branch review is run by the controller.

2026-10-07: A001 final whole-branch review findings fixed (record docs/plans/closed-adts-review.md). Function/constructor clashes report at the earliest declaration by source offset (new adt-types case failed before the fix at offset 26, passed after; .build/a001-review-minor3-red.log, -green.log). specialize and checkCtor return E_INTERNAL on field-count mismatch; the new diagnostics test fails with either change reverted in an isolated copy (.build/a001-review-isolated-red.log). Coverage oracle now requires witnesses to cover only unmatched values and checks brute-forced inhabitedness over 120 generated type systems (an inhabitedness mutant fails it: .build/a001-review-inhabited-mutation.log); 8 generated flat 3-5-arm matches run in Go (an arm-reordering mutant fails them: .build/a001-review-flat-mutation.log). verify.mjs runs every test/*.test.mjs (an unlisted failing dummy made verify exit 1: .build/a001-review-unlisted-probe.log). Clean `rm -rf output && npm run verify` (.build/a001-review-fix.log): exit 0, 0 warnings, 13 test files, 68 tests, 0 skips, regression proofs branch, nil-guard and exhaustive passed. CLI emits of examples/answer.sprig and examples/shapes.sprig equal bootstrap/answer.go and bootstrap/shapes.go (cmp). $TMPDIR still holds four stale `sprig-regression-*` directories (F005).

## Next milestone, item 1: F004 (2026-10-07)

Reproduced in an isolated copy: with a shadowed name added to Domain.Host, the
first `node scripts/build.mjs` failed with ShadowedName and the second exited
0. scripts/build.mjs now removes the output directory of every module declared
under src and tools/style/src before building (dependencies stay cached); the
same copy then failed both builds. New scripts/strict-rebuild.mjs, run by
verify, automates that proof; with HEAD's build.mjs restored in an isolated copy
it fails with "second build accepted a strict warning" (.build/f004-red.log).
AGENTS.md no longer requires a clean output directory. Clean
`rm -rf output && npm run verify` (.build/f004-verify.log) and the following
incremental `npm run verify` (.build/f004-verify-incremental.log) both exit 0:
0 warnings, 68 tests, 0 skips, strict rebuild proof and regression proofs
branch, nil-guard and exhaustive passed. The main item of the milestone is
not yet chosen.

## Next milestone, main item: A003 (design, 2026-10-07)

User chose A003 with print, equality and ordering. Design direction approved
with five clarifications (E_ENTRY keeps missing-main and parameters; round
trip recompiles with original declarations and checks structural equality via
the interpreter; ordering mutations must fail an oracle or explicit-order
assertion, with separately built equal values; nil-field panic rule scoped to
visited fields; Bool helper only when needed). Written spec:
docs/plans/2026-10-07-adt-printing-design.md, approved by the user.
Plan: docs/plans/2026-10-07-adt-printing-plan.md (4 tasks), awaiting review.
Documentation only; no compiler source changed.
