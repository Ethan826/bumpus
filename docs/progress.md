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
eight to twelve. ADR 007 records the decisions (rulings R1-R20 in the
plan's ledger). Open follow-ups: BACKLOG E006-E011. Pending: final
whole-branch review and the user's approval to merge; FN001's currying
direction is to be discussed with the user before its design.

### P001 final review fixes (2026-10-08)

The final whole-branch review (verdict: with fixes) found one Important
issue and several minors; all were fixed in one commit on p001.

- Unify meta chains (Important). `unifyHeads` bound the left (older) of
  two unbound metas to the right (newer), so sibling metas joined in turn
  formed one chain as long as the siblings, which every later `walk`
  followed: quadratic. Now the newer (larger id) is bound to the older;
  self-binding, the depth bound and the occurs check are unchanged
  (`bindMeta` still decides the bound before `bindBounded` resolves). New
  tests in test/large-source.test.mjs, 5 s bound: 5,000 match arms of
  `Nothing` (then `_ => Just(0)`) and 4,000 `Nil` arguments to
  `f(x0: b, …)`. RED (before the fix, built output): 15.8 s and 8.5 s;
  GREEN: 1.55 s and 0.15 s. A first `Nothing` followed by `Just` arms grows
  no chain (1.6 s before the fix too), so the test uses all-`Nothing` arms.
- The reviewer's one unexplained `actual false, expected true`. Reproduced
  by running the eight P001 test files three at once: it is the 5 s timing
  bound of poly-depth `an inferred type exactly 1000 deep checks`, which
  took 2.9 s alone and 7.0-9.0 s under that load. It does not depend on
  binding direction (2.8 s with either). Profiling showed nearly all of
  that time in `Ord (Ty Unit)` comparisons of Features.Check.Expand's
  whole-type map keys, 1,000 applications nested up to 1,000 deep. Expand
  now keys its numbering by a canonical string spelling of the key (one
  native string comparison) and keeps number-to-key in a second map:
  2.8 s to 0.35 s alone, 1.9 s under the same triple load, where it no
  longer fails; the 3,000-application coverage chain is 0.72 s to 0.65 s.
  This is a constant-factor fix; hash-consed keys (BACKLOG E008) remain
  the asymptotic one. The same triple load also failed Go batches,
  because concurrent runs of one test file in one checkout share
  .build/go-batches/<id> (BACKLOG T002); verify runs each file once.
- poly-check rejection rows now also run through `compile` (support.mjs
  `rejectedAt`), asserting the same code, span and text (design §8,
  "through the CLI"); the Check-level rows stay.
- Components: unreachable fallbacks are gone or report E_INTERNAL. A
  frame carries its node's order and low and `open` maps each open node to
  its order, so no lookup can miss; an edge to a node outside the graph,
  a component root missing from the stack and an unnumbered node stop the
  search with E_INTERNAL (`components` returns `Either Diagnostic`). New
  test: an edge to a missing node is E_INTERNAL; the reachability and
  20,000-node tests pass unchanged in substance.
- Docs: ADR 007 and next-session cite rulings R1-R20; README describes
  P001 as implemented without branch status; docs/language.md places the
  occurs-check E_TYPE at the argument `t`.

Verification: `rm -rf output && npm run verify` exits 0 in 90 s wall
(97 s on an earlier run) with 318 tests (302 + 2 timing + 1 E_INTERNAL +
13 compile twins), zero warnings and twelve regression proofs
(.build/p001-final-fix-verify.log). The eight files (`node --test test/unify.test.mjs test/poly-*.test.mjs
test/diagnostics.test.mjs`, 153 tests) passed three sequential runs
(.build/p001-final-fix-run{1,2,3}.log).

## P001 merged (2026-10-08)

User approved the merge (no push). main fast-forwarded from 79c2327 to
dcb40fb (P001 Tasks 1-9, the final-review fix wave, and the merged main
direction commits). Clean `rm -rf output && npm run verify` on main exited
0: zero warnings, 318 tests, zero failures/skips, twelve regression
proofs. Raw log: .build/p001-merge-verify.log. Per-task logs, briefs,
reports, review packages and the ledger (rulings R1-R20) archived under
.build/merged-p001-evidence; worktree and branch removed. Next: FN001,
starting with the currying discussion recorded in BACKLOG.

## FN001 direction settled (2026-10-08)

Discussed with the user before any design decision, as BACKLOG required.
Settled: curried semantics with Algol-like multi-argument syntax as
proposed (partial application, over-application, under-application
becomes a function-typed value with a `missing N argument(s)` hint
replacing today's under-application E_ARITY); lambdas `fn(x) => body`
reusing `fn` and `=>`, parameter annotations optional and inferred
locally; `|>` included in FN001 (left-associative, below comparison),
`>>`/`<<` wait for a Prelude; no local binding form in FN001 (separate
item), so closures capture parameters and pattern variables by value.
Design draft written the same day:
docs/plans/2026-10-08-functions-design.md (syntax, names, typing, declared
arity, evaluation, instantiation rule, canonical uncurried Go
representation with adapters, tests and regression probes, deliberate
diagnostic changes, four open questions). Not reviewed or approved; no
plan, no code. Next: the user's review of the draft.

## FN001 design revised after the user's review (2026-10-08)

The user's review of the first draft: revise before approving. The
canonical uncurried representation (`A -> B -> C` as `func(A, B) C` with
adapters) lost declared-arity timing: with `fn stuck(n: Int): Int -> Int
= stuck(n);` and `use(f) = drop1(f(1))`, `use(stuck)` must diverge but
the adapter made `f(1)` a partial application returning 0; lambda
eta-expansion delayed bodies the same way, and the draft's "delays
nothing observable" claim was wrong. Revision: nested Go function values
`func(A) func(B) C`, staged wrappers for named functions and constructors
used as values, direct saturated calls unchanged; declared arity is a
stage boundary; pipe evaluates its left operand first (kept as a `Pipe`
IR node); constructors are curried values; `_` discards lambda
arguments; the under-application hint is narrow with provenance rules;
timing tests use instrumented bounded panics, never stack exhaustion;
arrow spines are depth-flat, traversed iteratively, named Go function
types keep text linear, scale tests at 5,000 parameters. Section 12 of
the design maps each finding. Not yet approved; no plan, no code.

## FN001 design approved; plan drafted (2026-10-08)

The user approved the revised design and asked for the plan. While
writing it, the section 8 `go build` question was measured on
hand-written Go (scratchpad, Go 1.26.4): nested-closure staged wrappers
took 1.3 s at 50 parameters, 2.6 s at 100, 13.9 s at 200, 221 s at 300,
and did not finish within 10 minutes at 1,000; an environment struct
copied per stage took 1.1 s at 300 and 1,000 and 12.8 s at 5,000. A
parameter bound is not viable (large-source already checks a
20,000-parameter declaration). Recorded as design Amendment A1 (section
13, proposed): no nested Go closures; staged wrappers and every lambda
lifted to top-level stage chains over linked environments; meaning and
types unchanged. Plan: docs/plans/2026-10-08-functions-plan.md (nine
tasks; Task 1 re-measures the linked environment before any lowering
code). Awaiting the user's confirmation of A1 and review of the plan.
No code.
Verify for this docs change: first run failed one timing test (match
ladder 1,830 ms over its 1.5 s bound under external load, 471 ms alone;
.build/fn001-plan-verify.log), recorded as BACKLOG T003 before
re-running; second run exit 0, 318 tests, twelve regression proofs, the
ladder at 752 ms (.build/fn001-plan-verify-2.log).

## FN001 plan approved with changes (2026-10-08)

The user approved A1's architecture (top-level stages, immutable
environments) and the nine-task structure with three changes, applied to
the plan: Task 1 has no quadratic fallback (if the linked environment
fails its linearity thresholds, stop and reconsider with the user) and
benchmarks runtime with repeated applications, every argument consumed,
explicit build/run timeouts; equality, ordering and type interning are in
the scale work (hand-written spine-iterative `Eq`/`Ord` for both `Ty`s in
Tasks 2 and 5, arrows hash-consed in Specialize.Keys, Go function type
names numbered from interned suffixes in Task 6, a 5,000-parameter
function type as a generic argument in Tasks 5 and 8); the core timing
probes move into Task 6's first step, Task 7 keeps the interpreter and
generated comparisons. Accepted diagnostic adjustments now in the design
(§2, §4, §9): over-application past a non-function and `f()` keep
E_ARITY `Wrong number of arguments`; `x()` and `N()` keep E_NOT_CALLABLE.
Task 1 (measurement only) authorized in .worktrees/fn001.

## FN001 Task 1: linked-environment measurement (2026-10-08)

Branch fn001 (.worktrees/fn001). Added scripts/stage-shapes.mjs (Go
generator: linked, copied, nested; attribution baselines direct, bare,
idle, chain; remedy candidates shared, packed) and
scripts/stage-probe.mjs (explicit build/run timeouts, repeated
applications with every argument consumed, checksums recomputed in
JavaScript, growth-exponent verdict). Every run's checksum matched. The
first verdict line ("linear") was wrong: its ratio bound admitted a 16×
build for 4× n; replaced by the exponent bound before any decision. Result
(design §13 "A1 measurement"): the linked environment fails the build
bound (k = 1.92 with the statement driver, 1.74 without applying it);
run time is linear. Attribution: the last stage's `n`-local unpack and
`n`-argument call; a packed calling convention fixes the staged value
(k = 1.23 including a k = 1.52 floor of types and `f`). Applying a value
to `n` arguments in one Go function is k ≈ 2 in every shape. Stopped per
the user's ruling: no representation adopted; decision returned to the
user. No compiler change.

## FN001 Task 1, round 2 (2026-10-08)

User authorized a second measurement round only. Added
scripts/stage-baselines.mjs (types, signature, body, call),
scripts/stage-mixed.mjs (mixed Int/Bool/pointer parameters, each read
twice out of order; today's n-ary convention, packed per-type arrays,
packed struct), scripts/stage-blocks.mjs (block-split application,
arguments evaluated in place), scripts/stage-order.mjs (order, body-entry
and shared-partial checks with expected output computed from the
semantics); probe reports total build times and an exponent per program.
All checksums matched; four order cases matched; a hoisting mutant of the
helpers failed the order check (scratchpad, not committed). Results in
design §13 "round 2": Go's growth is confirmed in large bodies (today's
convention, mixed body: 1.51 s / 33.6 s at 5,000 / 20,000); packed
arrays plus blocks of 64: 2.45 s / 19.2 s; homogeneous packed, blocks of
64: 2.08 s / 13.1 s; runtime linear. Nothing adopted; proposed Go bounds
returned to the user. No compiler change.

## FN001 Task 1 complete (2026-10-08)

The user approved the scale rule (Bumpus phases linear and stack-safe;
Go builds at most 10 s per program at 5,000 parameters in verify and
100 s at 20,000 in the milestone probe) and one final round, adoption
conditional on the shared-body bound and type-diversity allocation.
Added scripts/stage-shared.mjs. Round 3 (.build/fn001-task1/run5-*.log):
shared body with direct call, packed entry and a shared partial, total
build 3.4 s / 5.1 s at 5,000 (3 / 1,000 types) and 52.1 s / 80.0 s at
20,000; 49.3 / 52.0 bytes per stage; checksums matched. Both conditions
hold; convention adopted and written as design §13 rules 1-8; plan Task 6
interfaces and tests updated; conclusions narrowed ("tested large
bodies", not "no representation"). The 20,000 / 1,000-type build uses
80% of its bound. Next: Task 2.

### FN001 Task 2: the arrow type (2026-10-08)

Branch fn001. Behavior-preserving: no syntax produces an arrow yet.

- What changed: `Domain.Type.Ty` gains `TFun (Ty v) (Ty v)` with spine
  helpers (`spine`, `spineThrough`, `arrows`, `children`; a loop each, in
  Domain.Type itself since the instances need them). Eq, Ord and Functor
  are hand-written: arrow spines are walked in step by a loop, applications
  compare inline (the first version, through helpers, overflowed
  test/poly-depth `an inferred type exactly 1000 deep checks` in verify;
  fixed. Headroom figures are approximate (JIT variance): my probe gave
  `compare` the derived instance's spare frames at 1,000 levels and `==`
  about 8,700; the review measured `compare` at 8,592 spare frames in
  most runs but 6,249 in 2 of 10, and the pipeline's minimum stack for
  the poly-depth 1,000-deep case at about 559 KB both before and after).
  Bind (substitution) and `ground` walk spines by a loop. Unify: arrow
  against arrow unifies parameters at level + 1 and results at the same
  level in a `tailRec` loop entered only when both heads are arrows (list
  nesting stack headroom unchanged, measured); `resolve`, `exceedsLimit`
  and the occurs check follow the same measure. `Problem.FunctionName`,
  rendered right-associatively by a loop with function parameters
  parenthesized. Comparable: rigid, then hole, then a new function check
  through the new Features.Check.Functional (declared types whose fields
  reach an arrow, settled once per program over the reverse reference
  graph; a program with no arrow field builds no graph). Signature and
  Matrix treat an arrow column as abstract; Inhabited and Expand treat
  every arrow as inhabited and never unfold it; Expand spells arrows
  `f(…)`; Nested's reference graph enters arrows, and a resolved arrow
  field is an Internal field-syntax mismatch until Task 3 adds the
  syntax. Specialize.Lower: `Internal "unlowered function"`.
- Tests seen failing first (all three files failed to import `TFun` before
  the code): test/unify-arrow.test.mjs (7 tests: arrow against arrow;
  mismatch inside a parameter and a result; meta against an arrow and
  occurs through one; rigid against an arrow; a 5,000-long spine unifies
  and resolves; 1,001-deep parameter nesting is TooDeep while a 5,000-long
  spine is not; a meta bound through a spine), test/type-order.test.mjs (5
  tests: Eq/compare on equal and last-parameter-differing 20,000-long
  spines; substitution and `ground` on one; agreement with the derived
  order on 2,000 generated arrow-free pairs, whose reference was first run
  against the old derived instance and passed; arrow name rendering; a
  20,000-long name). test/unify.test.mjs and the independent oracle
  test/unify-oracle.mjs generate arrows; shared helpers moved to
  test/unify-support.mjs.
- Mutants (isolated copies in the scratchpad, not committed): result side
  counted +1 in `exceedsLimit`; parameters unified at the same level;
  recursive arrow equality; recursive, unparenthesized name rendering.
  Each fails at least one new test.
- Reach: unit level only (Domain.Type, Unify, Format.Diagnostic). The
  Comparable, Inhabited, Expand, Nested and Lower cases are covered by the
  checker identity until Task 4 can produce arrows.
- GREEN: `rm -rf output && npm run verify` exit 0, 330 tests (318 + 12),
  zero failures/skips, twelve regression proofs; bootstrap snapshots
  unchanged.
- Review fixes (commit after c4e9ed1): test/functional.test.mjs (3 tests:
  the fixed point through fields, mutual and through applied arguments;
  `containsFunction`; a 50,000-type chain under 5 s), seen failing on an
  isolated no-fixed-point mutant (seeds only: 2 of 3 fail); `spineThrough`
  can no longer file a result as a parameter (its unreachable arm adds
  none); a redundant Inhabited arm removed; a unify-arrow test renamed;
  headroom figures above reworded as approximate.

### FN001 Task 3: syntax and resolution (2026-10-08)

Branch fn001. No existing row changes; bare names and calls of locals keep
their P001 resolution until Task 4.

- What changed: Format.Lex lexes `->` and `|>` longest first. Domain.Syntax
  gains `FunRef`, `Lambda`, `Apply`, `Pipe`, `LambdaParam` and
  `typeRefSpine` (a loop). The type parser moved to the new
  Format.Parse.Type: an arrow chain is read as a list (Grammar
  `chainRight`, Cursor `rightAt`, a `tailRecM` loop) and folded right;
  `(A, B) -> C` flattens to `A -> B -> C`; a list of two or more types not
  followed by `->` is `Expected ->`, `()` is `Expected a type` at `)`.
  Nesting follows design §1 (parameter side +1, checked at its `->`;
  result side +0); type parentheses are one level while parsed (Cursor
  `groupedAt`) and none once closed, recorded in ADR 006's new FN001
  section. Format.Parse.Lambda parses `fn(x, _: T) => body` (`Expected a
  parameter`); Format.Parse.Expression adds `|>` (a `chainLeft1` over
  comparisons) and postfix application (Grammar `manyOn`; flattened by
  the review fixes below); a name call stays `Call`. Domain.Resolved
  gains `Lambda` (with `Param = { local, ty, span }`), `Apply` and `Pipe`;
  Features.Resolve.Lambda resolves parameters (E_DUPLICATE `Duplicate
  parameter x` at the first occurrence of the earliest repeated name,
  `fn(b, a, a, b)` at the first `b`, as for functions; `_` gets no
  LocalId; annotations against the signature's variables, E_UNBOUND
  `Unbound type variable b`); `resolveType` and `occurrences` walk
  written spines by loops. Check.Infer returns `Internal "unchecked
  function"` for the three new nodes. Check.Nested replaces Task 2's
  placeholder: an arrow field is judged beside its written spine
  (parameters and final result, paired by a loop), so a nested reference
  inside an arrow is reported at its own span. test/poly-parse.mjs (the
  oracle's own parser) reads arrow types, lambdas, postfix application and
  pipes, independently. Style gate: Format.Parse.Type and
  Format.Parse.Lambda join the applicative production modules. BACKLOG
  E003 notes two dispatches now over the branch target.
- Not added: Resolved `FunctionRef`/`CtorRef` expression constructors.
  Domain.Resolved's `GlobalRef` already has constructors of those names,
  so adding them needs that rename, which belongs with Task 4's bare-name
  resolution.
- Tests seen failing first (before any code): test/fn-syntax.test.mjs and
  test/fn-names.test.mjs, 43 tests, 42 failing and one passing (`1 +
  fn(y) => y` is `Expected an expression` at `fn` before and after, kept
  as a characterization row); test/fn-oracle-syntax.test.mjs, 2 tests,
  both failing. Added after the code, each shown to bite by an isolated
  mutant (scratchpad copy, not committed): `a parameter inside a
  parameter counts both levels` (mutant: a parameter contributes no level
  in `rightAt`), the `(Int -> L^127(Int)) -> Int` row (mutant: a result
  contributes a level), `127 further applications parse; one more is
  E_NESTING` (mutant: postfix application without `infixed`). Further
  mutants, each failing the named rows: type parentheses keeping their
  level (`128 nested parameter positions resolve`); no lambda duplicate
  check (both E_DUPLICATE rows); Nested arrow arm restored to a mismatch
  (all four arrow-field rows); no `Expected ->` lookahead (both rows).
- Plan Step 1's "each §2 table row" is covered for lambda parameters
  (bare local, shadowing a parameter, a function and by a match binder,
  `_`, duplicates, rigid and unbound annotations). The rows for bare
  function and constructor names and calls of locals change in Task 4
  (plan Global Constraints), so no interim outcome is pinned here.
- Reach: Parse → Resolve (test/phases.mjs); the Nested arrow-field rows
  run Check (`checkRejectedAt`, `checkedPoly`), whose programs contain no
  lambda, application or pipe.
- GREEN: `rm -rf output && npm run verify` exit 0, 380 tests (333 + 47),
  zero failures/skips, twelve regression proofs; bootstrap snapshots
  unchanged. Log .build/fn001-task3-verify.log.
- Review fixes (follow-up commit): I1, postfix chains are flattened into
  one `Apply` of every group's arguments in order (`g(1)(2)(3)` is `Apply
  (Call g [1]) [2, 3]`, exact under design §5), the callee one level
  deeper once per chain, replacing the per-group level, which made plan
  Task 8's 1,000-application chain E_NESTING. Seen failing first: the new
  row `a chain of 1000 postfix groups resolves to one Apply` failed with
  E_NESTING (NestingTooDeep 128 at the 129th group's `(`; log
  .build/fn001-task3-i1-red.log), as did the flattened shape and span
  rows; the 128-application E_NESTING row is removed. M1, ADR 006 states
  that a parenthesized type raises its contents' depth while parsed, with
  the four `L^127((Int -> Int))`/`L^128((Int))` rows in the new
  test/fn-depth.test.mjs (passing on arrival: they pin behavior). M2,
  design §1 clarifies empty value applications. M3, five FN001 forms in
  scripts/depth-forms.mjs (`functionForms`, named-only in
  depth-probe.mjs), checked at the limit and one past it through Resolve
  by test/fn-depth.test.mjs; the review's lifted-limit figures in ADR 006;
  plan Task 6 Step 3a re-measures them. M4, BACKLOG E003 trigger
  reworded. M5, the duplicate wording above, with a `fn(b, a, a, b)` row.
  GREEN: `rm -rf output && npm run verify` exit 0, 387 tests (380 - 1 + 8),
  zero failures/skips, twelve regression proofs, snapshots unchanged (log
  .build/fn001-task3-fix-verify.log).

### FN001 Task 4: checking (2026-10-08)

Branch fn001. Reach: Parse → Resolve → Check (test/phases.mjs,
test/fn-checked.mjs); one CLI row asserts that checked function programs
reach Specialize as `Internal "unlowered function"`.

- Resolution (design §2): Domain.Resolved's `GlobalRef` constructors are
  renamed `GlobalFunction FunctionId Int` (with the declared parameter
  count) and `GlobalCtor CtorId`, freeing `FunctionRef Span FunctionId`
  and `CtorRef Span CtorId` for expressions. A bare name is a local, else a
  function with parameters (`FunctionRef`), else a zero-parameter function
  (Resolve: E_ARITY `Expected f()`, new `Problem.FunctionNeedsCall`), else
  a constructor (`Construct` with none if nullary, `CtorRef` otherwise),
  else E_UNBOUND. A local called with arguments is `Apply (Local …)`, the
  local spanning the name; `x()` stays E_NOT_CALLABLE. `CtorNeedsArguments`
  is removed (no longer produced).
- Checked IR: `FunctionRef`, `CtorRef`, `Apply`, `Lambda (Array Param)`,
  `Pipe`; `Call`/`Construct` hold 1..n arguments (partial when fewer).
- Checking: Features.Check.Use (schemes; value references build the
  curried arrow, direct calls keep fields as an array), Call (named callee:
  j = n today's path; 0 < j < n checks j fields, typed as the arrow of the
  rest; `f()` with parameters E_ARITY before arguments; j > n: E_ARITY
  before any argument if the declared result can never be a function
  (Int, Bool, declared type), else check n, E_ARITY at the call if the
  instantiated result is not an arrow or unbound meta, else apply the rest
  as `Apply (Call f a1…an) rest`), Apply (one argument at a time, the type
  threaded with the state by Scheme's `threadAll`, now generic in its
  state; an unbound meta is bound to `α -> β`; anything else is E_TYPE
  `Expected a function, found T` at that argument), Pipe, Lambda (fresh
  metas or rigid annotations), Hint, Context (shared env rows). `require`
  wraps a TypeMismatch in `Hinted problem (MissingArguments f k)` per §4's
  provenance rules (the found expression's own node a partial `Call` or
  `Construct`; expected type's head, under the state before the failure,
  neither an arrow nor an unbound meta). Walk, Comparable, Coverage cover
  the new nodes; a function scrutinee admits only `_` and binders (by
  unification, unchanged Match). Check judges a printable `main` before any
  body: E_ENTRY `Expected fn main() with a printable result type` when the
  result contains an arrow directly or through declared fields
  (Functional). Instantiation's `foldCalls` enters `Apply` and `Pipe`
  (calls there are ordinary edges); value references and lambda bodies are
  Task 5's. Specialize.Body returns `Internal "unlowered function"` for
  each new node.
- Decisions not dictated by the plan: (1) `a |> g(b1…bk)` with k = n is
  the over-application `g(b1…bk, a)`: E_ARITY at the right operand's span
  when g's result is not a function; any other right side is applied to
  `a` (NotAFunction at `a`). `a |> f()` keeps `f()`'s own E_ARITY. (2) The
  over-application E_ARITY is checked before arguments when the declared
  result is Int, Bool or a declared type, so those wrong counts keep their
  pre-FN001 order of errors. (Corrected by the review: a result type
  variable cannot keep it; see the review fixes below.) (3) Only a TypeMismatch is hinted (an occurs
  failure never has a non-meta expected head). (4) The printable-entry
  check lives in Features.Check (it needs Functional), not
  Check.Signature, which is the coverage signature.
- Changed rows (old → new):
  - test/diagnostics.test.mjs `fn f(): P = Pair;`: E_ARITY 37-41 `Pair`
    `Constructor Pair needs arguments` → E_TYPE 37-41 `Pair`
    `Expected P, found Int -> Int -> P`.
  - test/adt-types.test.mjs `fn main(): Int = Cons;`: E_ARITY at `Cons`
    (58-62) `Constructor Cons needs arguments` → E_TYPE 58-62
    `Expected Int, found Int -> IntList -> IntList`.
  - `fn main(): Int = Cons(1);`: E_ARITY at `Cons(1)` (58-65) `Wrong number
    of arguments` → E_TYPE 58-65 `Expected Int, found IntList -> IntList;
    missing 1 argument to Cons?`.
  - `fn helper(): Int = 1; fn main(): Int = helper;`: E_UNBOUND at the
    second `helper` (80-86) `Unbound local helper` → E_ARITY 80-86
    `Expected helper()`.
  - test/adt-match.test.mjs `Cons(f, _) => f(1)`: E_NOT_CALLABLE at `f(1)`
    `Local is not callable: f` → E_TYPE at `1` (128-129)
    `Expected a function, found Int`.
  The adt-types rows now also assert these messages. No other existing
  assertion changed.
- Tests seen failing first (log .build/fn001-task4-red.log): 81 tests in
  test/fn-check.test.mjs, test/fn-hint.test.mjs, test/fn-rules.test.mjs;
  74 failed, 7 passed on arrival (comparison of `Int -> Int` and
  `Box(Int)`, three patterns on a function scrutinee and a redundant arm
  after `_`, which Task 2's type passes already gave; kept as
  characterization). Two markers were then corrected in the tests (an
  earlier `= x` in the prelude) and one unhinted row rewritten to `g + 1`
  so the found expression is the binder, not the match.
- Mutants (isolated scratchpad copy, not committed), each failing new rows:
  hint ignoring the expected type (2 rows: expected function), hint looking
  through `Apply` (`add3(1)(2)`), over-application always E_ARITY (4
  rows), partial application typed as the result (63), a non-function
  bound to an arrow instead of NotAFunction (6).
- Observed: one direct `node --test test/*.test.mjs` run failed
  match-lift's 1.5 s ladder at 1,780 ms (load); evidence added to BACKLOG
  T003. BACKLOG E003 counts updated.
- GREEN: `rm -rf output && npm run verify` exit 0, 468 tests (387 + 81),
  zero failures/skips, twelve regression proofs, bootstrap snapshots
  unchanged; `twenty thousand parameters are checked in linear time`
  passes unchanged (258 ms). Log .build/fn001-task4-verify.log.
- Review fixes (follow-up commit). I1: over-application through a result
  type variable checks the n arguments first, which inherently changes
  pre-FN001 outcomes with no existing row: `id(true + 1, 2)`,
  `fst(1, true + 1, 3)`, `loop(true, 2)` E_ARITY → E_TYPE at `true`;
  `id(id(1, 2), 3)` keeps E_ARITY at the inner `id(1, 2)`; `loop(1, 2)`
  (`loop: Int → a`) is accepted by Check (each confirmed). Recorded in
  design §9; the first two pinned in test/fn-check.test.mjs (they pass on
  0a49dfd, pinning behavior). I2: the Specialize row was vacuous (its
  prelude's `k` failed first); it now uses its own two-function program and
  asserts each node's own span for `(fn(x) => x)(1)`, `1 |> add(2)`,
  `id(add)(1, 2)`, `add(1)(2)`. Isolated mutants: Specialize copying
  `Apply`'s callee and `Pipe`'s left operand, and `Apply` alone, each make
  it fail (`invalid program compiled`). M1: a pipe into a saturated call
  whose declared result is Int, Bool or a declared type is E_ARITY right
  after the left operand, before the call's arguments (design §9);
  `1 |> add(true, 2)` failed on 0a49dfd (E_TYPE at `true`). M2:
  Format.Parse.Expression's primary reports where it starts, so an
  application of a parenthesized callee spans from its `(`; Task 3's
  `(g)(x)` row in test/fn-syntax.test.mjs moves from `g)(x)` to `(g)(x)`
  (with `((g))(x)(y)` and a bare `(g)` rows), the hint row
  `(fn(x) => add(x))(1)` likewise, and `(add)(1)` is a new no-hint row; on
  0a49dfd the three span rows and the Specialize row failed (5 failures,
  test log in the scratchpad). M3: plan Task 4 Files list corrected. M4:
  docs/language.md Names paragraph points to the design as superseding,
  pending Task 9. Perf: `supplied` builds the arrow only for a partial
  application. Match ladder alone, six alternating runs before/after the
  change: 519/518, 525/519, 524/527, 514/514, 508/535, 578/1,641 ms (the
  last pair under an external load spike), then four more under load
  average 7.4: 686/642, 741/715, 715/713, 700/705 ms: no measurable
  difference (the ladder makes no calls on that path; 0a49dfd's parent was
  508-516 ms against 523-562 ms at 0a49dfd).
  GREEN: `rm -rf output && npm run verify` exit 0, 472 tests (468 + 4),
  zero failures/skips, twelve regression proofs, snapshots unchanged;
  the ladder took 1,393 ms inside it under external load (BACKLOG T003),
  `twenty thousand parameters` 286 ms (log .build/fn001-task4-fix-verify.log).

### FN001 Task 5: instantiation rule and specialization (2026-10-08)

Branch fn001. Reach: Parse → Resolve → Check → Specialize (`specialize`,
`specializeWith` and `specializationKeys` called directly); the CLI stops
every function program at the temporary guard after Specialize.

- What changed: Check.Instantiation's `foldCalls` makes a bare
  `FunctionRef` an edge with its instantiation and enters lambda bodies,
  so references at any depth (match arms, lambdas, `Apply`, `Pipe`) are
  judged and form components (design §6); Components needed no change.
  Domain.IR.Internal gains `TFun Ty Ty` with hand-written Eq/Ord (one
  spine loop, the derived order), `spine` (two loops), and `FunctionRef`,
  `CtorRef`, `Apply`, `Lambda (Array Param)`, `Pipe`. The new
  Features.Specialize.Intern hash-conses arrows: a key part is
  `KInt | KBool | KData n | KFun n`, an arrow is numbered by its
  (parameter, result) numbers, and Lower interns a spine's suffixes from
  its final result outwards while lowering it (parameters by a balanced
  `traverse`, the interning by `Array.foldr`), so every suffix is numbered
  once and no key is found by walking or spelling a type. Lower returns a
  `Lowered = { ty, key }`; Keys' `Key` is `Tuple Int (Array Interned)`,
  `Work.arguments` are `Lowered`, the state holds the arrow table; arrow
  fields are lowered beside their written spine (as Check.Nested pairs
  them). Body copies the new nodes through the new Specialize.Values
  (`callee` for calls and bare references, `ownerCtor`: a partial
  construction or constructor value names its owner's copy, the final
  result of its arrow, `lambda`). `specializationKeys` rebuilds arrow
  arguments by a loop. The new Features.Specialize.Unlowered `reject` is
  called by Program.Compile after `specialize`. Format.Go: `goType`
  spells `TFun` inline as `func(A) func(B) R` along the spine; the field
  comparison of an arrow field emits `malformed`; Usage walks the new
  nodes; Expression lowers them to `func() T { panic("bumpus: unlowered
  function") }()`. All unreachable behind the guard; Task 6 replaces them.
- Decisions not dictated by the plan: (1) The guard rejects any program
  whose monomorphic IR holds an arrow type or a new node (a constructor
  with an arrow field, at the constructor; a signature holding an arrow,
  at the declaration; an arrow-typed expression such as a partial call,
  at it); before, a constructor's arrow field was rejected at the field's
  type. An arrow that is only a phantom type argument (`Proxy(Int ->
  Int)`) is neither, and a generic function never instantiated is not
  emitted, so such programs reach Go (worded so by the review, M1). (2)
  Constructors, called or bare, are no edges: they have no body, so they
  are in no component with a function. (3) A bare reference keeps the
  existing text `Recursive call to f changes its type arguments` (no new
  text is listed). (4) IR's `TFun` carries no number: plan and design say
  `TFun Ty Ty`. Task 6's named Go types (design §13 rule 8) must reach the
  numbers through Features.Specialize.Intern or carry them into the IR;
  left to Task 6. (Superseded by the review fixes below: the numbers are
  in the IR.) (5) The generator's edge kinds come from a seeded stream
  of their own, so P001's components are unchanged. (6) Representative
  independence is checked on the IR as a bisimulation: from both entries,
  the bodies agree node for node ignoring types and spans, constructors by
  name, and each pair of referenced functions is compared once.
- Changed rows: test/fn-check.test.mjs `checked function programs reach
  Specialize as Internal` becomes `... stop at the unlowered guard`; its
  four rows keep code (E_INTERNAL), span (each node's own) and text
  (`unlowered function`), now reported by the guard; three rows added
  (partial call at `add(1)`, arrow field at `T(Int -> Int)`, arrow
  parameter at the declaration). The `spec-key` regression row's needle
  is now `key = Tuple declaration (map keyOf arguments)` and its mutant
  collapses a data argument to `dataType 0`; still one target, still
  fails. No other existing assertion changed.
- Tests seen failing first (logs .build/fn001-task5-red-*.log):
  test/poly-termination.test.mjs, 5 of the new rows failed (lambda in a
  match arm, bare `walk`, bare `step` joining a component, bare `walk`
  inside a lambda, and `wrapping an intra-component argument` over the
  generator's value and lambda edges); the arrow type row and the two
  accepted rows passed on arrival (the arrow row since Task 3's Nested),
  kept as characterization. test/fn-specialize.test.mjs (map(id) twice,
  constructor values' owners, the 5,000-parameter keys) 3 of 3 failed;
  test/fn-representative.test.mjs failed; poly-properties' §4.2 bound
  failed (each `unlowered function` from Specialize); the guard row failed
  on the arrow-field span.
- Mutants (scratchpad copies, not committed): keys of whole IR types,
  compared by the spine loop: the 5,000-parameter test took 5.5 s against
  0.23 s; keys spelled as strings: 12.6 s (bound 2 s); arrows interned
  without their parameter: `fn id[…]` keys merged, the distinctness row
  fails; no `FunctionRef` edge: 3 rejected rows and the wrapped generator
  test fail; no lambda edge: 2 rows and the wrapped test fail; owner taken
  as the arrow itself: the owner row fails; no guard: the CLI row fails;
  a lambda parameter dropping its local when lowered at Bool: the IR
  independence property fails, but only after its third wrapper (a
  lambda never applied, so its unused parameters are bare holes) was
  added: the first version, whose parameters were `List(_)`, let it
  survive. The §4.2 bound itself passes on both rule mutants: accepted
  generated components use bare variables or ground types only, so it
  cannot distinguish them; the wrapped-variant test does.
- Linear cost: no large-source bound changed; `twenty thousand
  parameters` 310 ms and `three thousand distinct instantiations` 747 ms
  inside verify. Specializing the 5,000-parameter program takes 0.23 s
  alone.
- Observed: inside the green verify the match ladder took 1,441 ms against
  its 1.5 s bound (BACKLOG T003, evidence added).
- GREEN: `rm -rf output && npm run verify` exit 0, 483 tests (472 + 11),
  zero failures/skips, twelve regression proofs; bootstrap snapshots
  unchanged. Log .build/fn001-task5-verify.log.

## FN001 decisions (2026-10-08)

The user approved (a) fixing BACKLOG T003 (match-ladder timing margin:
1,480, 1,393 and 1,441 ms against 1,500 inside the last three verifies)
on fn001 after the Task 5 review and before Task 6, by reducing the
workload, not raising the bound; (b) durability additions: Task 8 Step
1b commits the Task 4 review's linear-cost table as bounded tests
(test/fn-linear.test.mjs), Task 8 Step 4 uses a committed
scripts/fn-milestone.mjs for the 20,000 tier, and Task 9 Step 1b
promotes four scratchpad mutants to regression rows (block-order,
value-edge, functional-fixpoint, arrow-key; 22 proofs); (c) the design
§9 documentation of over-application diagnostic changes (Task 4 review).
- Review fixes (follow-up commit; the review approved 5874482). I1: arrows
  are numbers in the IR. `IR.Ty` is `TInt | TBool | TData TypeId | TFun
  FunTypeId` with derived constant-time Eq/Ord (the hand-written spine
  instances are gone), and `IR.Program` carries `funTypes ∷ Array {
  parameter, result }` in interned-number order, from Intern's table
  (`numbers` for lookup, `entries` by number). The review measured about
  40,050,000 arrow nodes in the expression types of the 5,000-parameter
  test's IR, which any pass re-walking them in Format would visit. With
  numbered types the `Lowered` pair is gone (a lowered type is its own key
  part), so Keys' `Key` is again `Tuple Int (Array IR.Ty)` and the
  `spec-key` row is back to its P001 needle and mutant (one target; the
  proof passes). `IR.spine` reads the table by two loops;
  `specializationKeys` rebuilds arrows through it (tests only). A
  construction's or constructor value's owner is now the owner type at
  its instantiation (`applied`), not the end of its type's spine. Format.Go
  already emits the named types: `type bumpusFun<N> func(P) R` per entry,
  after the data types, and `goType (TFun n)` is `bumpusFun<N>` (no
  re-walking); a program without arrows emits none, so snapshots are
  unchanged. Design §7 and plan Task 5 Interfaces and Task 6 (number
  order, not first-use order) are amended as Task 5 review
  clarifications. M1: plan Global Constraints and decision (1) above say
  the guard judges the monomorphic IR; `a phantom arrow argument compiles
  and runs` pins `Proxy(Int -> Int)` printing 0 and its unused
  `bumpusFun0` declaration (written after the code; not run against
  5874482, where the guard already let it through by reading). M2:
  plan Task 6 Step 3 replaces the two temporary catch-all arms. M3:
  docs/architecture.md names Intern, Values, Unlowered and the numbered
  `TFun`; the full FN001 update stays Task 9's. M4: test/phases.mjs (and
  support.mjs, poly-keys.mjs and the two new test files) build failure
  messages only on failure; `checkedPoly succeeds on a 20,000-parameter
  function value` failed first with a RangeError from `JSON.stringify`
  (.build/fn001-task5-fix-red.log; a plain 20,000-parameter program did
  not reproduce it, since only a value reference puts the long arrow in
  the checked IR). Design §9 notes that the `Recursive call` text covers
  value references. New test `arrow types in the IR are interned table
  entries` (different ids for the two 5,000-parameter types, equal ids
  for equal types, each spine read through the table, at most 2 × 5,000
  entries); a parameter-blind interning mutant (scratchpad) fails it and
  the distinctness row. Timing of the 5,000-parameter specialization
  (`specializationKeys`, alone): 0.23 s before, 0.26 s after (three runs
  each). test/specialize.test.mjs now checks that a monomorphic program's
  `funTypes` is empty before comparing the rest; the first verify of
  these fixes failed it on the new field, and the match ladder at
  1,732 ms (BACKLOG T003). GREEN on the next run: `rm -rf output && npm
  run verify` exit 0, 486 tests (483 + 3), zero failures/skips, twelve
  regression proofs, snapshots unchanged; the ladder 1,497 ms, 3 ms
  under its bound (T003); `twenty thousand parameters` 241 ms (logs
  .build/fn001-task5-fix-verify.log, .build/fn001-task5-fix-verify2.log).

### T003: match-ladder compile cost (2026-10-08)

Goal (approved by the user before FN001 Task 6): make the 127-deep,
50-arm ladder in test/match-lift.test.mjs substantially cheaper so its
1.5 s bound has headroom inside verify's parallel run; the bound, the
workload and the test's place in verify are unchanged. Acceptance was a
2× drop in the isolated median, or, if that needs a design change, the
profile and the options.

Profile (c120d48, built in an isolated copy). The measurement is
committed as scripts/ladder-profile.mjs (`node scripts/ladder-profile.mjs
--rounds 7 --baseline DIR`: cold compiles in fresh processes alternating
with a built baseline tree, steady per-phase medians, load average); the
CPU and allocation profiles below used `node --cpu-prof` and V8
allocation sampling on the same source. Steady state per phase (median of 15, in-process): parse
137 ms (lex 55), resolve 22, check 134 (infer 61, coverage 36,
firstTooDeep 9, holes 8, instantiation rule 9, retype 7, comparable 5),
specialize 24, Go emission 46. One cold compile (fresh process, the
test file's small program first, as in the test) was ~500 ms: about
1.4× the steady sum, from JIT warm-up and GC. The compile allocates about
2.8 GB for the 150 KB source (`--trace-gc`: 149 scavenges, ~110 ms of
GC). Hot spots: Format.Lex (per-character `tailRecM` steps over a copied
character array, `Array.elem`, a fresh slice per two-character-token
probe); `isName`/`decimalToken` copying each token into a character
array; Format.Go.Capture's `union` (concat, sort, then `Array.nubBy`,
which sorts again) at 26% of emission; coverage's per-arm redundancy
query re-simplifying every earlier arm and `uncons`-copying every row a
specialization drops (quadratic in arms by design, so the constant
matters); `tooDeep`/`walk` entering their loops for Int, Bool and rigid
types; `retype`/`holes` rebuilding a body that has no bound meta or
hole. Everything else is a flat spread of combinator, Either and record
overhead (no single function above 4% after these fixes).

Changes (each keeps its semantics; no public formula is new):
- Lex reads the source in place by code unit (`String.charAt`/`slice`),
  skips a whitespace run in one step, tries two-character tokens only
  after their first characters, and tests punctuation and reserved
  words with `case` instead of `Array.elem`; `isName` and Literal's
  `decimalToken` count in place.
- Parse.Cursor's State carries `upcoming`, the next token's text, set
  once per token consumed, so `peekText` is a field read.
- Coverage simplifies each arm once per match; `useful` takes simplified
  rows; Matrix's `specialize`/`defaults` judge a row by `Array.head`
  before copying its rest.
- `tooDeep` answers Int, Bool and rigid variables without converting;
  Unify's `walk` enters its loop only for a meta.
- Check skips `retype (resolved subst)` when the substitution is empty,
  and `holes` keeps a body with no hole.
- Capture's `union`/`armFree` keep the first of each id in one fold over
  the sorted array instead of `Array.nubBy`.
Tried and reverted: a loop in place of `Array.find` in Grammar's
dispatch (no measurable gain, and Grammar would pass 250 lines); a
`tailRecM` `threadAll` in place of the Thread applicative (no measurable
gain; needed a new Foldable instance).

After (steady, median of 15, load average 9-11, alternating with the
baseline): parse 124 → 92, resolve 19 → 19, check 125 → 78 (infer
53 → 35, coverage 31 → 26), specialize 21 → 21, emission 43 → 27;
sum 332 → 237. Allocation (V8 `total_allocated_bytes`, per phase
summed) 3.3 → 2.4 GB. Isolated cold compile, nine alternating rounds
at load average 5.7 (18:29): baseline 543 504 507 517 502 495 514 512
495, median 507 ms; T003 379 368 363 385 379 376 370 362 366, median
370 ms: 1.37×, short of the 2× target. Cold phases: parse 176 → 125,
check 193 → 131, emission 61 → 42.

Verify (three consecutive `npm run verify`, every run reported): all
exit 0, 486 tests, zero failures, twelve regression proofs, snapshots
byte-identical. Ladder: 942 ms (load 8.9 after), 968 ms (14.7), 852 ms
(12.0); logs .build/t003-verify{1,2,3}.log. Before T003 the same test
took 1,345-1,732 ms inside verify. Two direct `node --test` runs during
the work, while other projects' builds pushed the load average to
16-30, failed it at 1,659 ms and 2,573 ms (.build/t003-tests1.log,
.build/t003-tests2.log); the second also failed coverage-scale's
5,000-field pattern (5.1 s) and fn-specialize's 5,000-parameter keys
(2.7 s). Both pass alone (0.80 s and 3.2 s wall under load 27; baseline
0.70 s and 2.7 s in the same minute) and neither path's timing changed
in kind; these are T003's external-load symptom in other timing tests.

Why not 2×: what remains is spread over the combinator parser (each
argument passes about a dozen Either-threaded combinator layers),
monadic threading in Infer, Resolve and Specialize, coverage's quadratic
redundancy query, and GC. Options that would reach 2×, each a design
change: (1) a direct token-level parser for expressions in place of the
layered combinators (parse is now 35% of the cold compile); (2)
redundancy for literal-only columns without one usefulness query per
earlier arm; (3) fusing the checker's remaining whole-body passes
(firstTooDeep, comparable, coverage roots, instantiation's two call
folds) into one; (4) an allocation-light State/Parsed representation.
BACKLOG T003 stays Open with these.

Re-run with the committed script (18:37, load average 7.03 before, 6.40
after; 7 alternating rounds against the c120d48 copy): cold baseline
513 539 504 494 520 500 501, median 504 ms; current 396 373 392 382 373
368 368, median 373 ms. Steady medians baseline → current: lex 61 → 31,
parse 136 → 96, resolve 21 → 21, check 136 → 86, specialize 22 → 21,
emit 46 → 26 ms. `npm run verify` with the script committed: exit 0,
486 tests, twelve regression proofs, ladder 748 ms (load average 6.05
before, 19.82 after; .build/t003-script-verify.log).

Review follow-up (2026-10-08): the independent review approved 7c6c0f5
(50,453 differential cases, 0 differences). Minors fixed: Usefulness's
comment (once per arm, against all earlier arms); Lex `spaceEnd` reads
each character once (`spaceStep`); Check's `settle` uses a new
`Unify.isEmpty` (test `isEmpty holds exactly until a meta is bound`)
instead of `Subst(..)`; Coverage's import order. The reviewer's harness
is now scripts/differential.mjs (+ differential-corpus.mjs,
differential-hook.mjs; docs/engineering.md). Against the c120d48 copy,
seed 7, count 1000, harvest regenerated (3,419 parses → 2,355 distinct
sources; load average 11.6 at 18:49): harvested 2,355, fuzz 1,029 plus
1,085 isName probes, matches 1,000, mutations 1,000, 0 differences
(.build/t003-differential.log). Against a copy whose lexer no longer
treats tab as whitespace: 148 of 329 fuzz sources differ at lex, exit 1
(.build/t003-differential-broken.log). `npm run verify`: exit 0, 487
tests, twelve regression proofs, ladder 811 ms (load average 6.95
before, 12.03 after; .build/t003-review-verify.log).


## T003 decision (2026-10-08)

The user chose to accept the 1.37× isolated gain (7c6c0f5; script
scripts/ladder-profile.mjs, 6d0906c) and continue to FN001 Task 6. T003
stays Open with its five recorded design options; ladder in verify now
748-968 ms against 1,500. Task 6 starts after the T003 review.

### FN001 Task 6: Go lowering (2026-10-08)

Branch fn001. Reach: the whole CLI; programs with function types,
lambdas, function values, partial and over-application and pipes now
compile, build and run. Design §13 rules 1-8 as adopted.

- What changed: the guard Features.Specialize.Unlowered and its call in
  Program.Compile are deleted. Format.Go.Lowered's `Scope` carries the
  program's `Shape` (signatures and constructors as `Wrapper`s, the
  `funTypes` table, and a (parameter, result) → number map); `Lowered`
  gains `wrappers`, the staged wrappers its values need. New modules:
  Format.Go.Value (a saturated call or construction is today's n-ary call,
  rule 1; a partial one is `{f}Value(a1)…(aj)`; a bare reference of arity
  1 is the Go function, of arity n ≥ 2 `{f}Value`; any other application
  and over-application apply the value), .Apply (rule 6: inline up to 64
  arguments, else `bumpusFn{f}Apply{k}` helpers of at most 64 stages
  taking the value so far and their arguments' free locals, each argument
  evaluated in place), .Lambda (rule 5: `bumpusFn{f}Lambda{k}` of its free
  locals, ascending, then its parameters, `_` for a discard; the value is
  the wrapper applied to the free locals through .Apply, or the function
  itself with no free local and one parameter), .Pipe (rule 7), .Stage
  (rules 2-3: one `bumpusNode{N}` per distinct argument type of all
  wrappers, `{f}Value`, `{f}Stage{k}`) and .Entry (rule 4: package-level
  `{f}Kinds`/`{f}Slots`, one array per distinct type, one loop, one n-ary
  call). Capture gains `lambdaFree` (a lambda's named parameters are bound
  in its body; a set, so a wide lambda is not quadratic) and `without`.
  Expression dispatches every node by an explicit arm (the temporary
  wildcard is gone); Compare's `TFun` arm and a new explicit Show `TFun`
  arm emit `malformed` for a function field (never compared or printed,
  design §3, but every declared type gets both helpers). Emit order: node
  types after the function types, wrappers after the functions. A program
  with no function value emits no node, stage, entry or table: the four
  bootstrap snapshots are byte-identical (compiler, shapes, tree and
  lists tests). Usage and Layout needed no change.
- Decisions not dictated (recorded in design §13 "Task 6
  clarifications"): (1) a stage value with no interned arrow (inside the
  prefix of a partial application, or of a lambda's free locals) gets
  the wrapper's own `{f}Arrow{k}` type; every other stage uses the
  interned `bumpusFun{N}`, found by number, so uses and the wrapper agree.
  (2) The pipe's temporary is the parameter `bumpusPipe` of a lifted
  `bumpusFn{f}Pipe{k}` (free locals, then the operand), not an
  immediately invoked closure, so pipe chains nest no closure; a literal
  or local left operand is spliced in as the last argument. In both
  cases a right side `g(b1…bk)` with k < n becomes `g(b1…bk, v)`, so
  `xs |> take(3)` is a direct call. (3) Matches, lambdas, pipes and
  helpers share one pre-order counter per function. (4) Entries' tables
  are `int32`, not `uint16` (no 65,536-type ceiling). (5) Helper bodies
  are one chained expression, not one statement per stage as in Task 1's
  prototype. (6) Wrappers are emitted once each by name, in first-request
  order; node types are numbered in first-appearance order. (7)
  test/fn-lambdas.mjs now holds Task 5's lambda wrappers, shared by
  test/fn-representative.test.mjs and test/fn-run.test.mjs (moved, not
  changed).
- Deleted rows (the guard's test, test/fn-check.test.mjs `checked
  function programs stop at the unlowered guard`), each E_INTERNAL
  `unlowered function` at the span shown, now compiling and printing:
  `(fn(x) => x)(1)` (1), `1 |> add(2)` (3), `id(add)(1, 2)` (3),
  `add(1)(2)` (3), `match add(1) { _ => 0 }` at `add(1)` (0), `type T =
  T(Int -> Int); fn main(): Int = 0;` at `T(Int -> Int)` (0), `fn f(g:
  Int -> Int): Int = 0; fn main(): Int = 0;` at the declaration (0).
  test/specialize.test.mjs's monomorphic-identity set excludes the new
  polymorphic examples/functions.bumpus, as it excludes lists.bumpus (its
  first verify run failed on the new example's arrow table,
  .build/fn001-task6-verify1.log). No other existing assertion changed.
- Tests seen failing first, all at the guard (E_INTERNAL `unlowered
  function`): test/fn-timing.test.mjs, 6 of 6
  (.build/fn001-task6-red-timing.log): named value `use(stuck)`, lambda
  `use(fn(x) => stuck(x))`, partial strictness `ignore(k3(probe(1)))`,
  pipe order `probe1(1) |> g(probe2(2))`, helper order (a 65-argument
  application of `w`, whose body is entered at its second stage, before a
  third argument's probe) and sharing (`twice(k3(probe(10)))` prints `30`
  with probe entered once in the trace); test/fn-run.test.mjs, 22 of 22
  (.build/fn001-task6-red-run.log); test/fn-scale.test.mjs, 1 of 1
  (.build/fn001-task6-red-scale.log). After implementing, two structural
  rows in fn-run failed because the test assumed declaration-order ids
  (a generic `length` is numbered after the monomorphic functions); the
  ids in the tests were corrected, not the assertions.
- Mutation checks (isolated copies under the scratchpad, one mutant each,
  rebuilt, test/fn-timing.test.mjs run): eta-expanded value of a
  one-parameter function returning a function (`func(x) … { return
  func(y) … { return F(x)(y) } }`): `named value` fails (exit 0); a
  hoisting application helper (each block's arguments bound before its
  stages): `helper order` fails (probe2 entered first); lazy partial
  arguments (a partial call as nested closures around the saturated call):
  `partial strictness` fails (exit 0) and `sharing` fails (trace
  `[3 2 0 1 0 1]`, probe twice); a rewritten pipe (left operand spliced in
  place, no temporary): `pipe order` fails (probe2 first). Every other
  probe passed under each mutant.
- Scale (test/fn-scale.test.mjs, through the CLI): 5,000 parameters of
  Int, Bool and List(Int), each read twice in a strided order (Bool
  through a helper call, as Task 1's body), called directly and applied
  as a value through 79 helpers; Go's cache is defeated for the
  program's own package by a comment nonce. Alone: emit 1.3 s, `go build`
  4.0 s against the 10 s bound (2.8 s for the same program with the
  direct call only); the test logs its build time. A first body with
  `if` terms (3,333 immediately invoked closures) built in 5.8 s (4.5 s
  direct only); replaced before any verify.
- Depth (ADR 006 "Functions emitted"): the five FN001 forms joined
  `forms` and test/depth.test.mjs. Re-measured in an isolated copy with
  the limit lifted, every form, and the old forms also on an isolated
  build of 97740c6: FN001 forms 1,507 / 812 / 607 / 607 / 343; old forms
  unchanged by the lowering (within 5); minimum 276
  (constructor-argument; 274 at 97740c6), limit 128 unchanged, no
  anomalies. The drops since ADR 006's G001 table (e.g. plus-chain
  2,928 → 1,564, constructor-argument 304 → 274) predate Task 6.
- Differential (scripts/differential.mjs, a scratchpad variant that skips
  sources the baseline stops at its guard; baseline an isolated build of
  97740c6; harvest regenerated, its test run exited 0): seed 1, count
  1,000: 5,094 sources compared and 1,085 isName probes, 0 differences,
  309 function programs skipped (304 harvested, 5 mutations); seed 6,
  count 10,000: 32,054 compared and 10,085 probes, 0 differences, 349
  skipped (.build/fn001-task6-differential{,-10k}.log).
- GREEN: `rm -rf output && npm run verify` exit 0, 526 tests (487 at 97740c6,
  minus the guard test with its 7 rows, plus 6 timing probes, 22 run
  tests, 1 scale, 1 snapshot and 10 CLI depth tests), zero failures or skips, twelve
  regression proofs, the four bootstrap snapshots unchanged; the match
  ladder 542 ms; `twenty thousand parameters` 220 ms; the 5,000-parameter
  `go build` 6,799 ms against its 10 s bound (4.0 s alone; BACKLOG T003
  records the margin); load average 1.79 before, 6.71 after
  (.build/fn001-task6-verify3.log; earlier green run
  .build/fn001-task6-verify2.log). Usage and Layout unchanged.
- Review follow-up (2026-10-08; the independent review found the
  lowering sound and accepted the deviations). Depth: the reviewer
  bisected the margin loss (ADR 006 "Functions emitted" now attributes
  it: FN001 Task 3's postfix and pipe layers, the Task 4 review's
  `bare <$> named inner` map layer, P001 for plus-chain). Fix: `named`
  builds its `Primary` itself (Format.Parse.Expression; productions stay
  applicative). Isolated copies, limit lifted, two alternating rounds:
  constructor-argument 275 → 283, call-argument 315 → 326, parens 522 →
  522; minimum 283. Differential, d2cf616 plus only the parser change
  against d2cf616 (seed 6, count 10,000): 32,403 sources and 10,085
  probes, 0 differences (.build/fn001-task6-fix-differential-parser.log).
  BACKLOG G002 tracks recovering Task 3's ~24 levels. Minors: Stage no
  longer declares `{f}Arrow1`, which no stage names (only a helper's
  signature can; it now spells `func(A1) <next>`); bootstrap/functions.go
  loses its one unused `bumpusFn6Lambda0Arrow1` line. The full
  differential against d2cf616 shows that change alone: harvested 235 of
  2,374 sources differ, all at emit, and a scratch check finds every
  candidate emission equal to the baseline's with the `Arrow1`
  declarations removed and their uses spelled out (1,287 compiled, 0
  unexplained); fuzz and matches 0 differences; mutations 4 (seed 1) and
  32 (seed 6), the shown ones all at emit (.build/fn001-task6-fix-
  differential{,-10k}.log). The `--regenerate` harvest's own test run
  exited 1; differential.mjs discards its output, so the failing test is
  unknown (it ran the full suite in parallel under the hook). Apply's
  blocks push their lifted functions, frees and wrappers onto a stack and
  concatenate once (was O(blocks × lifted)). test/fn-specialize's stale
  guard comment and support.mjs's `goTest =(` spacing are fixed.
- Scale, from the review (pending user decisions; nothing changed): the
  reviewer's verify failed fn-scale, `go build 10584 ms, bound 10000`, at
  load average 18.3 with only verify's own runner. The same mixed-body
  program builds in 1.8 s at 2,500 parameters, 4.4 s at 5,000 (direct
  call only 3.0 s), 17.9 s at 10,000 (direct only 11.2 s); at 20,000 the
  Go compiler was killed at 7.4 GB RSS, with the direct call only too.
  The cause is the n-ary body's 2n-term `bumpusAdd` tree in one Go
  expression (the existing lowering of `+`), not Task 6's staging.
  Recorded in BACKLOG T003.
- GREEN (review follow-up): `rm -rf output && npm run verify` exit 0,
  526 tests, zero failures or skips, twelve regression proofs; the
  5,000-parameter `go build` 7,467 ms against 10 s; the match ladder
  1,030 ms; load average 3.15 before, 5.34 after
  (.build/fn001-task6-fix-verify.log). Run once.

### Differential harvest failure, unidentified (2026-10-08)

During the Task 6 review fixes, `scripts/differential.mjs --regenerate`
ran the full test suite under its harvest hook and that run exited 1;
the tool discarded the run's output, so the failing test is unknown
(likeliest a load-sensitive timing test, BACKLOG T003, unconfirmed). The
tool now writes the run's output to `<harvest>.jsonl.log` and prints the
failing test names. One rerun afterwards (load 3.3 before, 9.1 after)
exited 0: 2,374 harvested sources, 0 differences against itself.

### FN001 Task 8: scale (2026-10-09)

User decisions (2026-10-09): (A) the 5,000-parameter `go build` test
failed once at 10,584 ms against 10 s under verify's own parallel load
(4.0-4.4 s alone); bound and workload stay, and `go build`-timing scale
tests now run in a separate serial phase: scripts/verify.mjs runs
`test/*.serial.test.mjs` after the parallel `node --test` run with
`--test-concurrency=1`, still discovered by pattern (docs/engineering.md).
(B) At 20,000 parameters the mixed body's 2n-term `bumpusAdd` tree in one
Go expression kills the Go compiler (7.4 GB) even for direct calls only,
pre-existing lowering, not FN001 staging (BACKLOG G003, new). The
milestone therefore tests FN001's machinery at full width with bodies
that read six parameters (first and last three, mixed kinds).

- Files: test/fn-scale.test.mjs renamed test/fn-scale.serial.test.mjs
  (mixed-body program and its 10 s bound unchanged; now compiled in
  process with a phase bound) plus three programs; test/fn-scale-programs.mjs
  (generators shared with the milestone), test/go-timed.mjs (the
  process-group `go build` timer moved out of fn-scale),
  test/fn-linear-forms.mjs, test/fn-linear.test.mjs (20,000, parallel),
  test/fn-linear.serial.test.mjs (80,000, serial, about 11.5 s),
  scripts/fn-milestone.mjs, scripts/verify.mjs.
- Step 1 (serial; phases measured, bound 3x; `go build` bound 10 s):
  5,000-parameter mixed body, direct and value, phases 1,240-1,260 ms,
  build 4.0-4.3 s; `f(1)(2)…(1000)` 74-85 ms, 0.40-0.45 s; a written
  `Int -> … -> Int` of 1,000 parameters 65-77 ms, 0.41-0.44 s; a
  5,000-parameter function type through `id` and `Box(a)`, whole and as
  a half partial, 529-581 ms, 2.4-2.5 s. The shared partial (completed
  twice) is in the milestone's `wide` program; the 5,000-parameter
  mixed-body test keeps its workload, so its partial is covered at
  5,000 by the generic program's partial instead. The existing
  20,000-parameter and 4,000-`Nil` tests are unchanged.
- Step 1b (Parse → Resolve → Check → Specialize, 20,000 parameters, ms
  measured / bound): value 400/1,200, over-application 540/1,620, wide
  lambda 515/1,545, mismatch `f(1)` (E_TYPE) 175/525, `f(1)` 310/930,
  `f(1…n-1)` 225/675, `(f)(1…n)` 370/1,110, pipe 250/750. At 80,000 all
  eight finish with the expected outcome, about four times as long.
- Step 2 (scratchpad copies, non-strict build, test/fn-linear*.test.mjs):
  recursive spine walk (`spineThrough` as recursion with `Array.cons`):
  6 of 8 forms at 20,000 fail with RangeError (stack); spelling-based
  arrow keys (Specialize.Intern keyed by the expanded spelling of each
  suffix): 5 of 8 fail with RangeError; derived `Eq`/`Ord` on Domain.Type
  `Ty` restored: survives all Task 8 tests (fn-linear at 20,000 and
  80,000, fn-scale.serial, large-source, fn-specialize, fn-check), so
  no Task 8 form compares long source arrows with `Eq`/`Ord` (the
  specializer compares interned IR numbers). Not pursued further (user
  limited Step 2 to three mutants); open for Task 9's review. Nested
  closures were not rerun.
- Step 4 milestone, run once (`node scripts/fn-milestone.mjs`, 20,000
  parameters, CLI emit then `go build` with a 100 s timeout; load 3.1
  before, 5.4 after; .build/fn001-task8-milestone.log), all ok: wide
  (direct, value, shared partial) emit 2.4 s, build 13.7 s; chain 0.7,
  7.6; curried 0.8, 7.5; generic 2.0, 12.1; value 0.7, 6.8; over 0.8,
  7.0; lambda 0.8, 6.6; `f(1)` 0.7, 6.1; `f(1…n-1)` 0.5, 7.0;
  `(f)(1…n)` 0.7, 6.8; pipe 0.4, 0.3 (the pipe is a direct call: no
  staged wrapper is emitted).
- Step 3: `rm -rf output && npm run verify` exit 0 in 1:53 (load average
  3.69 before, 4.97 after; .build/fn001-task8-verify.log): parallel phase
  533 tests, serial phase 12, zero failures or skips; serial
  5,000-parameter build 4,733 ms; match ladder 735 ms; `twenty thousand
  parameters` 221 ms.

### FN001 Task 7: reference interpreter (2026-10-09)

- test/poly-oracle.mjs, independently of the compiler: function values
  (named functions and constructors with their declared arity, lambda
  closures, `_` parameters), staged application one argument at a time
  (a body runs exactly when its stage boundary completes), strict
  partial application, over-application, `|>` with the left operand
  first, then the callee and its explicit arguments, and an `enters`
  trace (declaration positions) with optional probes that stop the run
  on entry. test/poly-parse.mjs now records constructor field counts.
- Step 1 (seen failing against the previous interpreter): six
  test/fn-timing.test.mjs cases compare the interpreter's first entered
  probe with the Go run's (all five Task 6 probes) and the shared
  partial's printed value and entry trace (`30 [3 0 2 1 1]`); the
  generated property failed.
- test/fn-programs.mjs generates 30 programs (seeds 0x7a11 + index) over
  Int, Bool, List(Int), Pair(Int, Bool), Int -> Int and Int -> Int -> Int
  with a higher-order prelude (map, fold, compose, flip, adder):
  lambdas (with `_`, capturing match binders), partial and
  over-application of functions, constructors and lambdas, constructor
  values (`flip(Cons)`, `Pair(n)(b)`, `compose(adder, f)`) and pipes.
  test/fn-oracle.test.mjs runs them in one Go batch against the
  interpreter (failures print seed and source) and checks every form
  occurs. All 30 agree; no compiler bug found.
- Mutant (scratchpad copy, non-strict build): Format.Go.Pipe always
  splicing the left operand as the last argument (left operand
  evaluated last) fails `interpreter agrees: pipe order` (and Task 6's
  Go probe). The generated comparison does not see it: generated
  programs terminate and have no effects, so pipe order is not
  observable in their values; timing stays the probes' job.
- `rm -rf output && npm run verify` exit 0 (load average 3.01 before,
  5.77 after; .build/fn001-task7-verify.log): parallel phase 541 tests,
  serial phase 12, zero failures
  or skips.

### FN001 Task 9: regression proofs and documentation (2026-10-09)

- Ten regression rows (scripts/regression-fn.mjs, imported by
  scripts/regression.mjs; probes in test/regression-fn.mjs, imported by
  test/regression.mjs, whose `printed` now runs through a shared `ran`):
  `stage-value` (Format.Go.Expression: a bare arity-1 function whose type
  has two or more parameters lowered as a two-level eta adapter; probe
  `use(stuck)` must panic in `stuck`), `stage-lambda` (Format.Go.Lambda:
  the same adapter around a one-parameter lambda's lifted function),
  `partial-strict` (Format.Go.Value: a partial application wrapped in a
  closure awaiting its next argument, so its arguments run late),
  `pipe-order` (Format.Go.Pipe: every pipe spliced as the call),
  `lambda-capture` (Format.Go.Capture `lambdaFree` keeps parameters),
  `fun-compare` (Check.Comparable drops the function test),
  `block-order` (Format.Go.Apply: a helper binds its block's arguments to
  variables before applying), `value-edge` (Check.Instantiation: bare
  references and lambda bodies are no edges; mutant outcome `More than
  10000 specializations`), `functional-fixpoint` (Check.Functional
  returns its seeds), `arrow-key` (Specialize.Intern keys an arrow by
  `TInt` and its result). Timing probes use test/support.mjs
  `panicOnEntry`. Deviation: as built there is no uncurried value
  representation, so `stage-value`/`stage-lambda` restore the defect's
  effect (eta expansion to the type's arity) instead. The lowering
  mutants' Go builds, so those probes fail on behavior (`0` printed, or
  the wrong probe label); `lambda-capture` and `arrow-key` fail at Go
  build, inherent to those defects. `node scripts/regression.mjs
  name…` now proves only the named rows.
- Task 8 Step 2 gap (derived `Eq`/`Ord` on Domain.Type `Ty`): rebuilt in
  a scratchpad copy with both instances derived; test/type-order.test.mjs
  (Task 2) fails 2 of 5 (RangeError on 20,000-long spines), so verify
  already catches it; Task 8 had run five other files only. No pipeline
  phase compares long source arrows with `Eq`/`Ord`: the same mutant
  compiles a program unifying two 20,000-parameter written arrows with a
  20,000-parameter function (and `same(h, h)`) correctly. No new test
  added, since no pipeline test can observe that defect.
- Nested-closures mutant (Format.Go.Stage `wrapperCode` emitting the
  wrapper as nested Go closures, no nodes or entry) against
  test/fn-scale.serial.test.mjs, once (load 2.5 before, 2.9 after): the
  5,000-parameter value and the 5,000-parameter generic function type
  fail, `go build` killed at the 120 s timeout (bound 10 s); the
  1,000-partial chain (9,315 ms) and the 1,000-long arrow (6,325 ms)
  pass, against 542 and 575 ms healthy in the verify below.
- Docs: docs/adr/008-functions.md; docs/language.md (grammar, names,
  typing, evaluation, diagnostics, nesting; each claim names its test
  file; the Task 4 "pending" note removed); docs/architecture.md,
  docs/engineering.md (twenty-two rows), README (ADR 008), BACKLOG (FN001
  Done pending merge; FN002-FN005), docs/findings.md, docs/next-session.md.
- `rm -rf output && npm run verify` exit 0 in 150 s (load average 2.39
  before, 8.44 after; .build/fn001-task9-verify.log): parallel phase 541
  tests, serial phase 12, zero failures or skips; twenty-two `Regression
  proof (…)` lines; serial 5,000-parameter build 4,423 ms; match ladder
  640 ms.

## FN001 whole-branch review (2026-10-09)

Fresh reviewer, whole diff 2a61a2b..e2a6735: ready to merge, no Critical
or Important findings. Verify in an isolated copy: exit 0, 541 + 12
tests, 22 proofs. Six adversarial cross-task programs matched the
interpreter including entry order; 2,300 extra generator seeds matched;
~46,000 sources against a main build: 0 Go differences among sources
main accepts, none newly rejected, every non-syntax diagnostic change a
design §9 row. Minors fixed: language.md hint condition (M1), generator
label (M3), ADR 008 note on syntax diagnostics of invalid sources (M6),
BACKLOG T005 for the unidentified harvest failure (M5; renumbered at
the merge because main had added its own T004); deferred to
BACKLOG FN006: interpreter zero-argument calls (M2), splitting the
value-edge row (M4), fn-linear bounds in the parallel phase (M7).
Awaiting the user's merge decision.

## FX001 sequencing discussion recorded (2026-10-08)

At the user's request, language-direction records proposed `do` notation
as an expression elaborated into bind and lambdas, with an illustrative
block and its expansion. Result binding, discarded results, final
computation and the distinction between constructing and running deferred
effects are explained. Service/error inference is a goal; bind/pure
selection, binding rules and monadic versus algebraic effects stay open.
This is direction only, with no compiler change or implementation
authorization. Next-session and the FX001 backlog row point to the proposal.
Verification: `npm run verify` exited 0 with 318 tests, no failures or
skips, and all twelve regression proofs; evidence:
`.build/fx001-do-docs-verify.log`. The proposed notation is not implemented
or behaviorally verified by this suite.

## Effect-row notation and constraint scope recorded (2026-10-08)

The user asked to preserve the algebraic-effect/open-row discussion and
defer explicit effect-row constraint syntax to a future feature. The
language-direction document now records direct-style handler evaluation,
candidate `Log + ...effects` notation, inferred higher-order effect
relationships and proposed implicit universal row quantification. It
distinguishes record rows and R001's lacks constraints from effect rows.
Outer syntax, quantifier scope and handler semantics remain design work;
no compiler change or implementation authorization. BACKLOG and the
next-session handoff record the future constraint-syntax scope.
Verification: `npm run verify` exited 0 with 318 tests, no failures or
skips, and twelve regression proofs; evidence:
`.build/fx001-row-direction-verify.log`. This verifies the existing
compiler, not the proposed effects or notation.

## MileAhead error-row pattern captured (2026-10-08)

The user's error-widening question revealed that earlier direction only
mentioned extensible errors generically. Read-only inspection of MileAhead
(../trailmapper, as recorded in provenance) confirmed open error-family
rows, caller composition without conversion wrappers, context-only
wrapping, and closure at handling/test boundaries. Language-direction now
records this brief and independent Bumpus syntax candidates hiding Variant
and injection plumbing. FX001/R001 must resolve error-sum support against
the current general-variant deferral; no feature scope or code changed.
Provenance, BACKLOG and the next-session handoff track the design work.
Clarified after the user's follow-up: `errors` is an ordinary implicitly
universally quantified row-variable name, not reserved or existential;
only the spread punctuation is special syntax in the proposal.
Verification: `npm run verify` exited 0 with 318 tests, no failures or
skips, and twelve regression proofs; evidence:
`.build/fx001-error-rows-verify.log`. Proposed error sums remain unimplemented.

## Standard-library helper direction recorded (2026-10-08)

The user requested planning for common PureScript/Haskell FP helpers with
approachable Rust-informed names. Added STD001 and a dedicated direction
document covering optional/result eliminators, defaults, transformations,
functions, sequences, text, maps/sets and generic collection operations.
Candidate names distinguish getOrElse from full branch elimination and
make eager/lazy evaluation explicit. Delivery follows FN001 and stages
other APIs by their prerequisites; no compiler or helper implementation.
Acceptance requires an upstream coverage matrix, readable examples,
behavioral/law tests and explicit deferrals. Handoff and language-direction
link the brief; exact public names still need reviewed API designs.
Verification: `npm run verify` exited 0 with 318 tests, no failures or
skips, and twelve regression proofs; evidence:
`.build/std001-direction-verify.log`. Helpers are planned, not implemented.

## STD001 generic rigor clarified (2026-10-08)

The user clarified that approachable naming must preserve theoretical
rigor and HKT-based shared operations. STD001 now pins generic bimap over
any lawful Bifunctor, shared Functor/Applicative/Monad contracts, required
constructor kinds and partial type application, and coherent instance
evidence under the current rank-1/specialization constraints. Concrete
helpers are incremental delivery, not completion of the generic library.
Acceptance includes generic clients, user-defined product/sum instances,
algebraic law properties and cross-operation coherence; pure callback laws
remain distinct from FX001 effectful sequencing. BACKLOG and handoff track
the clarification. No language or library implementation changed.
Verification: `npm run verify` exited 0 with 318 tests, no failures or
skips, and twelve regression proofs; evidence:
`.build/std001-generic-rigor-verify.log`. Generic APIs and laws above are
future acceptance requirements, not implemented or proven by this run.

## Cross-language audit planned (2026-10-08)

The user asked for a structured audit of leading language specifications
and library/runtime designs. Existing STD001 only audited helper coverage;
there was no broader systematic plan. Added LA001 covering all twelve
named references, a versioned primary-source/section ledger, comparative
briefs, decision and interaction matrices, practical application scenarios,
independent review and durable scope decisions. Primary landing pages were
checked to assemble the roster; detailed reading/audit is not complete.
Relevant findings feed upcoming designs without expanding FN001 or revoking
existing advanced-feature deferrals. BACKLOG and handoff track the plan.
Verification: `npm run verify` exited 1 with 316 of 318 tests passing,
no skips, and two large-source timing failures (6.572 s and 5.633 s against
5 s bounds). Regression proofs were not reached. Evidence is
`.build/la001-plan-verify.log`; BACKLOG T004 records the cases, unconfirmed
cause and diagnostic next action. No checks or assertions were changed,
and no rerun concealed the failures. The audit itself remains planned.

## Developer tooling direction recorded (2026-10-08)

The user requested highlighting/IDE support, first-class doctests,
property-based testing, possible literate capabilities, and LLM
skills/discoverability. Added distinct IDE001, DOC001, PBT001, LIT001 and
AI001 entries with docs/plans/2026-10-08-tooling-direction.md. The brief
records outcomes, proposed acceptance and dependencies without selecting
syntax, tool protocols or implementations; literate capabilities remain
exploratory. LA001 now includes these concerns in its comparison axes and
application scenarios. Updated language direction and next-session handoff.
No language/compiler code changed and FN001's delivery is unchanged.
Verification: `npm run verify` exited 0 with 318 tests passing, no failures
or skips, and all twelve isolated regression proofs passing; evidence:
`.build/tooling-direction-verify.log`. This checks the existing compiler,
not the proposed tooling. T004's earlier timing failures remain recorded
and unresolved; this successful run does not establish their cause.

## Libraries, platform services and packages direction (2026-10-08)

The user requested distinguishing Bumpus libraries compiled to the host
target, FFI bindings and dependency-inverted services implemented through
host-language libraries, then added package management. Recorded PKG001
in the tooling brief and backlog; updated LA001, language direction and
handoff. Planning includes source packages/host-callable export assessment,
service contract/provider substitution, combined host/Bumpus dependency
resolution, manifests/locks, identity, compatibility and target/runtime
availability. Effect Platform's primary introduction was checked as a
conceptual precedent; its mechanisms are not adopted. No compiler code,
package manager, binary ABI or provider mechanism is implemented/selected,
and FN001 scope is unchanged.
Verification: `npm run verify` exited 0 with 318 tests passing, no failures
or skips, and twelve isolated regression proofs passing; evidence:
`.build/pkg001-direction-verify.log`. This validates existing behavior,
not the proposed package/interop features. T003/T004 remain open.

## FN001 merged (2026-10-09)

User approved merge and push. main had gained eight docs-only planning
commits (2190c8f..340953a: FX001 do notation, error rows, STD001, LA001,
tooling, PKG001); they were merged into fn001 (9527233). Conflicts: the
T003 row (fn001's extends main's; kept fn001's) and two different T004
items (main's large-source timing item kept as T004; fn001's unidentified
harvest failure renumbered T005); progress kept both sides. Clean `rm -rf
output && npm run verify` on the merged tree: exit 0, 541 + 12 tests,
twenty-two proofs (.build/fn001-merge-verify.log). main fast-forwarded to
fn001 and pushed to origin; worktree and branch removed.

## FX001 Task 1: runtime shape measurement (2026-10-09)

Branch fx001. No compiler change. Added scripts/effect-probe.mjs (driver:
explicit build 300 s / run 120 s timeouts, five repetitions, checksums
verified, load averages before and after each batch),
scripts/effect-runtime.mjs (Go prelude: `bumpusCtx` list, non-zero-sized
`bumpusMarker`, `bumpusAbort`, lifted `bumpusHandle` returning
`(result, abort)`, `bumpusCleanup`, defect report and `main` wrapper),
scripts/effect-semantics.mjs (Step 2 programs and independently written
expected output) and scripts/effect-programs.mjs (Step 3 loops and the
generated lifted-helper program). Semantic checks: all 7 modes pass (clause
reaches the outer handler; aborts cross unrelated and same-key inner
handles to their target; clause failures after the helper returns reach
the outer handle; nested blocks unwind LIFO; cleanup that handles a
failure internally lets the abort continue; two cleanup failures print the
three confirmed report lines in order, exit 1; normal-exit cleanup
failures; crash not caught by handle with cleanup run; guard line; 1,000
markers distinct). A first run of `abort` failed on my own expected output
(two nested blocks give `d2 d1 d2 d1`, I had written one pair); corrected
the expectation, not the program. Two mutants (handle catching every
abort; clause run in its own context) each fail their check (scratchpad,
not committed). A second full run reused Go's build cache (identical seed
per repetition; 0.2-0.4 s builds) and was discarded; the seed now varies
per run. Measurements (.build/fx001-task1/run3.log): median `go build` 0.83 s
/ 1.53 s / 2.91 s at 1,000 / 2,000 / 4,000 helpers (bound 10 s). Decision:
ADOPT the shapes. Details in findings "FX001 Task 1".

### FX001 Task 2: Unit, blocks and let (2026-10-09)

Branch fx001. No existing test assertion changes; the five bootstrap
snapshots are byte-identical (verify's snapshot tests).

- What changed: Format.Lex reserves `effect handler handle with let defer
  Unit ctl resume` at once (controller ruling; `pure` stays a name).
  Domain.Syntax gains `UnitRef`, `UnitValue`, `Block` and `Item` (`Let`,
  `Discard`); the new Format.Parse.Block parses `{}` (Unit), items
  separated by `;` (a trailing `;` makes the value `UnitValue` at the
  closing `}`, which marks the block trailing; `{ let x = 1 }` is E_SYNTAX
  `Expected ;` at `}`) and `()`; `{` joins the loosest expression dispatch,
  every item nested (128 nested blocks parse, 129 are E_NESTING). Domain.Type
  and the IR gain `TUnit` (Go `struct{}`, value `struct{}{}`); Resolved,
  Checked and IR gain `UnitValue`, `Block` and `Item`. Features.Resolve.Block
  threads the scope through the items (new Fresh `thread`, a balanced
  traverse); a `let` is in scope for later items only, shadowing as a match
  binder, its LocalId taken before its expression's binders. The resolver's
  scope and the checker's locals became maps (by name, by LocalId) so a
  20,000-let block costs no scan per lookup. Features.Check.Block: `let` is
  monomorphic, discards may have any type, the block's type is its value's.
  Check.Hint adds `TrailingSemicolon` (rendered `; remove the trailing ;?`)
  on a mismatch whose found expression is a trailing block. Unit is
  comparable (always equal; ordering lowered through an inline
  `func(struct{}, struct{}) int` so both operands still run) and prints
  `()`. Format.Go.Block lifts each block to `bumpusFn{f}Block{k}` (pre-order,
  counter shared with Match/Lambda/Pipe/Apply), captures in LocalId order
  (Capture `withoutAll`), each `let` a typed `var` plus `_ = x` (typed
  because an arity-one function value is a lifted Go func of unnamed type;
  the brief's `x :=` would leave it unnamed), `_ = e` for `let _` and
  discards, `return` the value. A Unit `main` emits `func main() {
  bumpusFn<n>() }` and prints nothing; `import "fmt"` is emitted only when
  main prints or a printer appends an Int/Bool field. The style gate's
  applicative-module list adds Format.Parse.Block. The interpreter
  (test/poly-parse.mjs, test/poly-oracle.mjs) reads and runs blocks, `let`,
  `()`, `{}` and `f()` calls.
- Tests seen failing first: test/fx-block.test.mjs, 86 tests, 85 failing
  and one passing before any code (`1 + { 2 }` was already `Expected an
  expression` at `{`, kept as a characterization row); log
  .build/fx001-task2-red.log. One test-construction slip fixed after GREEN
  (the `()` and `f()` rows pointed at the first occurrence, inside `main()`
  and `fn f()`). The 20,000-let timing test moved to
  test/fx-block.serial.test.mjs after the first verify: under the parallel
  run it took 999 ms against its 1,500 ms bound (load about 5).
- Isolated mutants (scratchpad copies, not committed), each failing its
  rows: block items emitted in reverse (3 order probes); hint ignoring the
  span (the `{ 1; () }` row); a let never entering scope (2 run rows); Unit
  ordering returning 1 (the two boxed `<=`/`>` rows); Unit main printing
  (both silent-entry rows).
- Scale: 20,000 lets compile to Go in 490-510 ms, 40,000 in 915 ms, 80,000
  in 1,739 ms (linear, no stack failure); bound 1,500 ms.
- Reach: Parse → Resolve → Check → Specialize → Go, built and run in one
  batch (two Unit-main programs via runGo, which the batch's Println shape
  check does not admit); the interpreter agrees on every run row and probe.
- GREEN: `rm -rf output && npm run verify` exit 0: 626 parallel tests and
  13 serial (was 541 + 12; +85 and +1), zero failures/skips, twenty-two
  regression proofs, load 3.6-6.1; the serial 20,000-let test 535 ms of
  1,500 (log .build/fx001-task2-verify2.log; the first run, before the
  serial split, .build/fx001-task2-verify.log, also exit 0).

### FX001 Task 3: effect rows and scoped-label unification (2026-10-09)

Branch fx001. Behavior-preserving: no syntax writes a row yet; every
existing `TFun` carries the closed empty row and every `TData` empty row
arguments. No existing assertion changes; the five bootstrap snapshots are
byte-identical (verify's snapshot tests).

- What changed: new Domain.Ids (`TypeId`, moved and re-exported by
  Domain.Type; `EffectId`) and Domain.Row (`Row t v`, `Label t`,
  `EffectRef`, `LabelKey`, `TypeHead`, `labelKey`, `closedRow`, `openRow`,
  `isPure`; parameterized over the argument type, so Domain.Type imports
  it; `Row` hides Prim's). Domain.Type: `TFun (Ty v) (TyRow v) (Ty v)`,
  `TData TypeId (Array (Ty v)) (Array (TyRow v))`, `THandler (Label (Ty
  v)) (TyRow v)`; the Monad/Bind instance is gone, replaced by sort-aware
  `substitute`/`substituteRow` over `Substitution v w = { types, rows }`
  (a row tail splices its image: labels appended, its tail the new tail);
  Functor is `substitute` with `TVar`/`openRow`. Spines are walked as
  arrow nodes (`stagesThrough`, `foldStages`: no record per arrow);
  `spine`, `arrows`, `ground`, `children`, `rowsOf`, `rowArguments` and
  `typeHead` moved to the new Domain.Type.Parts (250-line limit). The
  checker's substitution moved to Features.Check.Subst (`Subst { types,
  rows, fresh }`: fresh row metas count down from -1, apart from the
  checker's, which count up; `walkRow`, `resolveRow`), binding and the
  depth bound to Features.Check.Binding (`bindType`, `extendRow`,
  `bindTail`, `exceedsLimit` counting label arguments one level deeper),
  both re-exported by Features.Check.Unify, whose `TFun`, `TData` and
  `THandler` cases unify rows through the new Features.Check.UnifyRow
  (Leijen 2005 §7, a `tailRec` loop over labels, first occurrence by key,
  the side condition `tail(r1) ∉ dom(θ)` in both the rewrite and the
  left-over-entry cases; `unifyRowsTraced` also returns `RowEvent`s by
  `OccurrenceId`, Features.Check.Occurrence; Features.Check.RowSide holds
  the operand walk). `Failure` gains `RowMissing`, `RowExtra`,
  `RowSharedTail` and `RowMismatch` (tails alone differ: not in the brief,
  needed for closed against rigid); Require reports each as the existing
  whole-type E_TYPE mismatch. Specialize erases rows; `THandler` is an
  Internal error in Lower and Require and abstract to coverage until Tasks
  5 and 6. Scheme numbers row holes with type holes. Regression row
  `occurs` now mutates Features.Check.Binding.
- Tests seen failing first: test/unify-row.test.mjs and
  test/row-substitute.test.mjs (both failed to import
  output/Domain.Row; log .build/fx001-task3-red.log), then 14 tests pass:
  scoped commutation and order, first occurrence (mismatch never skips),
  Fail keys by payload identity (deferred keys match nothing until known),
  the side condition for `Clock + ...r`/`Log + ...r` and for a left-over
  entry, both in a child process with a 20 s timeout (the generated test
  then refuses to run if it failed), `RowMissing`/`RowExtra`/
  `RowMismatch`, 1,500 generated pairs (959 unify; 54 `RowSharedTail`)
  against the independent recursive oracle test/row-oracle.mjs (same
  acceptance, symmetric acceptance, scoped-label equality, acyclicity,
  equal normal forms up to renaming), 1,000-label rows, arrow rows in
  `unify` (occurs and depth through label arguments), traced events, and
  five substitution laws. Test support only changed elsewhere: value
  construction gains row arguments, two renderers (test/fn-shape.mjs,
  test/fn-checked.mjs) leave out pure rows, and imports follow the moved
  names.
- Isolated mutants (scratchpad copy, not committed): the rewrite-case side
  condition removed, and the left-over-entry one removed: each fails the
  timeout test at 20 s and the generated test at once; first occurrence
  replaced by last (`findLastIndex`): three tests fail.
- Found and fixed on the way: a strict `where` binding resolving both
  types on every `expectType` (the mismatch message) made the `occurs`
  regression mutant overflow instead of reporting, and cost about 2x in
  Require; it is a function now. A helper frame per applied level in
  `unify` overflowed test/unify-arrow at 1,000 levels; the fold is back in
  `unifyHeads`. `compare` on applications compares row arguments before
  type arguments so the recursive comparison stays last.
- Cost: fn-linear forms at 20,000 parameters through Specialize, alone,
  5 runs each, this build (before the final `compare` change) against an
  isolated build of e110526 (ms, medians): value 415/403, over 605/534, lambda 542/539, mismatch
  181/161, partialFirst 423/396, partialAll 300/289, parenthesized
  397/400, pipe 289/309. Minimum `--stack-size` for test/poly-depth's
  1,000-deep check: 575 KB (was 559).
- Differential: a scratch variant of scripts/differential.mjs comparing
  resolve and check by acceptance only (their types now carry rows by
  design) against the e110526 build: 0 differences over 2,486 harvested,
  1,029 fuzz, 1,000 match and 1,000 mutation sources and 1,085 name
  probes. Its harvest run (the suite under the hook) failed four timing
  bounds (fn-linear partialFirst 1,022 ms, partialAll 702, pipe 970; the
  serial 20,000-let test, run there in parallel, 2,130 ms).
- Reach: unit and generated tests drive Domain.Type, Features.Check.Unify
  and UnifyRow directly; through the pipeline only pure rows exist, which
  every existing test exercises.
- GREEN: `rm -rf output && npm run verify` exit 0: 640 parallel tests
  and 13 serial (was 626 + 13; +14), zero failures/skips, twenty-two
  regression proofs, load 2.0-5.9 (log .build/fx001-task3-verify2.log; an
  earlier run, .build/fx001-task3-verify.log, failed only the `occurs`
  proof above).

## R003 Waxwing rename (2026-10-09, verification in progress)

User approved the Bumpus -> Waxwing / `.wxw` migration and subagent help.
Work uses the existing isolated FX001 tree at 3481468 (Tasks 1-3), with
main and its pre-existing editor setting untouched. Separate agents handled
current documentation and test identity edits; a fresh read-only reviewer
found only a stale `Provisional name` sentence, which was corrected.

CLI is scripts/waxwing.mjs, npm script waxwing; packages are waxwing,
waxwing-style and waxwing-bootstrap. Renamed nine example/negative sources;
updated Go names/panics, temporary prefixes, harvest instrumentation,
current documentation, active FX001 documents, backlog and handoff. Historical
plans/progress/findings, prior naming evidence and branding provenance remain.
ADR 009 records the decision. No semantics, verbs, aliases, extension-based
rejection or final artwork were added.

Evidence so far:
- Before code edits, `npm run verify` exited 1: 638/640 parallel tests
  passed; fn-linear lambda 1604.135291 ms > 1545 ms and mismatch
  819.499333 ms > 525 ms. Serial tests/proofs not reached; FN006 owns the
  recorded failure/next action. Log .build/waxwing-baseline-verify.log.
- RED: renamed test/program.test.mjs against original compiled output
  failed only the expected old usage text (8 pass, 1 fail),
  .build/waxwing-usage-red.log. `npm run build` then passed with zero
  warnings/errors, .build/waxwing-build.log.
- All five examples emitted snapshots equal to the old bytes under only
  Bumpus/Waxwing and bumpus/waxwing substitutions, then ran through
  `npm run --silent waxwing -- run`: outputs saved in
  .build/waxwing-examples.json. Program/compiler/shell tests: 21 passed,
  no failures/skips, .build/waxwing-cli-green.log.
- Isolated source restoration: copied the healthy source/tool/test/output
  tree into .build/waxwing-name-regression, restored only Format.Arguments'
  old usage text, rebuilt successfully, then test/program.test.mjs failed
  only the usage assertion (8 pass, 1 fail). Logs
  .build/waxwing-name-regression-{build,test}.log. Live source unchanged.
- Post-rename `npm run verify` exited 1: 639/640 parallel tests passed;
  `twenty thousand declarations compile and run` took 5.106579416 s > 5 s.
  Serial tests/proofs not reached. Log .build/waxwing-verify.log; T004
  records the timing failure rather than concealing it with a rerun.
- During that validation, unrelated checker edits appeared in five files,
  followed by missing output/Format.Parse/index.js in a harvest smoke
  attempt (ERR_MODULE_NOT_FOUND; no hook behavior exercised). Concurrent
  diff/hashes preserved in .build/waxwing-concurrent-{edits.patch,files.json};
  smoke diagnosis .build/waxwing-harvest-race.log. Asked the user to pause
  the other FX001 worker; combined-tree verification awaits a stable tree.

No whole-suite success, merge, commit or push is claimed by this entry.

## R003 paused-tree validation and supplied branding (2026-10-09)

The user confirmed the other worker paused. Its eight changed source files
remain byte-identical to .build/waxwing-paused-files.json; no worker edit
was reverted or folded into the rename's semantic claims.

- Combined paused tree: `npm run verify` builds with zero warnings/errors,
  passes strict-rebuild/structural gates and 634/640 parallel tests. Five
  fn-linear bounds fail (exact timings in FN006); unify-row's deferred-Fail
  assertion expects RowMissing but receives Subst. R003 records the worker's
  remaining test/settlement next action, without changing its assertion.
  Log .build/waxwing-paused-verify.log. Serial tests/proofs not reached.
- An accidental extra paused-tree verify ran while creating the isolated
  validation tree because its working directory was wrong. Its log is
  preserved as .build/waxwing-paused-extra-verify.log: 636/640 passed, three
  fn-linear timing failures and the same row assertion. The mistaken
  relative log-move command also failed before correction. Neither run is
  isolated evidence or a hidden retry to claim a pass.
- Isolated rename-only tree: .build/waxwing-validation has the renamed
  code/tests/packages and the original 3481468 versions of the eight worker
  files (.build/waxwing-validation-scope.json). `npm run verify` builds with
  zero warnings/errors, passes strict-rebuild/structural gates and 639/640
  parallel tests. Only pipe at 20,000 parameters exceeds its unchanged
  750 ms bound (942.893 ms); .build/waxwing-isolated-verify.log. FN006 owns
  this existing parallel-timing exposure. No whole-suite green is claimed.
- Ran the remainder explicitly, without rerunning/omitting the failed
  parallel tests: all test/*.serial.test.mjs via --test-concurrency=1,
  13 passed, zero failures/skips (.build/waxwing-isolated-serial.log);
  scripts/regression.mjs, all twenty-two healthy/mutant proofs passed
  (.build/waxwing-isolated-regression.log). Statuses in
  .build/waxwing-isolated-remaining-results.json.
- The WAXWING_HARVEST/waxwingHarvest smoke passes on stable rebuilt live
  output, recording its source exactly once (.build/waxwing-harvest-smoke.log).
- User supplied the final flight-lines logo assets in main, then confirmed
  the files visible there are right after discussing kerning. Copied all
  five assets/notes byte-for-byte into fx001; hashes recorded in
  .build/waxwing-branding-hashes.json. Inspected the white preview, parsed
  both SVGs and confirmed no scripts/raster/external references. Transparent
  logo PNG is 2048 x 1991; preview 530 x 515. README uses the logo PNG;
  branding README links vector masters/notes and archived Bumpus provenance.
  No artwork was generated or edited by this migration.
- Fresh read-only review found no remaining rename blockers. The stale
  provisional sentence and harvest-property abbreviation were corrected.
  git diff --check passes. Current FX001 status/handoff distinguishes the
  implemented rename from the incomplete worker review fixes.

## R003 final rename evidence (2026-10-09)

The original 3481468 compiler was rebuilt in .build/waxwing-baseline-compiled
for a differential comparison. Its first scratch build failed because the
copy omitted tools/style/src (.build/waxwing-original-build.log); supplying
that unchanged directory fixed the setup, and the next build passed with
zero warnings/errors (.build/waxwing-original-build-fixed.log).

A scratch copy of scripts/differential.mjs normalizes only Bumpus/Waxwing
and bumpus/waxwing in emitted-Go hashes; all seven phase comparisons and
diagnostic comparisons remain. The full harvested corpus comparison was
interrupted (status 130) after several minutes without a report; T006 owns
the investigation. The bounded comparison used sources up to 20,000
characters (2,433 captured sources, 53 stress sources outside this optional
comparison only). It exited 0: 2,433 harvested, 1,029 fuzz, 1,000 match and
1,000 mutation sources, plus 1,085 isName probes; zero differences. Log
.build/waxwing-differential.log; scope .build/waxwing-differential-scope.json.
The bounded run had already completed when an interrupt was requested.
A redundant memoized-hash scratch experiment was then stopped (status 130)
and is not validation evidence; the final scratch checker was restored to
the successful version. No maintained differential check was weakened.

Final smoke: live npm waxwing run examples/answer.wxw prints 42; all eight
paused worker files still match their saved hashes; current branding assets
match the user-supplied originals (.build/waxwing-final-smoke.log).
The user confirmed the visible logo files are right. Read the supplied
Claude continuation prompt and the local SDD ledger; they corroborate the
paused Task 3 review-fix state. No further effects implementation was
started by this rename task.

Rename implementation is complete on fx001. Full verification is **not
green**: the isolated rename tree has the recorded pipe timing failure,
and the live combined tree also contains the unfinished deferred-row test
mismatch plus timing failures. Serial continuation (13) and all twenty-two
regression proofs pass; earlier failures remain recorded. The rename and
eight preserved FX001 worker files remain uncommitted; main is unchanged.
For the continuation, commit the rename separately from Task 3 review fixes;
finish those fixes/tests and re-review before Task 4. No merge or push.


## FX001 Task 3 review-fix continuation (2026-10-09)

The user resumed FX001 after the rename's separate commit 40cf312.
Preserved and completed the eight paused source files: deferred Fail keys
postpone the whole original row equation with type/row/fresh/event rollback;
settleRows retries after other constraints and preserves undecidable pairs;
groundErased is used only for Seeds/Resolve monomorphism while strict
ground remains strict. RowOccurs distinguishes a row's occurs failure.
The left-over-right path also needed a deferred-key guard: new tests first
failed 9/10 with RowExtra, then passed after that guard. Exact closed/open
reflexivity, one-Fail settling, closed deferred right, never-skip-first,
rollback, retry, arrow continuation and erased grounding cases are covered.

The independent transactional oracle now models rollback, postponement and
settling. Generators include deferred Fail arguments, same-family
Error(Int)/Error(Bool), arrow label arguments and nonempty starting type/row
substitutions. Original 1,500-pair solved laws (including symmetric
acceptance and scoped equality) remain; 2,000 further pairs in both
directions distinguish pending acceptance from solved equality and compare
settling after ordinary constraints. Focused run: 44/44 pass, no skips
(.build/fx001-task3-fix-focused.log). Seven isolated source mutants all
compiled successfully then failed intended assertions; full logs/results
in .build/fx001-task3-fix-mutants, summarized in the local Task 3 report.

Verification history retained:

- First clean-output npm run verify exited 1; build had zero warnings/
  errors and gates/strict-rebuild passed, but parallel match-lift timing
  was 1670.670250 ms >1500 (643/644 pass). Exact raw log:
  .build/fx001-task3-fix-verify.log. T003 records evidence/next action.
  Explicit serial continuation then passed 21/21, no skips
  (.build/fx001-task3-fix-serial.log); no unchanged full rerun hid the failure.
- User-authorized FN006 prerequisite moved the byte-identical
  fn-linear.test.mjs to fn-linear-timing.serial.test.mjs; the existing
  fn-linear.serial.test.mjs stays. Controller then authorized extracting
  only match-lift's timing block to match-lift-timing.serial.test.mjs,
  keeping semantic tests parallel. Both timing workloads, all constants,
  assertions and bounds are identical (hash/block identity records in
  .build/fx001-task3-fix-{timing,ladder}-identity.txt). This applies the
  existing suffix-driven serial policy; no checks are skipped or weakened.
- After that actual scheduling change, a second clean-output npm run
  verify exited 0: 356 modules, zero source/library warnings/errors,
  pinned formatting, strict-rebuild/structural gates, 643 parallel tests
  plus 22 serial tests, zero failures/skips, and all 22 existing regression
  proofs. Ladder: 410.995667 ms test duration against unchanged 1500 ms
  timed-compilation bound. Complete raw log:
  .build/fx001-task3-fix-verify-serial-scheduling.log.

The row fix is verified through direct semantic tests/oracles; no syntax
can create nonempty effect rows yet. Task 5 must settle after body
constraints and diagnose remaining unknown families. Deferred equations
currently carry no spans/provenance; Task 9 must preserve/recover origins
when integrating traced retries. UnifyRow is 249 lines. Both are explicit
handoff concerns, not claims of completed later tasks. Active effects ADR
references now use 010 (009 is naming). Ready for independent review before
Task 4; no merge or push. Local report/ledger:
.superpowers/sdd/2026-10-09-effects-plan/{task-3-report,progress}.md.


### FX001 Task 4 — effect signatures, operations and Console (2026-10-09)

Implemented sorted signature variables with one rigid ambient row,
explicit rows, declared operations, stage consumption, Console print and
Unit entry output. Rows erase from specialization arguments. Field and
operation arrows default to pure, with declared effect names available;
lambda annotation omissions share the lambda's own fresh ambient row.
Program.Compile explicitly rejects user effects before specialization;
handlers and user effect execution remain later tasks. Wire diagnostics
carry related: [] with existing messages and spans preserved.

Clean-output npm run verify exited 0 (.build/fx001-task4-verify.log):
zero build warnings/errors, formatting/structure/strict-rebuild gates,
672 parallel tests, 22 serial tests, no failures or skips, and all 22
existing actual-source regression proofs. Four additional isolated actual
source mutants built and failed their named regressions: lambda annotation
omission, 20,000-arrow row collection, row argument erasure and effect
names in field types (.build/fx001-task4-sensitivity/{results.json,*-test.log}).
Earlier failed runs remain documented in the local Task 4 report; no
unchanged rerun hid a failure. Concrete malformed-input validation gaps
are BACKLOG FX004, with reproductions and the Task 5 next action.
No merge or push. Implementation/evidence:
.superpowers/sdd/2026-10-09-effects-plan/task-4-report.md.

### FX001 Task 5 — handlers and typed failures in Check (2026-10-09)

Implemented handler values, `with`, `handle`, and `fail` through Parse,
Resolve, and Check. Handler clauses are checked against declared operations;
`with` consumes the handler capability while preserving the outside row;
`handle` settles concrete `Fail(E)` keys and forwards unhandled error
families. Deferred retries preserve the original semantic failure category
and `fail` span. Nested failures are traversed through their payloads.

Row-parameterized ADTs support interleaved, multiple type/row parameters,
bare effect labels, and `pure`; source sorts are retained while VarIds stay
canonical (type slots first). The parser remains Applicative-only; Handler
type syntax is isolated in Format.Parse.HandlerType. A declared ADT named
Handler wins for `Handler(Foo)`, while `Handler(Clock)` resolves as a handler
type when no such ADT exists. Duplicate effects, operations, effect/type
parameters and function/handler binders use the existing duplicate
diagnostics. Both written row forms reject repeated or nonfinal tails.

Program.Compile rejects checked Handler/HandlerValue, With, Handle and Fail
nodes, plus Handler types in signatures, expressions and every constructor
field, before Specialize. The iterative type walk stays stack-safe at a
20,000-arrow signature. This is Check-only support: specialization/lowering,
runtime behavior, and Go emission remain later FX001 tasks.

Root audit findings 1–13 are fixed and recorded with reproductions in
.superpowers/sdd/2026-10-09-effects-plan/task-5-root-audit.md. The previous
FX004 validation gaps are closed. Focused handler tests pass 81/81; the
large-source suite passes 15/15, with 20,000-type duplicate rejection at
475 ms against its unchanged five-second bound. Eleven new isolated source
mutations prove the nested Fail, duplicate validation, deferred diagnostic,
metadata guard and duplicate-scan timing regressions.

Clean-output `npm run verify` exited 0 in
.build/fx-handler-task5-verify5.log: zero build warnings/errors, pinned
formatting, strict rebuild and structural gates, 722 parallel tests and 22
serial tests with no failures or skips, and all 33 actual-source regression
proofs. Earlier real failures remain preserved: verify2 exposed duplicate
and resolver-metadata compatibility issues; verify4 exposed eager
`when`-argument evaluation in duplicate scanning (6.92 s against the
unchanged five-second limit). Those defects were fixed and their regression
proofs added before verify5. Full interfaces, evidence and the remaining
Task 9 origin-provenance handoff are in
.superpowers/sdd/2026-10-09-effects-plan/task-5-report.md. No runtime or
specialization behavior is claimed for this task.

### FX001 Task 6 — effect specialization with erased rows (2026-10-09)

Resumed in a Claude Code cloud session on branch claude/vibrant-cerf-3km61i
(fast-forwarded to fx001 at 9a6befd; no .worktrees, ruling recorded in the
SDD ledger). The local SDD ledger of Tasks 1-5 was never committed; it was
recreated from git and this file. Task 6 was implemented inline by the
controller before the superpowers skills were linked into .claude/skills
(32ee2d2); it then received an independent task review.

Implemented: effect keys (EffectRef, ground type arguments) in the one
specialization worklist, created on first reference; user effect keys fill
their operations' types beside their source (Resolved.OperationInfo gains
`syntax`), so they reach type keys and the effect keys of handler types;
`Handler(L …)` lowers to L's key in bodies and constructor fields; rows are
erased everywhere. The IR gains `THandler EffectKey`, an `effects` table and
nodes OperationRef, Perform, HandlerValue, Install, Handle and Abort (fail;
`handle` clauses and aborts carry the payload's declared family). Check.Nested
judges one reference graph over type and effect declarations (constructor
fields, operation parameters and results, `Handler(L …)` edges); Grow, the
mutual pair and the data/effect cycle are E_SPECIALIZATION at the nested
reference, their bare-parameter versions compile. A function whose type
variable appears only in its own row's labels is polymorphic (it crashed
specialization before). Features.Check.Unlowered is replaced by
Features.Specialize.Unlowered over the emitted IR: effect layouts or effect
nodes stop at E_INTERNAL "unlowered effect"; unused effect declarations reach
Go unchanged. Only keys with type arguments count toward the 10,000 limit.
Tests reach Specialize directly (test/fx-specialize.test.mjs, 18 tests);
executable probes wait for Task 7.

A Task 5 parser defect surfaced: `with R` inside `Handler(L with R)` was
silently dropped (and rows after non-arrow types elsewhere). Fixed by a
Sonnet implementer in 5da7865 and 3aa1217 (round 2 pending at this entry),
reviewed by Opus; meaningless rows are now E_SYNTAX "Unexpected effect row".

Evidence: RED 15/18 (.build/fx001-task6-red.log; three characterization
tests passed before). Clean `npm run verify` at 85c5867
(.build/fx001-task6-verify.log): zero build warnings, gates pass, 752/752
parallel tests; serial phase 13/22 — the 9 failures are fixed timing bounds
that fail identically on the pre-Task-6 baseline 9a6befd on this container
(BACKLOG T007); regression proofs, run explicitly: 33/33 (.build/fx001-
task6-regression{,2,3}.log; four duplicate-declaration rows now expect an
accepted program because the old guard no longer masks them). Test-helper
defect fixed: test/poly-keys.mjs built a 5,000-deep JSON message eagerly
(stack overflow here). Task review (Opus): spec ✅, quality Approved, no
Critical/Important; Minor items deferred in the ledger.

## FX001 spec revision: `defer` must not fail (2026-10-09)

Before Task 8, the user was asked how a cleanup failure during an abort
should behave (abort-to-defect conversion as specified, drop, replace, or
suppressed causes). The user chose the static rule, after Swift's `defer`:
a deferred expression that performs an unhandled `Fail` is E_EFFECT
`defer must not fail, but it performs <L>`; cleanup that can fail handles
its failure inside the deferred expression. Only defects can fail cleanup,
so a pending typed abort reaches its `handle` unless a cleanup on the way
raises a defect (the abort then heads the report) or diverges (corrected
per CF001 §11). Spec §2 (`defer`
rule), §3 ("Cleanup failures", with rejected alternatives), §5 (report
example, probes 6 and 11), plan Global Constraints and Tasks 8, 10 and 12,
findings and the handoff were updated. Docs only; no code changed.

### FX001 Task 7 — Go lowering of handlers, operations and failures (2026-10-09)

Subagent-driven: Sonnet implementer (e9a613f, fix round 4b80bd1), Opus task
review and scoped re-review. Effect programs now build and run. ctx mode is
chosen over the emitted IR (any effect layout or effect node); in it every
function, stage, lambda, constructor, lifted helper and function type takes
`ctx *waxwingCtx` first; otherwise Go output is unchanged (bootstrap
snapshots byte-identical, Console-only programs without ctx). Runtime (Task
1's adopted shapes, emitted only when used): immutable context list,
non-zero-sized markers, targeted aborts recovered only by their own lifted
`handle` helper. Keys: user effect EffectId+1, Fail families by declared
head (negative keys); missing handler is `panic("no handler for L")`.
Handler structs per layout (empty for Console/Fail layouts), perform
functions call clauses with the frame's outer context (intercept-and-
forward), clauses lifted like lambdas. Features.Specialize.Unlowered is
deleted; every 'unlowered effect' assertion was replaced by an executable
assertion (test/fx-run.test.mjs, 24 programs with exact stdout).
Two checker defects found and fixed: constructor patterns dropped row
arguments (Check.Match/Tables), and consumption did not resolve a bound row
tail (Check.Consume); Check-level tests in test/fx-check-fixes.test.mjs,
each failing with its fix reverted. Review found one Critical: the clauses
of one `handle` were installed in reverse (runtime panic for Error(Int) vs
Error(Bool) clauses); fixed with probes. Regression rows: block-order needle
updated; handler-metadata replaced by effect-free-ctx.

Evidence: `rm -rf output && npm run verify` (.build/fx001-task7-verify.log):
build, gates, 786/786 parallel tests; serial 12/22, the 10 failures are the
BACKLOG T007 environment bounds (same set on pre-change baselines);
regression proofs 33/33 (.build/fx001-task7-regression.log). The
fx-block.serial 20,000-let test sits at its 1,500 ms bound on this
container: 49717bc 1,533-1,574 ms vs Task 7 1,386-1,505 ms, alternating.

### FX001 Task 8 — `defer`, `crash`, cleanup and the defect report (2026-10-09)

Subagent-driven: Sonnet implementer (041cb31; fix round d5bfa8d, resumed
after a container restart), Opus task review and scoped re-review.
`defer e` (block item) and `crash(value: a): b` (built-in, printable
argument, no effect, uncatchable) run through every phase. Cleanup runs
LIFO, exactly once per exiting activation, in the registration context;
the defect report follows spec §5 (exit status 1, first line the original
cause, later lines `cleanup failed: `; `<not printable>` decided
statically). Runtime pieces (Format.Go.Cleanup, Format.Go.Report) are
emitted only when used; defer and crash do not force ctx; blocks without
`defer` emit no Go `defer`. Conventions recorded: with no pending cause the
first cleanup crash is the unprefixed first line; Go runtime panics print
as `panic: <text>`.

The user's rule that `defer` must not fail is enforced soundly after
review: the first implementation checked only labels, so five programs
(callback parameters with ambient or named rows, unsettled closures,
lambdas decided later) let a typed failure escape cleanup and become a
fatal report. Ruling (controller, pending user confirmation of strict over
a lacks-Fail constraint): the deferred expression has its own row; after
the function's constraints settle, a remaining Fail label or a tail
resolved to a rigid row variable is E_EFFECT (`defer must not fail, but it
performs <L>` / `... but it may perform any effect of <r>`). Accepted
limitations (spec §2, BACKLOG FX007): the bracket idiom needs `with pure`
callbacks; a local lambda also called outside the `defer` in a non-main
function is rejected in it. Report.payloadName now walks arrow spines by a
loop (a 5,000-arrow payload crashed the compiler).

Evidence: fx-cleanup 32/32 (RED 24/26 before, then 7 new failing tests
for the fix round; seven isolated mutants caught). `npm run verify`
(.build/fx001-task8-verify.log): build, gates, 818/818 parallel tests;
serial 12/22, the 10 failures are BACKLOG T007 timing bounds; regression
proofs 33/33 (.build/fx001-task8-regression.log). Re-review probes:
legitimate defers (`defer log(1)`, `defer print(x)`, monomorphic helpers)
accepted; the check is linear (1k-8k defers).

### FX001 Task 9 — effect diagnostic provenance (2026-10-10)

Subagent-driven: Sonnet implementer (2fc7a02; fix rounds 04ab898, cee8542,
b80cc17), Opus task review and two Opus re-reviews, Sonnet re-review of the
last one-line fix. (A first dispatch was lost to a container restart; the
second was briefly stopped by a controller misreading of a user message and
resumed with its work intact.) Effect errors now carry origin, boundary and
path notes (spec §6): occurrence links live in the substitution and are
recorded on every unification path (nested arrow rows, settleRows retries,
consumption); deferred-row origins are kept apart from the function row;
note texts follow ruling R4 and the wire carries `related: [{ span,
message }]`. Resolved gains `rowSpan` on functions and parameters so
boundary notes point at the written `with` (or the parameter name when the
concerned row is nested or not the only pure row). Path hops, note count
and characters are abbreviated (`visibleLabels 4`, `pathHops 2`, `maxNotes
4`, `maxCharacters 2000` for notes); labels over 120 characters print
`Effect(…)` in headlines. Pre-FX001 diagnostics are unchanged (`related:
[]` by construction; wire JSON identical); 20,000-parameter signatures
check in about 1.5 s.

Known limits recorded: `maxCharacters` bounds notes only — a headline with a
very long type or effect name can exceed 2,000 characters (BACKLOG E011);
the late-Fail-key defer note follows let-bound locals only and otherwise
gives no note (never a wrong one; ~20 probes); origin notes may point
outside the deferred expression.

Evidence: fx-diagnostics, fx-diagnostic-origins, fx-signature 46/46; the
fix-round tests were each seen failing (the round-2 tests by the controller
against 04ab898 in an isolated worktree). Final verify
(.build/fx001-task9-fix3-verify.log): build, gates, parallel 847/848 — the
one failure is large-source "three-thousand-constructor match" timing
(BACKLOG T004; passes alone); serial phase failures are the T007 set;
regression proofs 33/33 (.build/fx001-task9-fix3-regression.log).
