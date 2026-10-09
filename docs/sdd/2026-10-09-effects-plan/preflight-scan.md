# Pre-flight conflict scan: FX001 Tasks 6-12

Scope: docs/plans/2026-10-09-effects-plan.md (cited "P n"), Tasks 6-12 plus
Global Constraints (P 42-106) and Review Focus (P 108-121); spec
docs/plans/2026-10-09-effects-design.md (cited "S n"); docs/progress.md
FX001 Task 3/4/5 entries; AGENTS.md. Read-only scan at HEAD a3b54d3
(2026-10-09). Plan header status (P 3-13) ignored as instructed.

Codebase state observed during the scan (relevant to every ruling below):

- HEAD moved during the scan: a3b54d3 ("migrate guard expectations to the
  post-specialization guard") landed after 32ee2d2. The working tree has
  uncommitted edits to src/Format/Parse/HandlerType.purs and
  src/Format/Parse/Type.purs plus untracked test/fx-handler-type.test.mjs
  (the Task 5 `Handler(L with R)` parser-defect fix recorded in the SDD
  ledger). Another worker is active; nothing here touched those files.
- Branch is `claude/vibrant-cerf-3km61i`; there is no `.worktrees/`.
- Task 6 WIP (2501024) touches 23 files; IR gained `THandler EffectKey`,
  `EffectKey`, an `effects ∷ Array EffectInfo` table, and nodes
  `OperationRef`, `Perform`, `HandlerValue`, `Install`, `Handle`, `Abort`
  (src/Domain/IR/Internal.purs). `Abort` and `FailClause` are keyed by
  `TypeHead`, not by an effect key. Effect keys are created on demand
  (src/Features/Specialize/Effects.purs `effectAt`), never seeded; Console
  and Fail get layouts with `operations: []`; only effect keys with
  non-empty arguments call `claim` (count toward the 10,000 limit).
  Features.Check.Unlowered is deleted; Program.Compile runs
  `specialize >=> guarded` with Features.Specialize.Unlowered.
  Format/Go/Expression.purs gained an `unlowered` panic stub.
- Line counts near the 250 limit that later tasks must edit:
  Check/UnifyRow 249, Parse/Grammar 246, scripts/differential.mjs 244,
  test/regression.mjs 235, Specialize/Keys 232, Domain/Syntax 227,
  test/poly-parse.mjs 226, Format/Diagnostic 225, scripts/regression.mjs
  223, Format/Lex 216, Domain/IR/Internal 201.
- Bumpus→Waxwing: `grep -i bumpus` over plan and spec is empty; both use
  `waxwingCtx`, `waxwingMarker`, `waxwingAbort`, `waxwingCleanup`,
  `waxwingFn…`, `waxwingEff…`, `.wxw`. No rename residue.

## 1. Task-pair table (21 rows: every pair in 6-12)

| # | Pair | Producer → consumer (shared file / interface) | Finding |
|---|---|---|---|
| 1 | 6-7 | 6 produces IR effect nodes, `THandler EffectKey`, the `effects` table, Specialize/Unlowered and its call in Program.Compile; 7 lowers the nodes and deletes the guard (P 431-432, 447-450, 471-472). Shared: Domain/IR/Internal, Format/Go/{Expression,Data,Usage} (6's WIP already edited them), Program/Compile. | **Conflict.** (a) `OperationRef` exists in the IR but in no plan text (P 432 lists five nodes); 7 must lower bare operations as function values. (b) The `waxwingCtx.key` value is unspecified: P 482 numbers structs by effect-key index, while S 401-402, 405-409 make the runtime key the EffectId (shared by `State(Int)`/`State(Bool)`) and `(Fail, TypeId)` for failures; IR `Abort`/`FailClause` carry `TypeHead` (incl. HeadInt/HeadBool/HeadUnit). (c) Console and Fail layouts with no operations will produce `waxwingEff{N}` structs. (d) 7's Files (P 468-475) omit what deleting the guard breaks: regression row `handler-metadata` (scripts/regression.mjs 172-179, mutates Specialize/Unlowered.purs), its probe in test/regression.mjs, and 12 `unlowered` assertions in test/fx-specialize.test.mjs, test/fx-handler-check.test.mjs and test/regression.mjs. (e) The `unlowered` panic stub in Format/Go/Expression.purs must be removed by 7. → F1, F2, F3, F4. |
| 2 | 6-8 | 8 adds `Defer`/`Crash` IR nodes (P 505-506); 6's Specialize/Body and IR helpers (`effectParts`, `blockParts`) must carry them. | Consistent once 7 deletes the guard. 8's Files omit Specialize/Body and the IR traversal helpers (see row 25). |
| 3 | 6-9 | 6 edits Check/Nested and Check/Instantiation; 9 edits Consume, UnifyRow, Format/Diagnostic. | Consistent: layout-cycle and growing-label rejections reuse existing E_SPECIALIZATION problems (P 444-446), outside §6 row diagnostics (S 554). No shared file. |
| 4 | 6-10 | 10's generator must emit only programs 6 accepts (no expanding layout cycles). | Consistent. No shared file. |
| 5 | 6-11 | 11 asserts key count = effect-free baseline + effect keys (P 620-621), consuming 6's key counting (test/poly-keys.mjs, Specialize state counts). | **Conflict.** S 427 and P 443 say every key counts toward 10,000; WIP `newEffect` claims only effect keys with arguments (Effects.purs `unless (Array.null arguments) (claim span)`), mirroring monomorphic type keys. "Effect-free baseline" is undefined anywhere (P 620, S 627-628). → F5, F6. |
| 6 | 6-12 | 12's regression row "layout edges omitted" (P 644) mutates 6's Check/Nested; 12 must not re-create `handler-metadata`. | Consistent; needs a probe that fails when Nested ignores effect edges (fx-specialize `layout cycle rejected` rows qualify). |
| 7 | 7-8 | 7 creates Format/Go/Context.purs ("runtime text and mode", P 473); 8 adds `waxwingCleanup`, `waxwingDefect`, main's recovery wrapper there (P 506-507). Both touch Format/Go.purs (`entryMain`), Go/Usage, Go/Block (lifted block helpers). | Mostly consistent with S 480-483 (`defer`/`crash` runtime without `ctx`), provided 7 structures Context.purs as independently emitted pieces, not one "effect runtime" blob. Interface gap: 7's perform functions need the guard panic `no handler for L` (S 359-360) whose report formatting is 8's; 7 should emit a typed defect value 8 can render. → F7. |
| 8 | 7-9 | none | Consistent. |
| 9 | 7-10 | 10 runs 7's Go output against the interpreter and re-validates the interpreter on 7's hand-written probes (P 584-589). | Consistent; rubric risk of copying expectations (R2). test/go-batch.mjs already exposes raw stderr/exit status (lines 174-180). |
| 10 | 7-11 | 11 times installation, lookup, unwinding of 7's lowering, bounds from Task 1's hand-written Go (P 622-625; findings "FX001 Task 1"). | Consistent. Note: Task 1 lookup at depth 10,000 took 11.8 s per 10^6 performs; 11 must fix a depth/iteration count that fits its bound, and depth must come from recursion (128 nesting limit, Task 2). |
| 11 | 7-12 | 12's mutants "clauses in inner context", "abort consumed by nearest handle", "`ctx` for effect-free programs", "`ctx` by reachability" (P 640-644) need 7's named tests. | Consistent: P 489-496 lists RF1, RF2, RF4 and snapshot tests. |
| 12 | 8-9 | 8's Check/Defer checks `defer e` against the current row (S 270-271); 9 records provenance at consumption (P 543-553). | Consistent if Defer consumes through Consume.consume (then 9's provenance covers it). Note for 8's implementer. |
| 13 | 8-10 | 10's interpreter models 8's cleanup policy and report lines (P 579-580, 596-598). | **Conflict risk.** docs/findings.md "FX001 Task 1" leaves open "a cleanup failure of any kind while a typed abort is pending turns it into an uncatchable defect listing both causes"; S 342-344 states only that an *escaping abort while another is pending* becomes a defect. Whether the outer `handle` still catches the original abort decides both 8's Go and 10's oracle. → F8. |
| 14 | 8-11 | none (spec scale list S 646-651 has no cleanup timing). | Consistent. |
| 15 | 8-12 | 12's mutants "cleanup in exit-time context", "cleanup drops pending cause" (P 642) need 8's tests (P 523-525). | Consistent. |
| 16 | 9-10 | none | Consistent. |
| 17 | 9-11 | 11's acceptance requires the §6 diagnostic with origin, boundary and path notes (P 619-620) from 9. | Consistent in order; headline text depends on F9/F10. |
| 18 | 9-12 | 12's mutants "provenance dropped", "abbreviation disabled" (P 645) need 9's tests (P 559-568). | Consistent. |
| 19 | 10-11 | Both add heavy Go-building tests to `npm run verify`. | **Conflict risk.** 10's 500+ programs (P 600-601) in a parallel `*.test.mjs` collide with T003/T004 load exposure; engineering.md says differential tooling "neither runs in verify", yet P 581 creates `test/fx-oracle.test.mjs`. → F11. |
| 20 | 10-12 | 12's verify (P 655) includes 10's test; 12 records results in findings. | Consistent (subject to F11). |
| 21 | 11-12 | 11 creates bootstrap/services.go and examples/services.wxw; 12 documents. | Consistent with P 52 (only five snapshots frozen). Snapshot tests are hand-listed (test/compiler.test.mjs 93-110, adt-*.test.mjs), so 11 must add an explicit `services.go` assertion; not in its Files. → row 26. |

## 2. Per-task self-consistency (7 rows)

| # | Task | Finding |
|---|---|---|
| 22 | 6 | **Inconsistent.** (a) Files (P 427-437) vs reality: WIP also created Specialize/Handlers.purs and edited Seeds, Resolve/Effect, Syntax, Resolved, Type/Parts, Go/{Compare,Data,Expression,Show,Usage}, test/poly-keys.mjs; Check/Instantiation (listed, P 434-435) was not edited although "growing-label recursion is rejected" is tested. (b) Step 1 tests "rows in data arguments give no extra type key" and "a pure function used at three different rows is one key" (P 457-458) already hold since Task 3 erased rows, so they cannot be "seen failing before its code" (P 103). (c) "bare-parameter versions accepted" (P 455-456) vs S 466-467 "must compile": under the Task 6 guard (P 97-99) an instantiated layout cannot reach Go; the WIP test only compiles unused declarations. (d) Commit: WIP is `wip: … (unverified)` (2501024) + a3b54d3, not P 462's message. → F12, R1, R3. |
| 23 | 7 | **Inconsistent.** Files (P 468-475) omit Go/Block, Go/Match, Go/Entry, Go/Capture, Go/Pipe, Go/Value (every lifted helper and function value must take `ctx`, P 480-481), plus the regression/test files deleting the guard breaks (row 1d). Step 1 "every bootstrap snapshot byte-identical" (P 495-496) is existing behavior and cannot fail first. Interfaces' `usesContext` list (P 479) omits bare operation references (`OperationRef`). |
| 24 | 8 | **Inconsistent.** "through every phase in this task" (P 507-508, P 100-101) but Files (P 505-509) list only Block parser/checker/lowering, IR, Context, Check/Defer. Also needed: Domain/Syntax (Item gains `Defer`), Resolved, Checked/Internal, Resolve/Expression (block items; `crash` built-in, P 321-322), Specialize/Body, Go/Usage, Format/Go.purs or Go/Entry (recovery wrapper). `defer` is already reserved (Lex.purs 59). Step 1 (P 518-527) lacks the `crash` handler-type rejection that Task 5 deferred to 8 (P 401-402) and S 261-263 require ("Required rejection tests for all four"). |
| 25 | 9 | **Inconsistent.** Files: "UnifyRow.purs (origin hooks)" (P 536-537) but UnifyRow is 249 lines and Global Constraints say new work goes in new modules (P 46-47). Interfaces (P 543-553) attribute via `RowEvent`s but omit the deferred-retry path: progress "Task 3 review-fix continuation" says deferred equations carry no spans/provenance and Task 9 must recover them; Unify.purs 58 `retry` uses `unifyRowsTraced unify untraced`. Unify.purs, Failure.purs and settleRows are not in Files. → F13. |
| 26 | 10 | **Inconsistent.** No `npm run verify` step (Steps P 584-608) vs P 103-104 "every task". Step 1 says "every executable probe of Tasks 2 and 4-8" (P 585), but Tasks 5 and 6 have no executable probes (Check-only / specialize-only by P 91-99). "Independent parser extension" cannot extend test/poly-parse.mjs (226 lines) in place; it also inherits FN006(1) (applied-value zero-argument calls, poly-parse.mjs 98). Shrinker "keep only while still well-typed" (P 606) needs a type checker; the interpreter imports no compiler code (P 580), so the shrinker's typing oracle is unspecified. |
| 27 | 11 | **Inconsistent.** No production code, so P 103 "seen failing before its code" cannot apply to its timing tests. "20,000 `let` items" (P 626) duplicates test/fx-block.serial.test.mjs 15 (through `compile`; only "through the CLI" is new). "Effect-free baseline" undefined (row 5). Files omit the snapshot assertion for bootstrap/services.go (row 21). |
| 28 | 12 | **Inconsistent.** Step 3 creates "FX004 (general resume, CPS confinement)" (P 651-652) but BACKLOG.md 74 already has FX004 (Done: Task 5 validation gaps). "FN002 done" (P 650) duplicates Task 2 Step 5 (P 216-217, BACKLOG 13 already Done). Regression rows need probes: test/regression.mjs is 235 lines, so ~11 new probes need a new probe module (pattern: test/regression-task5.mjs), not in Files (P 633). "Side condition removed" mutant loops forever: scripts/regression.mjs requires `broken.status === 1` and its spawnSync timeout (180 s) yields `null`, so the probe must self-time-out (as Task 3's 20 s child process does). |

## 3. Plan mandates a code-review rubric would flag

- **R1 Tests that cannot fail first.** P 457-458 (Task 6 row-erasure key
  tests), P 495-496 (Task 7 snapshots), P 622-626 (Task 11 timing) already
  hold before their task's code; P 103 demands RED. A reviewer will flag
  either a fabricated RED or a missing one.
- **R2 Verbatim duplicated test data.** P 585-587 has the interpreter
  reproduce the hand-written expectations "already in those tasks' tests";
  copying them into test/fx-oracle.test.mjs duplicates data. P 626 repeats
  the existing 20,000-let timing test.
- **R3 Acceptance test that asserts almost nothing.** P 455-456 "bare-
  parameter versions accepted" is satisfiable (as in the WIP,
  test/fx-specialize.test.mjs 72-75) by compiling declarations nothing
  instantiates, so the layout worklist is never exercised.
- **R4 Weakened assertions.** Deleting the guard (P 471-472) removes 12
  `unlowered` assertions and the `handler-metadata` proof; AGENTS.md
  forbids weakening assertions, so each must be replaced by a stronger
  runtime assertion, not deleted.
- **R5 Tautological key-count assertion.** P 620-621 is circular if the
  "baseline" and "effect keys" are both read from the same counters of the
  same specialize run.
- **R6 Dead stub.** WIP Format/Go/Expression.purs `unlowered` panics
  "unlowered effect"; after Task 7 it is unreachable code.

## 4. Findings needing a ruling

Each: decision, reason, cost if wrong.

- **F1 Runtime context key (P 482; S 401-402, 405-409, 488-491).** Rule:
  `waxwingCtx.key` is one int space: user EffectId for `with`, and a
  distinct encoding of `(Fail, TypeHead)` for `handle` frames; struct and
  perform-function *names* use the EffectKey index (P 482). Reason: spec
  makes the runtime key layout-independent; WIP Abort is already keyed by
  TypeHead. Cost if wrong: keying by EffectKey index silently diverges
  from S 405-409 only for ill-typed paths, but makes the "no handler" guard
  and future `ctl` differ from spec; rework in Context/Effect/Handle.
- **F2 `OperationRef` (absent from P 432, 479).** Rule: accept the node;
  Task 7 lowers it as a function value taking `ctx`, and `usesContext`
  includes it. Reason: spec S 97-98 makes bare operations with parameters
  function values. Cost if wrong: such programs panic at the stub.
- **F3 Console/Fail handler-type layouts.** Check accepts
  `Handler(Console with pure)` and `Handler(Fail(E))` (tests in
  fx-handler-check.test.mjs 191-205), though no value can inhabit them
  (S 68-70, 111-113). Rule (recommended): keep them, emit an empty
  `waxwingEff{N}` struct, and let them switch on `ctx` mode as handler
  types (S 474-475). Alternative: reject them in Check (spec-silent, a new
  diagnostic). Cost if wrong: either a spurious diagnostic later, or extra
  struct/`ctx` code for an uninhabited type — low.
- **F4 Guard deletion fallout (P 471-472).** Rule: Task 7 also removes
  regression row `handler-metadata` and its probe, and converts each
  `unlowered` assertion into an executable assertion of the same program.
  Cost if wrong: verify fails ("mutation must have exactly one target") or
  assertions are weakened.
- **F5 Which effect keys count (P 443; S 427).** Rule (spec wins): every
  effect key, including argument-free ones, counts toward 10,000; or the
  user amends S 427 to match type-key precedent. Cost if wrong: limit off
  by the number of argument-free effects; Task 11's count assertion
  depends on the choice.
- **F6 Effect-free baseline (P 620-621; S 627-628).** Rule: the baseline
  is a separate, committed source of the same scenario with handlers and
  operations replaced by direct pure calls; expected count = its key
  count + the number of distinct effect layouts listed by hand in the
  test. Cost if wrong: R5 tautology, or an unfalsifiable assertion.
- **F7 Guard-panic interface between 7 and 8 (S 359-360, 562-564).** Rule:
  Task 7's perform functions panic with a typed runtime value (not a bare
  string) that Task 8's defect reporter renders as `no handler for L`.
  Cost if wrong: Task 8 rewrites Task 7's runtime text.
- **F8 Pending abort plus failing cleanup (S 341-347; findings Task 1
  open reading; P 520-521).** Decide whether the original typed abort
  stays catchable by its `handle` once a cleanup fails during its
  unwinding. The findings' reading ("uncatchable defect listing both
  causes") matches the P 520-521 expected report. Needs the user's
  confirmation before Task 8 and Task 10. Cost if wrong: Go runtime and
  oracle both change, plus every cleanup probe.
- **F9 `Unhandled` text for failures (S 706 vs P 67, S 292-293).** S 706
  writes `Unhandled fail(DbError) in main`; Task 4/5 render labels as
  `Fail(DbError)` (fx-handler-check.test.mjs 165). Rule: keep
  `Fail(DbError)` (row display, S 556) and amend S 706. Cost if wrong:
  Task 9/11 exact-text tests churn.
- **F10 Headline and suffix wording (S 292, 541, 695, 711; P 67-69,
  347-348).** S 695 gives `Expected pure, found Log` but S 711 and P 69
  (implemented) give `This function must be pure, but it performs Log`;
  S 292/541 give a `(required by stamp at 12:3)` suffix while P 67 is
  exact without it. Rule: keep the implemented headline texts; the
  "required by" information becomes a related note in Task 9, not text.
  Cost if wrong: changes every existing E_EFFECT exact-text test.
- **F11 Where the 500-program differential runs (P 581, 600-601).**
  Rule: `test/fx-oracle.test.mjs` in verify runs the validation set plus
  a bounded generated sample meeting the census at reduced counts, named
  `*.serial.test.mjs` if it builds Go at scale; the full ≥500-program run
  with shrinker is a committed script (like scripts/differential.mjs)
  whose result is recorded in progress. Cost if wrong: T003/T004 load
  failures in every later verify, or a coverage claim never re-checked.
- **F12 Task 6 testing scope (P 97-99, 455-458; S 441-442, 466-467,
  610-612).** Rule: Task 6 asserts acceptance via `specialize` with each
  admissible layout *instantiated* (a handler or handler type at Int);
  Task 7 Step 1 adds the executable versions of spec probes 1 ("through
  stored functions"), 5 (Fail families, `Error(Int)`/`Error(Bool)`),
  9 (recursive installation runs) and 10 (admissible variants build and
  run), which no task lists today. Row-erasure key tests are recorded as
  characterization tests with a mutant proof instead of RED. Cost if
  wrong: spec probes never executed; R1/R3 review findings.
- **F13 Task 9 module placement and retry provenance (P 536-553;
  progress Task 3 continuation).** Rule: origin hooks go in a new module
  wrapping `unifyRowsTraced` (UnifyRow untouched, 249 lines); Files add
  Unify.purs and Failure.purs; tests include an origin note for a label
  that reaches the rejection only through a deferred-Fail retry. Cost if
  wrong: line-limit gate failure or notes missing for deferred keys.
- **F14 BACKLOG id collision (P 651-652; BACKLOG.md 74).** Rule: general
  resume becomes the next free id (e.g. FX006), or the existing Done
  FX004 is renamed; update S 655 and S 758 references accordingly. Cost if
  wrong: two meanings for FX004 across progress and backlog.
- **F15 Branch and worktree (P 7-8, 104-105).** Plan requires branch
  `fx001` in `.worktrees/fx001`; this session works on
  `claude/vibrant-cerf-3km61i` with no worktree. Rule: user/controller
  states which branch receives Tasks 6-12, recorded in the ledger. Cost if
  wrong: commits on the wrong branch; a later merge reconciliation.
- **F16 Concurrent worker.** a3b54d3 landed mid-scan and the parser fix
  is uncommitted in the working tree. Rule: Task 6 review starts only
  after that fix is committed (ledger already says "separate commit"),
  and no two builds run in parallel (ledger note). Cost if wrong:
  reviewing a moving target; transient regression failures.
- **F17 Task 12 regression mechanics (P 639-645).** Rule: probes go in a
  new test/regression-fx.mjs; the side-condition probe runs its unifier
  call in a child with its own timeout and exits 1 on timeout. Cost if
  wrong: over-limit file, or a proof that can never pass (status `null`).
- **F18 Task 10/11 missing steps (P 584-608, 617-628).** Rule: Task 10
  gains Step "Run `rm -rf output && npm run verify`"; Task 11 replaces
  the duplicate 20,000-let compile timing by a CLI build-and-run check and
  adds the services.go snapshot test; both state their RED exemption
  (characterization/measurement) in progress. Cost if wrong: violated
  Global Constraint P 103-104 noted by every reviewer.
- **F19 Task 7/8 Files lists (rows 23, 24).** Rule: treat Files as
  compile-guided (as Task 3 did, P 225-227) and say so in each brief.
  Cost if wrong: implementers stop on "unlisted file" or reviewers flag
  scope creep.

Consistent items checked and not needing a ruling: Waxwing naming (no
Bumpus residue); IR names `HandlerValue`, `Install`, `Perform`, `Handle`,
`Abort`, `THandler EffectKey` match P 431-432; on-demand effect keys agree
with S 413-427 and S 470-477 (layouts reached from emitted functions; unused
declarations emit nothing, fx-specialize "declared but unused effects");
IR allowlist regex (scripts/structure.mjs 24-25) admits
Features.Specialize.Unlowered and Format.Go.*; Review Focus items map to
Tasks 7 (RF1, RF2, RF4), 4 (RF3) and 9 (RF5) as stated.
