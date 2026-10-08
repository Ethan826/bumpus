# Bootstrap evidence and current checkpoint

## Language direction recorded (2026-10-08)

User review revisions: FN001 is scheduled after P001 before C001/R001/
FX001; C001/R001 require joint design review of ordinary record instances.
Documented row-specialization key/code growth and dictionary/accessor
passing as an option needing an ADR, not a chosen fallback. Lowered IR's
default to test is after specialization, above layouts. D001 records text,
numeric and collection foundations; M001 remains required for shared
modules. Rust pragmatics are explicit; FX001 compares ZIO-like computations
and Koka-like effect rows/handlers. All five review points addressed in the
direction document and backlog/handoff. Current P001 worktree untouched.

Fresh `npm run verify` on main exited 0: 162 tests, zero failures/skips,
zero build warnings/errors, gates, strict rebuild proof and eight isolated
regression proofs. Raw log: .build/language-direction-review-verify.log.
Documentation only; these milestones remain unimplemented.

User requested a local commit of the current language/backend/effect
discussion using the planning guidance. Read brainstorming/writing-plans;
recorded docs/plans/2026-10-08-language-direction.md as direction and
hypotheses, not an implementation spec. Goals, early-release deferrals,
row/service scenarios, effect-design questions, inspectable IR and future
targets are separated from assistant recommendations and open decisions.
Backlog follow-ups FX001 (effect design), L001 (lowered IR direction) and
J001 (JavaScript evaluation direction); P001's approved scope/order intact.
README, bootstrap index, next-session, findings and provenance linked.
Self-review checked scope, status, references and distinction between
proposed acceptance scenarios and implemented behavior. Documentation only.

Fresh `npm run verify` on main exited 0: 162 tests, zero failures/skips,
zero build warnings/errors, formatting/style/layer gates, strict rebuild
proof and eight isolated regression proofs passed. Raw evidence:
.build/language-direction-verify.log. Existing .vscode/settings.json edit
excluded from this change. No feature implemented and no push authorized.

2026-10-07. The language is renamed from Sprig to Bumpus (A003 Task 3a). Dated evidence below keeps literal historical identifiers (old module names such as `Sprig.Check`, `sprigCmpN`-style Go helpers, old command lines, `.sprig` paths and log names) verbatim because they name artifacts that existed; the prose language name changes.

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

## A003 execution

- 2026-10-07 Task 1 (comparison syntax, typing, primitive lowering): added
  `Operator`/`Compare` through lexer, parser (non-chaining, looser than `+`),
  resolver, checker, coverage and Go lowering; Bool ordering lowers through
  `sprigCmpBool`, emitted only when used. New test/compare.test.mjs (6 tests:
  runs, positions, rejections, left-to-right evaluation trace, helper
  presence, answer.go unchanged); the old "lone > is E_LEX" test now pins a
  lone `!`, and the branch regression needle gained context so it stays
  unique. `npm run verify` exit 0; bootstrap/answer.go and shapes.go
  unchanged.
- 2026-10-07 Task 2 (structural order for declared types): one
  `sprigCmpN` helper per declared type (tag range check, constructor order,
  fields left to right, nil check before a declared field), emitted in
  TypeId order; declared comparisons lower to `(sprigCmpN(L, R) op 0)`;
  `sprigCmpBool` is also emitted for any Bool constructor field. New
  test/value-oracle.mjs (reference order, printer, parser, alternate
  expressions) and test/adt-order.test.mjs (7 tests, all red before the
  change: hand cases, structural equality, 8192-element lists, uninhabited
  type, malformed values, evaluation trace, 8-seed oracle agreement with
  order laws and coverage assertions). Regression rows `ctor-order` and
  `first-field` fail with their defects restored; their probes run Go under
  .build/regression. bootstrap/shapes.go gains only `sprigCmp0`; answer.go
  unchanged. The compiler's ~3500-character stack limit was recorded under
  E002. `npm run verify` exit 0.
- 2026-10-07 Task 3 (printing and unrestricted `main`): `EntryResult` is
  gone and a missing entry reads `Expected fn main()`; `main` may return any
  type. New Format.Go.Show emits one `sprigShowN(out []byte, v sprigTyN)`
  per declared type in TypeId order (cases built from the constructor
  table, `fmt.Append` for Int/Bool fields, nil check before declared
  fields, unknown tag panics `bumpus: malformed value`); a declared `main`
  prints `string(sprigShowN(nil, sprigFnK()))`. The shared panic text moved
  to Format.Go.Data. New test/adt-print.test.mjs (7 tests, all red before
  the change: hand prints, Int/Bool unchanged, entry rules, 8192-element
  list print, malformed panics, 8-seed print round trip, tree snapshot);
  diagnostics and adt-types E_ENTRY rows updated per Global Constraints.
  Regression row `show-fields` fails with its defect restored (`printed
  value lost fields: Cons(1)`). New examples/tree.sprig and
  bootstrap/tree.go; shapes.go gains only `sprigShow0`; answer.go
  byte-identical. `npm run verify` exit 0.
- Task 3a (rename to Bumpus): `npm run build` rewrote spago.lock (packages bumpus, bumpus-style); bootstrap/answer.go, shapes.go and tree.go regenerated by the CLI each equal the old bytes under `sed s/sprig/bumpus/g;s/Sprig/Bumpus/g` (cmp, exit 0). New docs/assets/bumpus.svg. `npm run verify` exit 0.
- Task 3b (stack-safe lexing and declaration parsing, E002 part): Format.Lex
  scans by index in a `tailRecM` loop (Control.Monad.Rec.Class, `tailrec`
  now a direct dependency; spago.lock gains it), Format.Parse.declarations
  is a `tailRecM` loop, Format.Parse.Core reads tokens by index, and
  Format.Stack makes accumulation linear. Two quadratic resolver costs the
  20,000-declaration test exposed were fixed: globals are built once, and
  function-name duplicates use a sort (Features.Resolve.Repeated). New
  test/large-source.test.mjs (5 tests: megabyte padding, 20,000
  declarations run in Go, E_LEX at offset 1,000,020, megabyte lex under 5 s,
  duplicate among 20,000) all failed on the old code with heap exhaustion
  (.build/task3b-red.log); now 0.09 s, 2.2 s, 0.26 s, 0.07 s, 0.08 s. The
  structure allowlist admits exactly Control.Monad.Rec.Class (new structure
  test red first). Coverage-oracle `choose` reads the LCG's high 16 bits (a
  new test showed 80 two-way draws alternating `0101…`); seed-dependent
  preconditions then failed (adt-order `seed 22: one T0 constructor`,
  adt-print `nested`), so seeds were reselected, assertions unchanged.
  Dropping the backward neighbour check in Repeated fails the diagnostics
  and large-source duplicate tests in an isolated copy. bootstrap/*.go
  unchanged. `npm run verify` exit 0, 17 files, 96 tests, 0 skips
  (.build/task3b-verify.log).
2026-10-07: logo. The README shows assets/branding/bumpus-logo.png (1254 × 1254 PNG with alpha, a bluetick coonhound with the stolen turkey above the wordmark), chosen by the user from image-generator candidates; provenance and final prompt in assets/branding/README.md. The Task 3a SVG icon was removed at the user's request; no earlier image versions are kept. Documentation and assets only.
- 2026-10-07 Task 4 (documentation and closure): language.md, ADR 005,
  architecture, engineering, README, BACKLOG (A003 In review, E002 extended
  with the quadratic `uniqueTypes`/`uniqueCtors`, new T001), findings and
  next-session updated; each claim was checked against src/ and test/.
  `rm -rf output && npm run verify` exit 0, 0 warnings, 17 files, 96 tests,
  0 skips, strict rebuild proof, six regression proofs (branch, nil-guard,
  exhaustive, ctor-order, first-field, show-fields)
  (.build/a003-final-verify.log). CLI emits compared with `cmp` (exit 0):
  examples/answer.bumpus to bootstrap/answer.go, shapes.bumpus to shapes.go,
  tree.bumpus to tree.go, and tree.bumpus a second time to tree.go. A003 is
  In review; Done follows the final whole-branch review.
- 2026-10-07 final-review fixes (docs/plans/adt-printing-review.md): I3
  Go emission and resolver tables made non-quadratic (Format.Go.Layout,
  Repeated-based type and constructor duplicate checks, linear typeInfo).
  New 20,000 one-constructor-types test failed first at 25.9-26.3 s against
  its 5 s bound, now 0.23-0.28 s; duplicates among 20,000 types 21.8 s to
  0.43 s; reporting at the later constructor fails it in an isolated copy.
  Emitted Go byte-identical: `cmp` of the CLI emits of examples/answer,
  shapes and tree against bootstrap/*.go (exit 0) and 504 programs emitted
  identically by b5dde4e and the fix. Tag-3 compare case fails under an
  emitted `.tag > count+1` mutant. adt-order runs one Go program per seed.
  E002, language.md, ADR 005 and architecture.md corrected (I1, I2); G001
  added; A003 Done. `rm -rf output && npm run verify` exit 0, 0 warnings,
  17 files, 98 tests, 0 skips, six regression proofs
  (.build/a003-review-fix-verify.log).
  Follow-up: the final test/large-source.test.mjs run against a b5dde4e
  build fails both new tests on their 5 s bounds (types 25.9 s, duplicates
  21.8 s). Remaining per-reference name scans (resolveType, findGlobal)
  measured at 1.7 s for 20,000 references and recorded in E002 for G001.

## A003 merged (2026-10-07)

User approved the merge. main fast-forwarded 74e5c2a..4b5ce2e. Clean
`rm -rf output && npm run verify` on main exited 0: zero warnings, 98 tests,
zero failures/skips, strict rebuild proof and six regression proofs
(branch, nil-guard, exhaustive, ctor-order, first-field, show-fields). Raw
log: .build/a003-merge-verify.log. Worktree .build logs and the SDD ledger
were archived under .build/merged-a003-evidence before the a003 worktree
and branch were removed. No push. Next: G001 (design first).

## G001 design (2026-10-07)

User chose an applicative-only parser (no Monad instance) and a depth limit
with a structured diagnostic for deep nesting (over a larger Node stack or
heap-based phases). Written spec:
docs/plans/2026-10-07-applicative-parser-design.md, approved as written
with clarifications (section 7).
Documentation only; no compiler source changed.
Plan: docs/plans/2026-10-07-applicative-parser-plan.md (5 tasks), awaiting
user review.

## G001 execution

- Task 1 (2026-10-07): applicative grammar core (Format.Parse.Grammar, with
  the token cursor split into Format.Parse.Cursor to stay under 250 lines);
  Literal and Pattern ported; Expression reaches them through
  fromLegacy/toLegacy. test/grammar.test.mjs RED: 1,473 arms RangeError
  (trailing-comma rows recorded from the old compiler, passing); GREEN: 1,473
  arms in 0.23 s. `npm run verify` exit 0, 101 tests, 0 failures/skips
  (.build/g001-task1-verify.log); emits of answer, shapes, tree cmp-identical
  to bootstrap/*.go.
- Task 2 (2026-10-07): Expression, Declaration and the declaration loop
  ported to the applicative grammar; Format.Parse.Core and the
  fromLegacy/toLegacy, legacyState/grammarState adapters deleted; `spanned`
  is an empty span when nothing is consumed; Functor map is direct. New CST
  rule: no `do`, `>>=` or `=<<` in Format.Parse and
  Format.Parse.{Literal, Pattern, Expression, Declaration} (Grammar, Cursor
  exempt). RED: 1,536 constructors, 1,536 fields and 1,793 arguments
  RangeError (.build/g001-task2-red.log), style fixture failing
  (.build/g001-task2-style-red.log), empty `spanned` failing in an isolated
  copy (.build/g001-task2-spanned-red.log); GREEN 15 ms, 7 ms, 56 ms
  (.build/g001-task2-green.log). `fn main(): Int = (1` keeps E_SYNTAX
  "Expected ')'" at 19-19. Parser lines 889 -> 685 (no module grew).
  `npm run verify` exit 0, 112 tests, 0 failures/skips
  (.build/g001-task2-verify.log); answer, shapes, tree emits cmp-identical
  to bootstrap/*.go. Cold-CLI nesting depth moved (BACKLOG E002).
- Task 3 (2026-10-07): E_NESTING at 128 levels (ADR 006): `nested`,
  `infixed`, `rooted` and `nestingLimit` in Format.Parse.Grammar, `depth` and
  `peak` in the Cursor state; operators count the depth of the tree they
  build, so a deep left operand counts in full; Grammar `foldAt` runs the
  first item directly. Probe (scripts/depth-probe.mjs, limit disabled):
  smallest overflow 304 (`Cons(1, `), no anomalies after classifying V8's
  regex `Stack overflow` SyntaxError as an overflow; limit = largest power
  of two ≤ 152. RED: test/depth.test.mjs 14 of 26 failing, no E_NESTING
  (and `go build` killed on 128 nested match arms, BACKLOG E005)
  (.build/g001-task3-red.log); diagnostics E_NESTING row failing with the
  limit disabled; GREEN 26/26 (.build/g001-task3-green.log). `npm run
  verify` exit 0, 138 tests, 0 failures/skips (.build/g001-task3-verify.log);
  answer, shapes, tree emits cmp-identical to bootstrap/*.go.
- Task 4 (2026-10-07): resolver numbering through Features.Resolve.Fresh
  (state-and-error, Functor/Apply/Applicative/Bind/Monad; `fresh`,
  `failure`, `liftEither`, `runFresh`); arms, arguments and pattern fields
  via balanced `traverse`; `Numbered` dropped from Domain.Resolved.
  Characterization (test/adt-match.test.mjs LocalIds row) recorded from and
  passing on the old compiler, failing when arms are numbered before the
  scrutinee in an isolated mutant. New: 10,000 binding arguments compile in
  about 1 s (test/large-source.test.mjs; RED RangeError on the old resolver,
  .build/g001-task4-red.log). Differential over 1,327 distinct sources
  compiled by the suite: all identical Go or diagnostics except that row.
  `npm run verify` exit 0, 140 tests, 0 failures/skips
  (.build/g001-task4-verify.log); answer, shapes, tree emits cmp-identical
  to bootstrap/*.go.
- Task 4b (2026-10-07): coverage breadth and parameter duplicates.
  Coverage's Array.foldM searches over Either (redundancy over arms;
  exhaustiveness and wildcard usefulness over constructors) became
  Features.Check.Search.firstJust (`tailRecM`); `specialize` checks arity
  once, then mapMaybe; parameter duplicates use Repeated. Corrected
  thresholds: the coverage overflow was about 1,929 arms (not 3,000), the
  pre-G001 resolver overflowed near 1,700 arms or arguments (not 5,000).
  RED on the pre-fix compiler (.build/g001-task4b-red.log): 5,000 integer
  arms and 3,000 constructors RangeError, 20,000 parameters 3.07 s;
  per-site mutants (each foldM restored alone, quadratic uniqueParameter,
  reversed Fresh `apply` for the strengthened 10,000-argument order test)
  each fail. GREEN (.build/g001-task4b-green.log): 5,000 arms 1.3 s,
  3,000 constructors 1.3 s, 20,000 parameters 0.17 s; still quadratic in
  arms (10,000 arms 5.2 s, BACKLOG E002). `npm run verify` exit 0, 144
  tests, 0 failures/skips (.build/g001-task4b-verify.log); `exhaustive`
  regression row holds; answer, shapes, tree emits cmp-identical to
  bootstrap/*.go.
- Task 5 (2026-10-07): closure. Regression row `state-thread`
  (scripts/regression.mjs, probe in test/regression.mjs): Grammar's `apply`
  running the second parser from the original state makes
  examples/answer.bumpus fail with `parser state not threaded` (E_SYNTAX
  "Expected an identifier" at 1:1; .build/g001-t5-state-thread-mutant.log);
  the healthy compiler emits bootstrap/answer.go. CST gate closed
  (tools/style/src/Style/Parser.purs): productions also reject `bind`,
  `join`, `discard` (plain, qualified, backticked), `>=>` and `<=<`, and
  only Format.Parse (and Grammar) may import `run`/`initialState`; open,
  `as`-only and `hiding` imports of Grammar or Cursor are rejected. RED: 2 of
  8 style tests failing (.build/g001-t5-style-red.log); the positive
  fixture fails with the importer exemption removed, in an isolated copy
  (.build/g001-t5-style-positive-mutant.log); GREEN 8/8
  (.build/g001-t5-style-green.log). Measured at the CLI: a 129-operand flat
  sum compiles and 130 is E_NESTING; a 128-element printed list compiles
  and 129 is E_NESTING. Docs: language.md (nesting rule, E_NESTING), ADR
  005 and 006, architecture.md, engineering.md, findings, README,
  next-session; BACKLOG G001 In review, E002 restated, E005 options left to
  the user, new O001, H001, F006 (stale output of deleted modules,
  recorded, not fixed). `rm -rf output && npm run verify` exit 0, 20 files,
  147 tests, 0 failures/skips, seven regression proofs
  (.build/g001-task5-verify.log); answer, shapes, tree emits cmp-identical
  to bootstrap/*.go. Final whole-branch review pending.
- Final whole-branch review fixes (2026-10-07; record
  docs/plans/applicative-parser-review.md). I1: usefulness and algorithm I
  (Features.Check.Usefulness, new Features.Check.Missing, shared
  Features.Check.Matrix) run on an explicit Search `Stack` in `tailRecM`;
  I2: inhabitation is a worklist (new Features.Check.Inhabited, lookups in
  Features.Check.Tables), and Array.modifyAtIndices is chunked after the
  20,000-type test overflowed in it. RED on the pre-fix compiler: all four
  test/coverage-scale.test.mjs cases RangeError (5,000-field exhaustive,
  non-exhaustive witness and redundant arm; 10,000-type chain after 9.9 s)
  (.build/g001-final-fix-red.log); GREEN 0.27-0.36 s, 0.08 s, 0.05 s,
  0.64-0.69 s. Remaining cliffs measured and recorded in BACKLOG E002 (4),
  (5). M1: the Bind gate also rejects ap, ifM, whenM, unlessM, liftM1,
  bindFlipped, composeKleisli, composeKleisliFlipped (style fixture failed
  first on `ap`); M2: test/depth.test.mjs imports `nestingLimit`; M4: ADR
  006 gives the exact uncommitted probe steps; M5: O001 notes. M3: accepted
  that src/Format/Parse/Literal.purs grew 51 -> 55 lines, all of it the
  purs-tidy one-per-line Grammar import list (spec section 6 "no parser
  module grows" is otherwise met). `rm -rf output && npm run verify` exit 0,
  21 files, 151 tests, 0 failures/skips, seven regression proofs (the
  `exhaustive` needle still matches once and its mutant fails)
  (.build/g001-final-fix-verify.log); answer, shapes, tree emits
  cmp-identical to bootstrap/*.go. G001 Done, pending the controller's
  scoped re-review.

## G001 merged (2026-10-07)

User approved the merge and kept the externally rewritten history. main
fast-forwarded to 44a735b. Clean `rm -rf output && npm run verify` on main
exited 0: zero warnings, 151 tests, zero failures/skips, strict rebuild
proof and seven regression proofs (branch, nil-guard, exhaustive,
ctor-order, first-field, show-fields, state-thread). Raw log:
.build/g001-merge-verify.log. Scoped re-review of the final fixes found all
findings addressed (116,000+ differential coverage cases identical to the
pre-fix build); remaining wording nits fixed here (engineering test count)
or parked (coverage-scale comment, Inhabited complexity formula). The
re-review's out-of-scope allowlist gap is BACKLOG F007. Worktree evidence and
the SDD ledger are archived under .build/merged-g001-evidence; the g001
worktree and branch are removed.

## E005 execution

- 2026-10-07, branch e005 from 0777cf6, design approved by the user. Each
  match lowers to a top-level Go function `bumpusFn{f}Match{k}` (k in
  per-function pre-order, scrutinee before arms), taking its captured
  locals in LocalId order and then `bumpusScrutinee`; lifted functions
  follow their function in number order (ADR 003 item 6). New modules
  Format.Go.Lowered (counter threading), Format.Go.Expression (moved out of
  Format.Go) and Format.Go.Capture; Format.Go.Compare's `comparison` now
  takes lowered operand code.
- RED on the closure compiler: test/match-lift.test.mjs's two signature
  tests failed (no `bumpusFn0Match*` functions; .build/e005-red-lift.log);
  its capture test passed, as expected for closures, and its RED is the
  `capture` mutant. The 128-deep timing test hit its 10 s spawn timeout
  (.build/e005-red-timing.log). The full-limit match-arm and
  compare-matches runs were not executed on the closure compiler (prior
  record: killed at 128).
- Mutants of Format.Go.Capture in isolated copies: dropping nested
  scrutinees (the `capture` row) and capturing nothing both make the probe
  fail with `captured local lost` and Go's `undefined: bumpusLocal3` /
  `bumpusLocal1` (.build/e005-mutants.log).
- Timings (.build/e005-timing.log, `go build`, Go 1.26.4): closures 0.31 s
  at d = 16, 1.26 s / 596 MB at 20, 7.99 s / 2.7 GB at 22; named functions
  0.13-0.15 s and about 67 MB at every d from 8 to 128.
- test/adt-match.test.mjs `LocalIds in emitted Go follow source pre-order`
  pinned the emitted text of one closure-form body; its expected sequence
  now covers bumpusFn0 and its four lifted matches (same binder numbering,
  plus capture parameters and arguments).
- bootstrap/answer.go byte-identical; shapes.go and tree.go regenerated
  through the CLI (matches become `bumpusFn0Match0`/`Match1` functions).
- `rm -rf output && npm run verify` exit 0: zero warnings, 22 files, 155
  tests, zero failures/skips, eight regression proofs including `capture`
  (.build/e005-verify.log).
- Review fix round 1 (2026-10-07). (1) Capture cost: each lifted match
  re-scanned its subtree. A 127-deep ladder of 50-arm matches (147 KB)
  compiled in 3.0 s against 0.27 s on 0777cf6 (depth 64: 0.71 vs 0.15 s).
  Lowering now returns each subtree's free locals (Format.Go.Lowered `free`;
  Format.Go.Capture `union`/`armFree`), so captures come from one bottom-up
  pass: 0.31 s at 127. New test `a deep, wide match ladder compiles in under
  1.5 s` failed first at 3,028 ms (.build/e005-fix1-red-ladder.log). Generated
  Go is byte-identical to the pre-fix head on 21 programs (the three
  examples, the match-lift, LocalId and capture programs, an if/match mix,
  ladders at 32 and 127, and every depth form at 128) and cmp-identical to
  bootstrap/*.go (.build/e005-fix1-identical.log). The `capture` row now
  drops a match's scrutinee from its free set (Format.Go.Match); its mutant
  fails with `undefined: bumpusLocal3` (.build/e005-fix1-mutant.log).
  (2) The 128-deep timing test emits Go, then runs `go build` detached in
  its own process group, killed as a group on timeout, and removes its temp
  directory in `finally`. Against the closure compiler it failed with `go
  build killed at 10000 ms` and left no go/compile process or temp
  directory (.build/e005-fix1-groupkill.log). (3) Its comment now says the
  build cache may supply the binary and why the bound stays honest.
  `rm -rf output && npm run verify` exit 0: zero warnings, 22 files, 156
  tests, zero failures/skips, eight regression proofs
  (.build/e005-fix1-verify.log).

## E005 merged (2026-10-08)

User approved. main fast-forwarded to 09f3071 (E005 c928d93 plus review fix
round 09f3071). Clean `rm -rf output && npm run verify` on main exited 0:
zero warnings, 156 tests, zero failures/skips, eight regression proofs. Raw
log: .build/e005-merge-verify.log. Review: 430-program base/head
differential identical (values and call traces) and malformed-value panics
identical; fix round re-review addressed all three findings. Parked: one
82-column JS test line (rule binds PureScript only), the stale
Format.Go.Capture header comment (fixed with T001), wall-clock budgets with
~5x headroom. Evidence archived under .build/merged-e005-evidence; worktree
and branch removed. Next: T001, then P001 (user order 2026-10-07).

## T001 execution (2026-10-08)

Branch t001 (.worktrees/t001) from 62f8192. Brief:
.superpowers/sdd/t001/brief.md (approved with eight binding amendments).

- Preparatory commit `docs: refresh Format.Go.Capture header`: the header now
  describes bottom-up free-local sets (parked from the E005 review).
- Baseline, same machine, warm Go cache (a warm-up verify ran first, 82.3 s):
  `rm -rf output && npm run verify` 76.4 s wall, its node --test phase
  33.0 s (duration_ms 33,026; .build/t001-before-verify.log); `node --test`
  alone 27.0 s (.build/t001-before-tests.log); 156 tests. Serial per-file:
  large-source 12.4 s, adt-order 8.8, adt-print 8.5, depth 8.0, compare 7.0,
  adt-properties 6.3, adt-match 4.7, properties 3.8, compiler 3.1, adt-types
  1.7, match-lift 1.5, adt-coverage 0.5.
- test/go-batch.mjs adds `runGoBatch` (design and failure contract in
  docs/engineering.md). Self-tests (test/go-batch.test.mjs, five tests) were
  first run against a stub that throws: 5/5 failed
  (.build/t001-selftest-red.log), then passed against the implementation
  (.build/t001-selftest-green.log). Each also kills a mutant of the harness
  in an isolated copy (.build/t001-mutants.log): a rejection failing the
  whole batch, no blame in the compile diagnostic, a disabled shape guard,
  clearing the go-batches root, and a lost exit status each fail exactly
  the matching self-test; the healthy copy passes 5/5.
- No runGo caller pinned stderr: runGo returned stdout only and asserted
  exit 0, so every caller was migrated: adt-coverage, adt-match, adt-order,
  adt-print (two batches: reprints depend on the first outputs),
  adt-properties, adt-types, compare, compiler, large-source, match-lift,
  properties. Generated-program loops in adt-properties and properties draw
  their programs at module level in the original order; adt-properties'
  20 programs were checked identical to the old in-test draws. Assertions
  and their messages are unchanged; Bumpus sources are unchanged.
- Batch compilation is lazy (first `run`), so large-source's timed
  `checked()` of the 20,000-declaration program is still the first compile
  of that source. Its 5,000-arm timed compile now follows the batch's
  compile of the same source (JIT-warm); the 5 s bound still fails a
  quadratic regression by far, and a cold-compile stack overflow would
  still surface through the batch's own first compile, rethrown by that
  case's `run`.
- After: `rm -rf output && npm run verify` exit 0, 60.7 s wall, node --test
  phase 19.2 s (duration_ms 19,167; .build/t001-after-verify.log), 23 files,
  161 tests, zero failures/skips, eight regression proofs; `node --test`
  alone 15.5 s (.build/t001-after-tests.log). Serial per-file: large-source
  10.7 s, adt-order 6.3 (rest is goTest), adt-print 2.4, depth 8.0
  (unchanged, out of scope), compare 2.1, adt-properties 0.5, adt-match 2.0,
  properties 0.5, compiler 1.6, adt-types 0.4, match-lift 1.2, adt-coverage
  0.5, go-batch 1.4.

T001 review fix round 1 (2026-10-08; review: ready to merge, six cheap items).
(1) large-source: the 5,000-arm case has its own batch (label `arms`),
declared inside its test after the timed compile, so that timed compile is
cold again. (2) The guard self-test gains `package main` followed by
`package other`, and a second multi-line `func main() {`; the two guard
clauses that no self-test bound (the `package \w+` count and the `func main`
count), each replaced by `true`, now fail that test. (3) `runGoBatch` takes
an array of `[name, spec]` pairs and refuses a duplicate name (compared as
strings, as `run` looks names up) at declaration; every caller passes pairs.
New self-test failed first with `Missing expected exception`
(.build/t001-fix1-dup-red.log). (4) The directory self-test removes its
neighbour marker in `finally`. (5) docs/engineering.md: batch directories
persist (`rm -rf .build/go-batches` reclaims them), concurrent test runs in
one checkout race on them, and the 300 s build timeout does not group-kill
(noted rather than changed: spawnSync cannot kill a group). (6) Only the
shape guard's refusal becomes "generated Go was refused"; filesystem errors
propagate as themselves. Mutants in an isolated copy
(.build/t001-fix1-mutants.log): all eight (the five earlier, both guard
clauses, no duplicate check) fail exactly their self-test; healthy 6/6.
`rm -rf output && npm run verify` exit 0: 162 tests, zero failures/skips,
eight regression proofs, test phase 19.9 s, 61.8 s wall
(.build/t001-fix1-verify.log).

## T001 merged (2026-10-08)

User approved. main fast-forwarded to 4230eb9 (T001 7cbf2dd, c4e5cd0 and
review fix round 4230eb9). Clean `rm -rf output && npm run verify` on main
exited 0: zero warnings, 162 tests, zero failures/skips, test phase 19.4 s,
eight regression proofs. Raw log: .build/t001-merge-verify.log. Evidence
and brief archived under .build/merged-t001-evidence; worktree and branch
removed. main pushed to origin at the user's request. Next: P001.

## P001 execution

Plan: docs/plans/2026-10-08-polymorphism-plan.md (spec
docs/plans/2026-10-08-polymorphism-design.md). Branch p001 in
.worktrees/p001; baseline `npm run verify` exit 0, 162 tests, eight
regression proofs (.build/p001-baseline-verify.log).

### Task 1: parameterized type, checked IR, Specialize seam (2026-10-08)

Behavior-preserving refactor; no language change. Pipeline is now Parse →
Resolve → Check → Specialize → Go (Program.Compile `parse >=> resolve >=>
check >=> specialize`, then `emit`).

- Domain.Type (new): `TypeId` (moved from Domain.Resolved, re-exported
  there), `VarId`, `data Ty v = TInt | TBool | TData TypeId (Array (Ty v))
  | TVar v` with Eq, Ord, Functor, Apply, Applicative, Bind (substitution),
  Monad, and `ground ∷ Ty v → Maybe (Ty Void)`. Domain.Resolved re-exports
  it; resolved types are `Ty VarId`. Nothing produces `TVar` or a type
  argument yet.
- Domain.Checked.Internal (new): the former IR shape over `Ty Open`, `data
  Open = Rigid VarId | Hole Int`; `Call` and `Construct` carry an
  `Instantiation` (always empty now); `rigid ∷ Ty VarId → Ty Open`.
  Features.Check* produce and cover it; `check` returns `Checked.Program`
  (the `CheckedProgram` alias is gone).
- Domain.IR.Internal: its own variable-free `Ty`, `TypeInfo`, `CtorInfo`,
  `Tables` (ruling R1). Format.Go* change only imports.
- Features.Specialize (new): `specialize ∷ Checked.Program → Either
  Diagnostic IR.Program`, a copy that converts ground `TData id []`; any
  variable, type argument or non-empty instantiation is E_INTERNAL
  `unspecialized type` at the holding span (unreachable until Task 2).
- Coverage (Signature `candidates`) and Match `typeName` report E_INTERNAL
  on a `TVar` instead of guessing; Task 6 and Task 3/4 replace those arms.
- Structure gate: two `{ module, importers }` rules in scripts/structure.mjs
  `internalModules`. AGENTS.md, docs/engineering.md, docs/architecture.md
  updated. Regression row `branch` needle follows the rename
  (`Checked.typeOf`); still one target, same defect.
- Tests: test/structure.test.mjs gains the two-IR gate test (and its old
  "Features.Check may import Domain.IR.Internal" row now names
  Domain.Checked.Internal, since that import is now forbidden);
  test/specialize.test.mjs `specialize is the identity on monomorphic
  programs` over examples/*.bumpus and the 232 generated programs of the
  two property files. Their generators moved to test/generators.mjs
  (importing a test file would register its tests and build its Go batch);
  draw order and seeds unchanged. test/diagnostics.test.mjs: the two
  white-box coverage tests now build their input from
  Domain.Checked.Internal and pass `TData` its (empty) argument array;
  their assertions are unchanged.
- RED: `node --test test/structure.test.mjs` failed the new gate test
  (`actual: []`, expected `[ 'Features.Check imports Domain.IR.Internal' ]`;
  .build/p001-task1-red-structure.log). `node --test
  test/specialize.test.mjs` failed with ERR_MODULE_NOT_FOUND for
  output/Features.Specialize (.build/p001-task1-red-specialize.log).
- GREEN: `rm -rf output && npm run verify` exit 0, 85.5 s wall, zero
  warnings, 164 tests (162 + 2), zero failures/skips, eight regression
  proofs, bootstrap snapshots unchanged (.build/p001-task1-verify.log).
- Phase reached: every test runs the full pipeline on monomorphic programs;
  the CLI does not compile polymorphic programs (none parse yet).

### Task 2: type parameters and applied types, syntax and resolution (2026-10-08)

Language change: `type List(a) = Nil | Cons(a, List(a));`, lowercase type
variables, parenthesized application. Status: done.

- Domain.Syntax: `TypeRef` gains `VarRef Span String`; `NamedRef` carries
  its arguments and spans head through `)`; `TypeDecl.parameters ∷ Array
  TypeParameter` (`{ name, span }`); `typeRefSpan`.
- Format.Parse.Declaration: optional `(lower, …)` after a type name
  (`type T() = A;` is E_SYNTAX `Expected a type parameter` at `)`); a type
  is Int, Bool, a lowercase name, or an upper name with optional arguments,
  each argument one `nested` level (ADR 006), so 129 deep is E_NESTING at
  the 129th argument. `List()` fails at `)`; `Int(a)`/`a(Int)` at `(`.
- Domain.Problem / Format.Diagnostic: `TypeArguments` (E_ARITY `Wrong
  number of type arguments for <name>`), `UnboundTypeVariable`,
  `DuplicateTypeParameter`, `EntryPolymorphic`; `TypeName` gains
  `AppliedName`, `VariableName`, `HoleName` (rendered `List(Pair(Int, a))`,
  `a`, `_`). Witness and type argument lists share one `listed` helper.
- Domain.Resolved: `TypeInfo.parameters`, `CtorInfo.fieldSyntax` (the
  field's source TypeRef, for Task 5's nested spans), `FunctionDecl.variables`.
- Features.Resolve*: order is type names, the existing duplicate checks, then
  every declaration's type parameters (reported at the repetition, via
  Repeated `laterRepeat`, sort-based), then field types. In a declaration
  `VarId i` is its i-th parameter; an unknown lowercase field type is
  E_UNBOUND. A function's variables are every lowercase name in its
  signature, first occurrence, parameters then result
  (Features.Resolve.Variables `signatureVariables`). Arity is checked at the
  whole reference before its arguments. `main` with a non-ground result is
  E_ENTRY `EntryPolymorphic`, beside `EntryParameters`.
- Features.Specialize: projects `TypeInfo` and `CtorInfo` explicitly, since
  the monomorphic IR does not carry parameters or field syntax.
- Tests: test/phases.mjs (`resolved`, `resolveRejectedAt`, `checkedPoly`,
  `checkRejectedAt`); test/poly-syntax.test.mjs, 21 tests. test/specialize
  `identical` now asserts each checked type has no parameters and each
  constructor one syntax reference per field, then drops both before the
  identity comparison (they are resolution data the IR does not hold).
- RED: `node --test test/poly-syntax.test.mjs`: 19 of 20 failed (the one
  pass, `Int(a)` at `(`, already held) (.build/p001-task2-red.log). GREEN:
  20 of 20 (.build/p001-task2-green.log).
- Conflict resolved by coordinator ruling: `fn main(): int = 1;` is now a
  polymorphic `main` (E_ENTRY `EntryPolymorphic`, span 0–19), as design §1
  requires, not E_SYNTAX at `int`. Only the inputs of two characterization
  rows changed, each keeping its code, span and text:
  test/diagnostics.test.mjs now uses `fn main(): 100 = 1;` (E_SYNTAX
  `Expected a type`, 11–14) and test/adt-syntax.test.mjs
  `fn main(): 1 = 1;`. poly-syntax pins the new `int` behavior (21 tests).
  The specialize identity-helper edit above was accepted (adds assertions,
  removes none).
- GREEN: `rm -rf output && npm run verify` exit 0, 185 tests (164 + 21),
  zero failures/skips, zero warnings, eight regression proofs
  (.build/p001-task2-verify.log).
- Phase reached: these tests reach Resolve only (rejections stop in Parse
  or Resolve through `compile`). The CLI does not compile polymorphic
  programs until Task 7: a use of a type variable or applied type stops in
  Check (E_INTERNAL `Unnamed type variable`) or Specialize (E_INTERNAL
  `unspecialized type`). A declaration whose parameters no field or
  signature uses still compiles, as a monomorphic type.

### Task 3: the unifier (2026-10-08)

No language change; nothing calls the unifier until Task 4. Status: done.

- Features.Check.Unify (new): `Flex = Rigid VarId | Meta Int`; triangular
  `Subst` (a Map from meta to `Ty Flex`), `empty`; `substitute` (one pass,
  Ty's bind; defined on every substitution) and `compose` (law
  `substitute (compose s2 s1) = substitute s2 ∘ substitute s1`);
  `resolve` (full normalization, acyclic substitutions only); `Failure =
  Mismatch | Occurs`; `unify` (rigid only with the same rigid; a meta binds
  to its walked partner unless the resolved partner properly contains it;
  TData argument-wise, left to right, stopping at the first failure). A
  Mismatch carries the first differing subterm pair, an Occurs the meta and
  the containing type, both resolved under the substitution reached at the
  failure. Meta-to-meta chains are followed by a `tailRec` loop (`walk`);
  recursion is over type structure only (see E006).
- Domain.Problem / Format.Diagnostic: `InfiniteType TypeName TypeName`,
  E_TYPE `Infinite type: <a> occurs in <b>` (raised from Task 4).
- Dependencies (user-approved): spago.yaml adds ordered-collections and
  tuples (already locked through tools/style; spago.lock's workspace entry
  lists them; build offline from .spago cache). scripts/structure.mjs
  `coreLibraries` admits exactly Data.Map, Data.Set and Data.Tuple;
  docs/engineering.md records the rule.
- Tests: test/structure.test.mjs `pure layers may use Data.Map, Data.Set
  and Data.Tuple only` (rejects Data.List, Data.Map.Internal, Data.MapX,
  Data.Tuple.Nested, Data.Set.NonEmpty). test/unify.test.mjs, 9 tests: the
  brief's pairs; left-to-right stop; substitute versus resolve on
  {m0 ↦ List(m1), m1 ↦ Int}; 500-case properties (substitute equals a
  one-pass reading and obeys the composition law over arbitrary, possibly
  cyclic substitutions; resolve idempotent with no bound meta left over
  acyclic ones; unify results acyclic, sound, most general for
  ground-range σ pairs, and in agreement with test/unify-oracle.mjs, an
  independent union-find unifier, on success and on the unified types up
  to renaming of metas, for single pairs and for pairs threaded after a
  σ pair: 268 of 1,000 sequences succeed); stack safety at 128-deep types
  and a 10,000-meta chain; the InfiniteType wire rendering (code and text).
- Generator note: drawing the keep/drop decision before each binding
  correlated with the next LCG draw and never produced a bare-variable
  binding, so a `resolve` that stops after one link passed the resolve
  property; the binding is now drawn first.
- Mutation checks (isolated copy under the session scratchpad, not
  regression rows; Task 7 adds `occurs` and `rigid`): occurs check removed,
  rigid unifying with any rigid, resolve stopping after one link, no walk
  in unify, compose with reversed union bias, arguments right to left: each
  fails at least one unify test.
- RED: `node --test test/structure.test.mjs` failed the new gate test
  (`[ 'pure module Features.Check.Unify imports Data.Map' ]`,
  .build/p001-task3-red-structure.log); `node --test test/unify.test.mjs`
  failed with ERR_MODULE_NOT_FOUND for output/Features.Check.Unify
  (.build/p001-task3-red-unify.log). GREEN: 9 of 9
  (.build/p001-task3-green-unify.log).
- GREEN: `rm -rf output && npm run verify` exit 0, 71.2 s wall, zero
  warnings, 195 tests (185 + 10), zero failures/skips, eight regression
  proofs (.build/p001-task3-verify.log).
- Phase reached: unit level only (compiled module loaded from output/). The
  CLI does not compile polymorphic programs until Task 7.

### Task 4: polymorphic checking (2026-10-08)

Language change: rank-1 polymorphic functions and constructors type-check.
Status: done.

- Features.Check is split (every file under 250 lines): Check.purs
  (`check`, `checkFunction`), Check.Infer (expressions), Check.Call (calls
  and constructions), Check.Arms (`checkMatch`), Check.Match (patterns;
  `checkPattern` keeps its old signature, from a fresh state),
  Check.Require (`require`/`expectType` by unification, `typeName`),
  Check.Scheme (state, instantiation, holes), Check.Walk (IR type
  traversal), Check.Comparable (comparison groundness).
- State: `{ subst, next }` threaded explicitly through `infer` in Either;
  arrays are threaded by a private applicative (`threadAll`), whose
  traverse is balanced, so 5,000 arms and 10,000 arguments stay linear and
  stack-safe. During checking a checked-IR `Hole m` is the meta m.
- A function: parameters bind rigid types; the body is inferred, every
  former type equality now a unification in the same order (arguments all
  inferred, then unified; `if` else against then; arms against the first);
  the result unifies; the resolved body's comparisons must be ground (rigid
  variable: E_TYPE `Type <t> is not comparable`; otherwise a hole: E_TYPE
  `Ambiguous type <t> in comparison`; pre-order, at the left operand); then
  unsolved metas are renumbered `Hole 0, 1, …` per function in
  `foldTypes` pre-order. Each use of a function instantiates its
  `variables`, each constructor its owner's `parameters`; `Call` and
  `Construct` record the resolved instantiation in that order.
- Messages: E_TYPE `Expected <t>, found <u>` names both whole operands
  resolved under the substitution before the failing unification (not
  Unify's innermost pair); `InfiniteType` names the meta (`_`) and the
  resolved containing type. Domain.Problem gains `NotComparable` and
  `AmbiguousType` (E_TYPE). The constructor-pattern arity guard (an
  internal error) now runs before the owner lookup and unification.
- Regression row `branch` now targets Features.Check.Infer's
  `checkConditional` (still one target, same defect); docs/engineering.md
  and docs/architecture.md updated.
- Tests: test/poly-check.test.mjs, 16 tests: the brief's rows (rigid
  mismatches, occurs, not comparable at `a` and `List(a)`, ambiguous
  `Nil == Nil` and `Proxy == Proxy`, literal pattern on `a`), plus a
  constructor pattern on `a`, whole-type messages (`Pair(Int, Int)` versus
  `Pair(Int, Bool)`, `Maybe(List(_))`), rigid beside a hole; checked-IR
  rows: `pair(id(1), id(true))` records `[Int, Bool]` (and `[Int]`,
  `[Bool]`, rigid `[a, b]` inside `pair`), `length(Nil)` `[Hole 0]`, dense
  per-function hole numbering, and a pattern's instantiated type.
  test/diagnostics.test.mjs and every adt-* test pass untouched.
- RED: `node --test test/poly-check.test.mjs` on the pre-change build: 16
  of 16 failed (.build/p001-task4-red.log; the final file, rerun against
  HEAD c6e87bc in an isolated copy: 16 of 16 failed,
  .build/p001-task4-red-final.log). GREEN: 16 of 16.
- GREEN: `rm -rf output && npm run verify` exit 0, 96.3 s wall, zero
  warnings, 211
  tests (195 + 16), zero failures/skips, eight regression proofs
  (.build/p001-task4-verify.log).
- Measurements (checking only, warm Node default stack): existing
  depth-forms at 128 and 20,000 declarations: deepest checked type 1;
  `id` nested 128: 1; `wrap(x: a): L(a)` nested 127: 128; `deep(x: a):
  L^127(a)` nested k: checks at k = 40 (5,081 deep), RangeError in
  Unify `resolve` from k = 44 — within every source limit (now E_NESTING
  after fix round 1, below; BACKLOG E006,
  .build/p001-task4-measure-depth.log). `dup(x: a): Pair(a, a)` nested
  12/16/20: 21 ms / 208 ms / 3.2 s, doubling per level (BACKLOG E007,
  .build/p001-task4-measure-dup.log).
- Fix round 1 (review approved; ruling R7, the compiler must not crash on
  a legal program): `inferredTypeLimit = 1000` in Features.Check.Unify. A
  type deeper than that is E_NESTING `Inferred type nesting exceeds 1000
  levels` (Problem `TypeTooDeep Int`). The decision is `exceedsLimit`, a
  stack-safe explicit-stack walk that stops past the limit. It runs on each
  expression's type when it is built (Infer `infer`, at that expression),
  on both operands before each unification and on each binding before the
  occurs check (Unify `Failure` `TooDeep`), and on every type of a finished
  body before it is resolved (Scheme `firstTooDeep`, at the holder's span).
  Also two tests: one constructor at two types in one function, and the
  left-to-right first error `g(1, true)`. `matchCtor` and `checkMatch` are
  split to stay within the declaration budget (`fieldsAgainst`,
  `checkArms`, `laterArm`). Comments now explain the two `Infer` rows and
  mark the `checkPattern` test seam. Walk's `foldTypes` passes spans.
- Fix tests: test/poly-depth.test.mjs, 6 tests: the limit constant; a type
  exactly 1,000 deep checks; 1,001 deep is E_NESTING at the eighth `deep`
  from the inside; `deep(x: a): L^127(a)` nested 44 and 127 deep are
  E_NESTING at the same call (each under 5 s, about 2 ms); a type that
  deepens after it is built is caught by the final bound at `sink`'s call.
  test/poly-check.test.mjs gains 2 tests (18).
- Fix RED: the 6 depth tests fail on HEAD 19ac4a9 in an isolated copy: 5
  fail (RangeError at 44 and 127; no diagnostic at 1,001 or for the late
  deepening; the limit is undefined). The exact-1,000 row passes there,
  because the old code had no bound to trip
  (.build/p001-task4-fix1-red.log, .build/p001-task4-fix1-red-head.log).
  With the final bound disabled in an isolated copy, the late-deepening
  test fails (.build/p001-task4-fix1-mutant-final-pass.log). The two
  poly-check additions pass on the Task 4 code too. They pin behavior
  already correct, so they have no RED.
- Fix GREEN: `rm -rf output && npm run verify` exit 0, 77.2 s wall, 219
  tests (211 + 8), zero failures/skips, eight regression proofs
  (.build/p001-task4-fix1-verify.log). Re-measured: `deep` nested 8 to 127
  is E_NESTING in 2–3 ms. `dup` nested 12/16/20 now takes 42 ms / 441 ms /
  6.8 s (BACKLOG E006, E007 updated).
- Fix round 2 (re-review: R7 partially addressed). Within one unification,
  metas bound at earlier positions chained into each other. Two operands,
  each bounded beforehand, then unified as chains about 1,780 levels deep,
  and unify's recursion threw a RangeError. Unify now threads a level
  (`unifyAt`, one level per applied type, which equals resolved depth) and
  fails with `TooDeep` past `inferredTypeLimit`. A Mismatch whose pair is
  too deep to resolve also fails with `TooDeep`. The span is the expression
  whose unification failed (Require `expectType`, the actual operand).
  Tests:
  - poly-depth: two links of deep^7 and three links of deep^4 are
    E_NESTING at `same`'s second argument.
  - poly-depth: a binding made too deep within its own unification (bindMeta
    `TooDeep`) is E_NESTING at `same`'s second argument.
  - unify: 1,000 levels unify; 1,001 fail with `TooDeep`.
- Fix-2 RED (.build/p001-task4-fix2-red.log):
  - The two-link case threw a RangeError.
  - The three-link case reported E_NESTING at the second arm's pattern `Z`,
    not at the failed unification.
  - The unit test unified 1,001 levels.
  - The bindMeta row already passed, because that branch existed but was
    untested.
- Fix-2 mutants, each in an isolated copy (.build/p001-task4-fix2-mutants.log):
  - Without the bindMeta bound, only the bindMeta row fails.
  - Without the level bound, the two chain rows and the unit test fail.
- Fix-2 margins: inside the checker, unify overflowed between 1,525 and
  about 1,779 levels; in unit context, between 2,218 and 2,250. The bound
  of 1,000 therefore leaves at least a 1.5x margin, not fix 1's 5x, which
  was resolve's figure.
- Fix-2 GREEN: `rm -rf output && npm run verify` exit 0, 65.9 s wall, 223
  tests (219 + 4), zero failures/skips, eight regression proofs
  (.build/p001-task4-fix2-verify.log).
- Fix round 3 (re-review): `bindMeta`'s strict `where` resolved the
  binding before `exceedsLimit` ran. Six or more L^997 links chained in one
  unification threw a RangeError in that resolve. The resolve and occurs
  check now live in `bindBounded`, which runs only after the bound.
  - Test: poly-depth `six chained links of L^997 are E_NESTING, not a
    crash`, at `same`'s second argument.
  - RED: RangeError in `resolve` (.build/p001-task4-fix3-red.log).
  - Reviewer probe /private/tmp/claude-501/probe-t4r2/eager.mjs at 2, 6, 8,
    12 and 20 links: all E_NESTING.
  - Audit of compiled Features.Check*: the remaining strict bindings that
    recurse over a type run only on bounded types (Comparable `variables`,
    Check `settled`, `bindBounded` `resolved`).
  - Unify's `inferredTypeLimit` comment now names unify as the binding
    limit.
  - GREEN: `rm -rf output && npm run verify` exit 0, 64.7 s wall, 224
    tests, zero failures/skips, eight regression proofs
    (.build/p001-task4-fix3-verify.log).
- Known gap: coverage of a constructor's fields at an applied type (for
  example `match m { Just(n) => n, Nothing => 0 }` over `Maybe(Int)`)
  is E_INTERNAL `Coverage of a type variable` until Task 6.
- Phase reached: these tests reach Check only (`checkedPoly`,
  `checkRejectedAt`). The CLI still rejects polymorphic programs until
  Task 7 (Specialize: E_INTERNAL `unspecialized type`).

### Task 5: the instantiation rule (2026-10-08)

Language change: polymorphic recursion and nested datatypes that would
make specialization infinite are rejected (design §4.1). Status: done.

- Check order: typing, then the instantiation rule, then coverage.
  `instantiationRule ∷ Checked.Program → Either Diagnostic Unit`
  (Features.Check.Instantiation) judges types first, in declaration order
  (Features.Check.Nested), then each function's calls in pre-order. Inside
  a strongly connected component of the call graph or of the type
  reference graph (an edge for every declared type a field mentions, at any
  depth), each type argument must be a bare variable of the referrer or
  mention no variable; a hole counts as ground.
- Diagnostics: new ErrorCode `SpecializationError` (wire E_SPECIALIZATION).
  `PolymorphicRecursion f` → `Recursive call to <f> changes its type
  arguments`, at the call; `NestedDatatype t` → `Recursive use of <t>
  changes its type arguments`, at the offending nested reference, found
  by walking the resolved field alongside `CtorInfo.fieldSyntax`.
- Features.Check.Components: `components ∷ Array (Array Int) → Array Int`,
  iterative Tarjan (explicit frame stack, self tail calls, Data.Map and
  Data.Set state), numbered in closing order.
- Function names: the message names the callee, so Resolved, Checked and
  IR `FunctionDecl` gain `name` (Specialize copies it so the identity test
  still compares checked and monomorphic IR unchanged; Go ignores it).
- Tests: test/poly-termination.test.mjs, 23 tests: the brief's accepted
  rows (`length(t)`, mutual `even`/`odd`, swapping, dropping, ground
  substitution, Rose/Forest, `T(b, a)`) plus a hole as ground and wrapping
  into another component (functions and types); rejected rows with exact
  code, span and text (self and mutual `List(a)` calls, §4.3's
  conservative case, `Pair(x, 1)`, first offence in pre-order, `Nest`,
  the nested `W(Pair(Int, a))` reference, mutual types, types before
  functions); generator coverage; 200 generated components accepted and
  each wrapped variant rejected at its call; components against a
  brute-force reachability oracle (300 graphs); 20,000-node chain and
  cycle under 5 s each (about 0.23 s for both). test/poly-components.mjs
  exports the generator (ruling R3): per component its functions,
  arities, calls (variable or ground arguments) and `groundTypes`, plus
  `render` and `wrapped`, for Task 8's bound.
- RED: with the components import stubbed (the module did not exist), 12
  of 23 failed: every rejection row, the generated wrapping test and both
  components tests (.build/p001-task5-red.log). The accepted rows and the
  generator check passed there, as they pin non-rejection. Mutants in an
  isolated copy: a rule that admits nothing fails every accepted row
  (.build/p001-task5-mutant-overreject.log); ignoring components fails
  both cross-component rows, the nested `W` row and the generated test
  (.build/p001-task5-mutant-components.log); treating holes as variables
  fails the hole row and the generated test
  (.build/p001-task5-mutant-hole.log).
- GREEN: `rm -rf output && npm run verify` exit 0, 66.4 s wall, 247 tests
  (224 + 23), zero failures/skips, eight regression proofs
  (.build/p001-task5-verify.log).
- Known gap: `length(t)` and `even`/`odd` match on `List(a)`, which still
  ends in E_INTERNAL `Coverage of a type variable` until Task 6; the test
  accepts exactly that diagnostic for those two rows (coverage runs after
  the rule, so reaching it proves the rule accepted). Task 6 should make
  them plain acceptances.
- Phase reached: these tests reach Check only (`checkRejectedAt`,
  `check`). The CLI still rejects polymorphic programs until Task 7.

### Task 6: coverage over applied types (2026-10-08)

Language change: matches over applied types (`List(a)`, `Maybe(Void)`,
`List(List(Int))`) and over type variables are checked for exhaustiveness
and redundancy (design §5); the E_INTERNAL `Coverage of a type variable`
gap is gone. Status: done.

- Features.Check.Expand: `expand ∷ Array TypeInfo → Array CtorInfo →
  Array (Ty Open) → Lookup Expansion` numbers every application reachable
  from the roots by unfolding constructor fields (finite by Task 5),
  keyed with variables forgotten (rigid variables and holes are one
  abstract type), and builds monomorphic-shaped `types`/`ctors` tables
  over those numbers: application fields as `TData (TypeId n) []`, the
  abstract type as Int (inhabited, no data). Discovery is a `tailRecM`
  loop of one round per frontier, so it is stack-safe. Roots: every data
  type the bodies carry (Features.Check.Walk `foldTypes`, deduplicated in
  a Set) plus every declared type whose constructors mention no variable,
  so inhabitation still settles over every monomorphic declaration.
- Signature: `buildSignature` runs the unchanged `inhabitation` fixpoint
  on the expanded tables; `candidates` maps an application's inhabited
  expanded constructors back to the declared ones (declaration order) and
  gives rigid variables and holes no heads; `fieldTypes ∷ Signature →
  Ty Open → Head → …` substitutes the column's type arguments. Matrix
  `complete` treats a variable column like Int (never complete). Witness
  format unchanged (constructor names only).
- Tests: test/poly-coverage.test.mjs, 19 tests through Parse, Resolve and
  Check: exhaustive `Nil`/`Cons(_, _)` over `List(a)`, a binder over `a`,
  binders under constructors over `a`, `Nothing` alone over `Maybe(Void)`,
  `Maybe(Maybe(Void))`, a hole column, nested heads through
  `List(List(a))`; E_TYPE for `Nothing` over `a` (Task 4 guard); exact
  witnesses `Cons(_, Cons(_, _))` and `Cons(Cons(_, _), _)` through
  `List(List(Int))`, `Pair(_, false)`, `Nothing`, `Just(_)`, `Cons(_, _)`
  over a hole; redundant `_` after a binder and after `Nothing` over
  `Maybe(Void)`; a generic function with a non-exhaustive match called at
  two types reports one diagnostic at the match span; five arm sets over
  `Maybe(Void)` give the same verdict as monomorphic `type MV = N |
  J(Void)` (ADR 003); a 3,000-type parameterized chain where `Dead` needs
  an arm only for `U(Int)` and `U(a)`, not `U(Void)`, each under 5 s
  (about 1.1 s for the test).
- R12: test/poly-termination.test.mjs's `length(t)` and `even`/`odd` rows
  now require plain acceptance; no poly-* test tolerates E_INTERNAL.
- RED: the new test against the pre-change source (src restored, rebuilt):
  14 of 19 failed (six with E_INTERNAL `Coverage of a type variable`; the
  `Maybe(Void)` rows and the chain because inhabitation was per declaration,
  not per application) (.build/p001-task6-red.log). The five that passed
  pin behavior the old code already had (the E_TYPE guard and witnesses
  whose types need no variable column).
- GREEN: `rm -rf output && npm run verify` exit 0, 266 tests (247 + 19),
  zero failures/skips, eight regression proofs; coverage.test.mjs,
  coverage-scale.test.mjs and adt-coverage.test.mjs unchanged and passing
  (10,000-type chain 1.10 s, was 0.89 s in Task 5's log)
  (.build/p001-task6-verify.log).
- Phase reached: these tests reach Check only (`checkedPoly`,
  `checkRejectedAt`, `check`). The CLI still rejects polymorphic programs
  until Task 7.

### Task 7: specialization (2026-10-08)

Language change: polymorphic programs now compile and run end to end
through the CLI (`npm run bumpus -- run examples/lists.bumpus` prints
`Pair(Cons(Pair(3, true), Cons(Pair(2, false), Nil)), Just(6))`).
Status: done.

- Features.Specialize replaces the Task 1 seam: `specialize = specializeWith
  TInt`; `specializeWith ∷ Ty Void → …` (hole representative, for tests);
  `specializationKeys` returns `{ declaration, function, arguments }`, types
  then functions, each in output-id order. Design §6 worklist: seeds are
  every monomorphic type (its fields may reference applications) then every
  monomorphic function, in id order; a single first-in first-out list of
  work items, filled by a `tailRecM` loop; each body is copied in pre-order
  (signature, then an expression's type, a call's instantiation, its
  callee, its arguments; a pattern's type before its fields), and a key is
  created on first reference. Monomorphic declarations keep their order and
  take the first output ids, so monomorphic programs come out unchanged.
  A polymorphic declaration never reached is not emitted.
- R15: keys are hash-consed. Each ground application is numbered once as an
  output type (`Map (Tuple Int (Array IR.Ty)) Int`; IR.Ty gains `Ord`), so
  a key compares in time linear in its arity; `specializationKeys`
  rebuilds `Ty Void` arguments from those numbers.
- Limit: `specializationLimit = 10000` counts only keys of polymorphic
  declarations (function instantiations and parameterized type
  applications); the reference that would create key 10,001 is
  E_SPECIALIZATION `More than 10000 specializations` (Problem
  `SpecializationLimit Int`). A key found in a constructor field is
  reported at its own nested reference (field syntax walked alongside, as
  Check.Nested does).
- Modules: Specialize (API, loop), Specialize.Seeds, .Keys, .Lower, .Body
  and .Copy (a state-and-failure applicative whose Apply does not use Bind,
  so Array's balanced `traverse` keeps wide bodies in shallow stack). Copy
  is a sixth module beyond the plan's Keys and Body. Format.Go needed no
  change: specialized constructors carry source names, so values print and
  re-read (`Cons(Pair(1, true), Nil)`).
- Tests: test/poly-run.test.mjs, 27 tests, one Go batch of 23 programs:
  every §9 function of examples/lists.bumpus printed from `main`; Review
  Focus 1–5 (namespaces `a(5)` → 5; `loop()` fixed by context → 1; `zip`
  value printed and re-read → `Cons(Pair(1, true), Nil)` both ways; an
  8,192-element list from generic `append`, counted by generic `length` →
  8192; `xs < Cons(2, Nil)` inside a generic function → true); `length` at
  `List(Int)` and `List(Bool)` in one program → `Pair(1, 2)`; `length(Nil)`
  → 0 with a single `length` key at Int; exact key order for a small
  program; an uninstantiated polymorphic function and type are not
  emitted; the limit (compile only): 6,000 function keys + 4,000 type keys
  + 500 monomorphic functions and types compile, one more function key and
  separately one more type key fail at `gx(1)` and `QX(1)`.
  test/large-source.test.mjs: 3,000 distinct instantiations (3,000
  function and 3,000 type keys) compile in about 0.6 s (bound 5 s); the
  20,000-declaration programs are unchanged and pass.
  test/compiler.test.mjs: bootstrap/lists.go snapshot and CLI run.
  test/specialize.test.mjs: identity now skips the one polymorphic example
  by name (its count assertion is unchanged).
- bootstrap/lists.go generated with `npm run bumpus -- emit
  examples/lists.bumpus bootstrap/lists.go` and reviewed (types numbered in
  discovery order, `Pair(Int, Bool)` first from `main`'s signature;
  constructors in contiguous blocks; one compare and show helper per
  specialized type; Bool helper emitted). answer.go, shapes.go and tree.go
  are byte-identical (CLI re-emit `cmp`, and their snapshot assertions).
- RED: the new poly-run file failed to load (`specializationKeys` not
  exported); with that import stubbed, all 27 tests failed (the Go cases
  with E_INTERNAL `unspecialized type`, the key tests on the stub); the
  limit test first failed on its own syntax (`match` as a `+` operand, now
  parenthesized), then with `unspecialized type`; the 3,000-instantiation
  test failed with `unspecialized type` (.build/p001-task7-red.log,
  .build/p001-task7-red-limit.log).
- GREEN: `rm -rf output && npm run verify` exit 0, 295 tests (266 + 29),
  zero failures/skips, eight regression proofs
  (.build/p001-task7-verify.log).
- Phase reached: these tests run the whole pipeline (`compile`, the CLI and
  Go). Task 8 adds the specialization properties.

### Task 8: specialization properties (2026-10-08)

Language change: none (tests only). Status: done.

- test/poly-properties.test.mjs, 7 tests, one Go batch of 90 packages
  (30 generated programs, each as generated, with declarations reversed,
  and with Bool as the hole representative); the file runs in about 10 s.
  - execution oracle: each of the 30 programs prints in Go what the
    reference interpreter computes;
  - uniqueness: no two `specializationKeys` are equal (normalized keys
    such as `fn f0[List(List(Int))]`), and every program has polymorphic
    keys;
  - determinism: `compile` twice gives equal Go; the reversed program
    prints the same and has the same normalized key set (sorted arrays,
    declaration and type ids replaced by source names);
  - representative independence: `specializeWith TBool` and `specialize`
    emit different Go for every program (the holes reach specialization)
    and both print the same;
  - termination bound (design §4.2): Task 5's 200 components, each entered
    once from `main` at a random function and random ground arguments
    (Task 5's four plus `List(List(Bool))` and `List(List(_))`); keys per
    component ≤ Σ_{d∈C} |T|^arity(d) with T = the entry's arguments ∪ G_C,
    holes normalized to their representative Int (Task 5's `List(_)`
    reads `List(Int)`), and every key's arguments lie in T. `outside`'s
    keys are not counted (its own component). The bound is often reached
    exactly. Component programs are only counted, never run (R13);
  - two self-checks that do not depend on specialization: the interpreter
    against known outputs (examples/lists.bumpus, int32 wrap, constructor
    order), and the generator mixes permuted and dropped type arguments
    in calls between generic functions, recursion that runs (at least a
    third of the programs make a self call at run time), a hole in every
    program, and `main` instantiations at `List(List(Int))` beside
    `List(List(Bool))` and `Pair(Int, Bool)` beside `Pair(Bool, Int)` of
    the same function.
- Helpers (each under the 250-line limit): test/poly-parse.mjs and
  test/poly-oracle.mjs, the reference interpreter (own tokenizer and
  recursive-descent parser, type syntax read and dropped; untyped values,
  int32 `+`, strict left-to-right, ADR 005 order), sharing no compiler
  code; test/poly-types.mjs, test/poly-expressions.mjs and
  test/poly-programs.mjs, the type-directed generator (List, Pair and a
  generated G whose recursive fields keep or swap its parameters; four
  generic functions calling only earlier ones, with self calls only on a
  part of the recursion parameter, so every program terminates);
  test/poly-keys.mjs, keys by source name. test/poly-components.mjs:
  `render` takes an optional `entry` in place of `main`. The brief named
  one helper file; it is split to respect the size target.
- RED: with `specialized` stubbed to return `Left` (temporary edit,
  reverted), the five properties failed and the two self-checks passed
  (.build/p001-task8-red.log). A second temporary mutant, function keys
  looked up with every applied-type argument treated as equal, failed the
  execution oracle, determinism and representative tests (the batch's Go
  no longer compiled) (.build/p001-task8-mutant-key.log); uniqueness and
  the bound do not catch that mutant, because it reuses keys rather than
  duplicating them.
- GREEN: `rm -rf output && npm run verify` exit 0, 302 tests (295 + 7),
  zero failures/skips, eight regression proofs
  (.build/p001-task8-verify.log).
- Phase reached: the whole pipeline (`compile`, `specializeWith`,
  `specializationKeys`) and Go for the generated programs; the
  components through Specialize only.

### Task 9: regression proofs and documentation (2026-10-08)

Language change: none (regression rows and documentation). Status: done.

- Four regression rows in scripts/regression.mjs, each one needle in the
  current code, probes in test/regression-poly.mjs (imported by
  test/regression.mjs, which stays at 152 lines; each probe uses only the
  compiler it is given):
  - `occurs`: Features.Check.Unify `bindBounded`, `if mentions meta
    resolved then` → `if false then`. Healthy: E_TYPE `Infinite type: _
    occurs in List(_)`. Mutant: the cyclic binding is caught later by the
    depth bound, E_NESTING `Inferred type nesting exceeds 1000 levels`, so
    the probe fails `occurs check missing`.
  - `rigid`: Unify `unifyHeads`, the rigid-with-same-rigid arm →
    `TVar (Rigid _), _ → Right subst` plus `_, TVar (Rigid _) → Right
    subst`. Healthy: `fn f(x: a): Int = x;` is E_TYPE `Expected Int, found
    a`. Mutant: accepted (`rigid variable unified with Int: null`).
  - `instantiate`: Features.Check.Scheme `instantiate` no longer advances
    the meta counter (`, state: state { next = … }` → `, state: state`), so
    later uses reuse the same metas. Healthy: `pair(id(1), id(true))`
    prints `Pair(1, true)`. Mutant: rejected (`scheme metas shared across
    uses: probe program was rejected`).
  - `spec-key`: Features.Specialize.Keys `applied` keys each data-type
    argument as `TData (TypeId 0)` (Int and Bool kept). Healthy: the
    `length` program over `List(List(Int))` and `List(List(Bool))` prints
    `Pair(1, 2)`. Mutant: Go build fails (`cannot use … (value of struct
    type bumpusTy1) as bumpusTy0 value`), probe fails `nested
    specialization keys collided`.
  Evidence: .build/p001-task9-mutants.log (each probe exit 0 on the healthy
  build, exit 1 with its message on its mutant).
- RED/GREEN for the rows is the regression script itself: each row asserts
  the healthy compiler passes and the isolated mutant fails with the row's
  message. `node scripts/regression.mjs`: twelve `Regression proof (…)`
  lines, 43.5 s wall.
- Docs: docs/adr/007-specialization.md (new: phases, typing, holes and the
  representative with the four validity conditions, opaque variables and
  comparison groundness, the instantiation rule with the §4.2 proof and
  §4.3 conservatism, the inferred-type depth bound with measured margins
  and the default-stack assumption, hash-consed keys, the limit's
  accounting, the R18 span deviation); docs/language.md (grammar, types,
  a Polymorphism section: scoping, rigid/flexible, holes, groundness,
  patterns and coverage, the rule, depth bound, limit; lowercase `int` is
  a variable); docs/architecture.md (final pipeline and phase list, depth
  bound, P001 test files, new rows); docs/engineering.md (test count, the
  four rows); BACKLOG.md (P001 Done on p001; E006 and E007 updated; new
  E008 Expand keys, E009 `did you mean Int?` hint, E010 `_` in mismatch
  messages, E011 near-limit diagnostic elision); docs/findings.md (P001
  observations); README.md (ADR 007 link); docs/next-session.md.
- GREEN: `rm -rf output && npm run verify` exit 0, 85.3 s wall, zero
  warnings, 32 test files, 302 tests, zero failures/skips, twelve
  regression proofs (.build/p001-task9-verify.log).

### P001 summary

Rank-1 polymorphism is implemented on branch p001 (Tasks 1-9, commits
959a7d1 onward). Parameterized types and generic functions type-check with
rigid signature variables, fresh metas per use and occurs-checked
unification; comparisons need ground operand types; unsolved metas are
holes that Specialize fills with Int; the instantiation rule makes the set
of specializations finite; coverage works over applied types; inferred
types are bounded at 1,000 levels (E_NESTING, never a crash); a pure
Specialize phase produces the variable-free monomorphic IR with
hash-consed keys and a 10,000-key limit. Monomorphic programs emit
byte-identical Go. Tests grew from 162 to 302 and regression proofs from
eight to twelve. ADR 007 records the decisions (rulings R1-R19 in the
plan's ledger). Open follow-ups: BACKLOG E006-E011. Pending: final
whole-branch review and the user's approval to merge; FN001's currying
direction is to be discussed with the user before its design.
