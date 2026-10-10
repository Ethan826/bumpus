# Pre-flight re-scan: plan Tasks 9-12 after Tasks 6-8 and the spec revisions

Scope: docs/plans/2026-10-09-effects-plan.md lines 542-668 (Tasks 9-12) plus
the Global Constraints and Review Focus they inherit. The scan was read-only;
no build was run. HEAD was 6f41252 at scan time (Task 8 docs, FX007 and
CF001 rows already committed). Line numbers are plan lines unless prefixed
(D = effects design, CF = concurrency-foundations design).

Facts the findings rest on (checked in code):
- src/Features/Check/UnifyRow.purs has 249 lines. `RowEvent`s
  (`Matched`, `Extended`) are produced only by `unifyRowsTraced`. Every
  caller drops them: Consume.purs:24-27 uses `unifyRows`, Unify.purs:58
  retries postponed pairs with `untraced`, and rows nested in arrow types
  go through `unifyRows`. Nothing consumes events today.
- `Domain.Syntax.NoteReason = RequiredBy String` is unused. Format.Wire
  puts the `Note` ADT itself on the wire (`related ∷ Array Note`). No
  note text exists anywhere. Format/Diagnostic.purs has 232 lines,
  Subst.purs 205, Handler.purs 216.
- Features.Check.Defer checks `e` against `openRow (Hole n)` and consumes
  its labels into the current row at the defer span with a fresh tail.
  `settleDeferred` (Check.purs, between two `settleKeys` calls) rejects
  any `Fail` with `DeferMayFail` and a rigid tail with `DeferMayPerform`
  (`...`, `...e`). A `Hole` tail is accepted but never bound (re-review
  minor).
- Runtime (Format.Go.Context:88-98, Handle.purs:133-138): a user effect's
  key is EffectId+1, so State(Int) and State(Bool) share one key. A Fail
  key is negative, by the payload's declared head, so Error(Int) and
  Error(Bool) share one key. The clauses of one `handle` are installed
  with the first clause innermost.
- Report conventions (Task 8): when no cause is pending, the first
  cleanup crash is the unprefixed first line. Go runtime panics print
  `panic: <text>`. When an abort is pending and a cleanup crashes, the
  abort heads the report and never reaches its `handle`.
- test/fx-cleanup.test.mjs (248 lines) keeps its run cases inline, and
  some cases transform the emitted Go (`injected`: the guard and newline
  escaping). test/fx-run-programs.mjs exports `cases` with stdout only.
  test/fx-block-programs.mjs exports `runs`.
- scripts/differential.mjs and scripts/differential-corpus.mjs (170
  lines) compare two compilers phase by phase. They are not a Go-versus-
  interpreter oracle. FN001's oracle pattern is test/fn-oracle.test.mjs,
  test/poly-oracle.mjs and test/poly-parse.mjs (226 lines; FN006 (1): it
  cannot parse `f()`).
- Regression proofs: rows live in scripts/regression*.mjs and probes in
  test/regression*.mjs (test/regression.mjs has 243 lines and dispatches
  external probe maps). Each row asserts `ifError` and status 1 with a
  180 s spawn timeout, so a hanging mutant crashes the runner instead of
  counting as detected. Row `effect-free-ctx` already exists (Task 7).
- verify currently fails in its serial phase on the BACKLOG T007 set
  (10 timing tests) and therefore never reaches scripts/regression.mjs.
  Tasks 6-8 ran regression separately.
- BACKLOG: FX007 (strict-defer relaxation) and CF001 (Proposed) exist.
  FX002, FX003, FX005 and FX006 are absent. FX004 is the Task 5 row
  (F14). docs/adr ends at 009, so 010 is free.
- Spec D §2 now states the own-row rule and its costs (FX007). D:369
  ("Task 8 review ruling, pending user confirmation"), CF:134 and CF:408
  still say "pending user confirmation".

## 1. Amendments

Kinds: S = stale, W = wrong, M = missing. "Ruling?" marks findings where
the controller (or the user) must decide something beyond transcription.

| ID | Task | Plan line | Kind | Issue (one line) | Ruling? |
|---|---|---|---|---|---|
| G1 | all | 104-105 | W | "`npm run verify` exits 0" is unreachable on this container (T007), and verify then skips regression proofs | yes |
| G2 | all | 105-106 | S | commits "on branch fx001 in .worktrees/fx001"; F15 moved work to claude/vibrant-cerf-3km61i | no |
| G3 | 9,12 | 66-71 | M | problem-text list lacks `defer must not fail, but it may perform any effect of <r>`; Fail label spelling (F9) | no |
| G4 | docs | D:369, CF:134, CF:408 | S | "pending user confirmation" of strictness; user chose strict for now | yes (wording) |
| G5 | 10 | 110-125 | M | Review Focus has no item for strict-defer soundness | no |
| T9-1 | 9 | 544-549 | W | Files: modify UnifyRow (249 lines, F13 says new module); no Defer/Check/Unify/Subst/Wire/Syntax; Diagnostic.purs near cap | no |
| T9-2 | 9 | 552-562 | W | provenance from `RowEvent`s, but events are dropped on every real path (Consume, nested arrow rows, settleRows retries of deferred Fail keys, F13) | yes |
| T9-3 | 9 | 552-562 | M | no provenance for the deferred row (separate from the function row) and the two defer diagnostics | no |
| T9-4 | 9 | 552-556, 568 | M | `Consumed`, `Boundary`, note reasons and note texts undefined; wire carries a PureScript ADT | yes |
| T9-5 | 9 | 568-577 | M | tests lack defer diagnostics, F9 spelling, F10 "(required by)" note, and the no-notes-on-old-diagnostics check | no |
| T9-6 | 9 | 563-566, 570-571 | M | length assertion vacuous unless the unabbreviated text exceeds `maxCharacters` | no |
| T10-1 | 10 | 586-591 | W | Files: F11 serial file missing; `scripts/differential-corpus.mjs` is the wrong tool; Task 8 cases not importable; parser near cap and cannot parse `f()` | yes |
| T10-2 | 10 | 593-598 | S | "Tasks 2 and 4-8": Task 5 is check-only, Task 6 has no executable probes (F12), injected Go-transform cases cannot be interpreted | no |
| T10-3 | 10 | 587-589 | M | interpreter semantics not pinned to the shipped key scheme, clause order, strict defer, crashing cleanup and the abort-heads-report rule | yes |
| T10-4 | 10 | 599-608 | M | generator ignores the strict defer rule; coverage lacks cleanup outcomes the revised spec defines; rejected programs not accounted for | yes |
| T10-5 | 10 | 609-616 | M | where and how the corpus of 500 or more programs runs (F11); env knobs; batch chunking; no shrinker test; no sensitivity check | yes |
| T10-6 | 10 | 617-618 | M | no verify step (F18) and no progress entry before commit | no |
| T11-1 | 11 | 626-630 | W | scenario may use the bracket idiom (rejected by strict rule); notes depend on Task 9 texts | no |
| T11-2 | 11 | 629-630 | M | baseline for the key-count identity not defined (F6) and not robust to handler constructors | yes |
| T11-3 | 11 | 631-634 | W | bounds "from Task 1's measurements": hand-written Go on another host; T007 container | yes |
| T11-4 | 11 | 634-635 | S | 1,000-label rows "through the CLI" unspecified; 20,000 lets duplicate fx-block.serial (F18) | no |
| T11-5 | 11 | 622-624 | M | non-timing acceptance assertions placed in a serial timing file | yes |
| T12-1 | 12 | 641-646 | W | Files: no test/regression-fx.mjs (F17), no test/regression.mjs, no spec/CF001/SDD snapshot | no |
| T12-2 | 12 | 648-655 | W | rows: duplicate of `effect-free-ctx`; missing rigid-tail, own-row, clause-order and abort-heads-report rows; side-condition timeout mechanism; "named test" wording | yes |
| T12-3 | 12 | 656-659 | S | ADR/language limits miss strict defer, cancellation and discard, abort delivery condition, Task 8 conventions, F3, F5 | no |
| T12-4 | 12 | 660-664 | S | BACKLOG step ignores existing FX007/CF001; FX005 lacks CF001 §10.4 constraint; FX006 "CPS confinement" contradicts row erasure | no |
| T12-5 | 12 | 665-666 | W | "exit 0 with the new regression proofs" unreachable while verify stops at T007 | yes (G1) |

Total: 27 amendments (5 global, 6 Task 9, 6 Task 10, 5 Task 11, 5 Task 12).

### Replacement texts and rulings

Each block gives the replacement plan text (to apply verbatim, rewrapped
to the plan's width) and a ruling: decision; why; cost if wrong.

**G1 (plan 104-105, and every task's "Run `rm -rf output && npm run
verify`. Expected: exit 0"; Task 9 step 4 at 581, Task 11 step 3 at 636,
Task 12 step 4 at 665).** Replace with:
> `npm run verify` exits 0, or fails only in its serial phase on the
> BACKLOG T007 timing set, named in the progress entry and failing
> identically at the task's base commit; verify then stops before the
> regression proofs, so `node scripts/regression.mjs` is run explicitly
> and must exit 0. No bound is raised and no rerun hides a failure.

Ruling: adopt. Why: this is how Tasks 6-8 were accepted, and the plan
text cannot be met on this container. Cost if wrong: a new timing
regression could hide among the T007 failures. Mitigation: the set must
be named and identical to the base commit's.

**G2 (105-106).** Replace "commit on branch fx001 in .worktrees/fx001"
with "commit on branch claude/vibrant-cerf-3km61i (ruling F15; no
worktree)". Ruling: transcription of F15.

**G3 (66-71).** After `` `defer must not fail, but it performs <L>` ``
add `` `defer must not fail, but it may perform any effect of <r>` (<r>
is `...` for the ambient row, `...e` for a named one; Task 8 review
ruling, user chose strict 2026-10-09) ``. Add the line "Labels print
capitalized everywhere, including `Unhandled Fail(DbError) in main`
(F9); spec §6's `fail(DbError)` is a typo." Ruling: transcription.

**G4 (docs, applied with the amendments rather than in Task 12).**
- D:369: "(or may, through an open row tail: Task 8 review ruling,
  pending user confirmation)" becomes "(or may, through a row tail
  resolved to a rigid variable: Task 8 review ruling, strict form chosen
  by the user 2026-10-09; relaxation is FX007)".
- CF:134 and CF:408: "Pending user confirmation …" becomes "The user
  chose this strictness for `defer` for now (2026-10-09); a lacks-X
  constraint is FX007. For `par` it remains proposed."

Ruling: apply now, only if the controller reads the ledger entry "user
chose strict over a lacks-Fail constraint for now" as a confirmation;
otherwise leave the text and ask the user. Why: the binding spec should
not call shipped behavior pending. Cost if wrong: docs claim a
confirmation the user did not give.

**G5 (Review Focus, after item 5).** Add:
> 6. No accepted program ends a deferred expression in a typed abort
>    (strict `defer` rule, including rigid row tails and Fail keys settled
>    after the `defer`); a pending abort reaches its `handle` only when
>    every cleanup on the way completes normally. Tasks 8, 10.

Ruling: adopt. Why: this is the soundness claim the strict rule was
chosen for, and Task 10 can witness it (T10-3). Cost: none.

**T9-1 (Files, 544-549).** Replace with:
> - Modify: `src/Features/Check/Subst.purs` (occurrence links, merged on
>   composition), `src/Features/Check/UnifyRow.purs` (only calls into the
>   hook module; no net growth, 249 lines), `src/Features/Check/Unify.purs`
>   (`settleRows` retries record links: deferred `Fail` keys, F13),
>   `src/Features/Check/Consume.purs` (`consumeAt` records the consuming
>   origin), `src/Features/Check/Defer.purs` and `src/Features/Check.purs`
>   (deferred-row origins and the `defer` boundary), the consuming
>   checkers that pass a `Consumed` (Operation, Call, Apply, Failure,
>   Lambda as needed, compile-guided as F19), `src/Domain/Syntax.purs`
>   (`NoteReason`), `src/Format/Diagnostic.purs` (calls only; 232 lines),
>   `src/Format/Wire.purs` (`related` as rendered `{ span, message }`)
> - Create: `src/Features/Check/Provenance.purs` (origins and links),
>   `src/Features/Check/Origin.purs` (row-event hooks, ruling F13),
>   `src/Format/Diagnostic/Row.purs` (abbreviation),
>   `src/Format/Diagnostic/Note.purs` (note texts, paths),
>   `test/fx-diagnostics.test.mjs`

Ruling: adopt. The 250-line cap and F13 force this. Cost: none.

**T9-2 (Interfaces, 552-562).** Insert after "…occurrences are never
merged by effect key.":
> Links are recorded by every row unification, not only by
> `unifyRowsTraced` callers: they live in the substitution (`links ∷ Map
> OccurrenceId OccurrenceId`, first link per occurrence wins, merged when
> substitutions compose). That covers rows nested in arrow types (a
> callback's row reaching a `with pure` parameter) and `settleRows`
> retries of deferred `Fail` keys (Unify.purs). Origins (`Map
> OccurrenceId Origin`, in checker state) are recorded where a label is
> consumed. Neither map is read by unification. A test runs every
> pre-FX001 rejection and acceptance test unchanged, and one asserts that
> all non-effect diagnostics have `related: []`.

Ruling: store links in Subst. Why: events are discarded on every path
the Task 9 tests exercise, and threading an event list through every
`unify` caller is wider and easy to miss. Cost if wrong: Subst grows by
one map. If composition drops links, the provenance-dropped mutant
catches it.

**T9-3 (Interfaces, new bullet).**
> - Deferred rows (Task 8): `defer e` is checked against its own row,
>   separate from the function row. Origins of its labels are recorded
>   inside `e`. Consuming them into the enclosing row (in `checkDefer`,
>   and for labels that arrive later in `settleDeferred`) links each
>   enclosing occurrence to its deferred occurrence with boundary
>   `DeferItem`. `defer must not fail, but it performs <L>` keeps the
>   `defer` item as primary span and gets an origin note at the operation,
>   call or `fail` inside `e` that introduced L, following links through
>   a called function's row and a `Fail` key settled after the `defer`.
>   `defer must not fail, but it may perform any effect of <r>` gets a
>   note at the application whose row carried the rigid tail (a callback
>   parameter, or a local lambda also called outside the `defer`) and a
>   boundary note at <r>'s declaration (the enclosing signature for `...`,
>   the `...e` annotation for a named row). Provenance adds no
>   unification after `settleDeferred` (an unsolved deferred tail is not
>   bound; see §3 R11).

Ruling: adopt. Why: the user's own diagnostic texts are E_EFFECT and
fall under §6 "Every effect diagnostic follows section 6". Cost: about
two more tests.

**T9-4 (Interfaces, 552-556; Step 1 "each note's … text").** Add:
> - `Consumed = Operation String | CallOf String | Application | FailOf
>   String`; `Boundary = Signature String | AmbientSignature String |
>   PureParameter | Installation String | Main | DeferItem`.
>   `NoteReason` (Domain.Syntax; replaces the unused `RequiredBy`) and
>   texts, rendered in Format.Diagnostic.Note:
>   origin `<L> is performed here` / `<L> comes from this call of <f>` /
>   `<L> comes from this function value` / `Fail(<T>) is raised here`;
>   path `through <f>`, elision `… <k> more calls`; boundary `the
>   signature of <f> does not allow <L>` / `the signature of <f> has an
>   ambient row` / `this parameter must be pure` / `<L> is handled here`
>   / `main may perform only Console` / `cleanup registered here must not
>   fail` / `<r> is declared here`; same-key `the innermost <L> is here`.
>   The wire's `related` is `[{ span, message }]`.

Ruling: the controller fixes these texts now, and the user may reword
them at the Task 9 review. Why: spec §6 fixes headlines but no note
texts, and without fixed texts the implementer invents them and the
tests pin arbitrary strings. Cost if wrong: test-text churn only.

**T9-5 (Step 1, 568-577).** Append before the final period:
> ; `Unhandled Fail(DbError) in main` (F9 spelling) with an origin note
> at the `fail`; the existing headline `Unhandled <L> in main` is kept
> and "(required by …)" is an origin note (F10);
> `defer must not fail, but it performs Fail(E)` through a called
> function and through a `Fail` key settled after the `defer`, each with
> its origin note inside the deferred expression;
> `defer must not fail, but it may perform any effect of ...` (callback
> parameter) and `... of ...e` (named row), with notes at the
> application and at the row's declaration; every pre-FX001 diagnostic
> keeps `related: []`.

Ruling: adopt. Cost: none.

**T9-6 (Step 1; Review Focus 5).** Add to the 50-label case:
> its labels carry type arguments so that the unabbreviated rendering
> exceeds `maxCharacters` (asserted first, through a test-only full
> renderer exported by Format.Diagnostic.Row), and the abbreviated
> diagnostic is within it.

Ruling: adopt. Why: otherwise the length assertion and the Task 12
"abbreviation disabled (bound exceeded)" mutant pass vacuously.
Cost: none.

**T10-1 (Files, 586-591).** Replace with:
> - Create: `test/fx-oracle-parse.mjs` (independent parser for the effect
>   forms; extends test/poly-parse.mjs by import, which stays unedited at
>   226 lines; parses zero-argument calls `f()`, FN006 (1)),
>   `test/fx-oracle.mjs` (interpreter; no compiler code imported; split
>   further to stay within 250 lines), `test/fx-programs.mjs` (generator,
>   census), `test/fx-shrink.mjs`, `test/fx-oracle.test.mjs` (hand-trace
>   validation, shrinker test, sensitivity check; parallel phase),
>   `test/fx-differential.serial.test.mjs` (generated comparisons, serial
>   phase, ruling F11), `test/fx-cleanup-programs.mjs` (Task 8's run cases
>   moved unchanged out of test/fx-cleanup.test.mjs)
> - Modify: `test/fx-cleanup.test.mjs` and any other probe file whose run
>   cases are inline (import them instead), `docs/engineering.md` (the
>   corpus knobs)

The line "Modify: `scripts/differential-corpus.mjs` (effect corpus)" is
deleted.

Ruling: drop the differential-corpus change. Why: that file feeds a
compiler-versus-compiler tool whose harvested corpus already includes
every fx test source. Spec §5's "extending FN001's tooling" means the
go-batch plus oracle pattern. Cost if wrong: generated effect programs
are not available as a compiler-refactor corpus. Adding that later is
cheap, because it imports test/fx-programs.mjs.

**T10-2 (Step 1, 593-598).** Replace the second sentence with:
> Validate it first against hand-derived traces: every executable probe
> of Tasks 2, 4, 7 and 8 (fx-block-programs `runs`, the Console probes,
> fx-run-programs `cases` with empty stderr and status 0,
> fx-cleanup-programs with stdout, stderr and status), imported, never
> copied. Task 5 tests are check-only and Task 6 has no executable probes
> (F12). Cases whose Go is transformed after emission (fx-cleanup
> `injected`: missing-handler guard, newline escaping) are outside the
> interpreter's language and are listed by name as excluded in the test.

Ruling: transcription. Cost: none.

**T10-3 (new paragraph under Files or Step 1).**
> The interpreter models the shipped semantics exactly: handler lookup by
> runtime key, user effects by effect identity regardless of type
> arguments (innermost State wins for State(Int) and State(Bool)), and
> `Fail` by the payload's declared head (Error(Int) and Error(Bool) share
> a key). The clauses of one `handle` are frames with the first clause
> innermost. A clause runs in its `with`'s outer context. Aborts target
> their frame. `defer` registers when reached and runs LIFO, once per
> exiting activation, in the registration context. A pending abort
> reaches its `handle` only if every cleanup on the way completes
> normally. If a cleanup crashes, the pending abort heads the report as
> `fail(T): V` and its `handle` never runs. With no pending cause, the
> first cleanup crash is the unprefixed first line. Later causes follow
> with `cleanup failed: `, in execution order. Payloads print by ADR 005,
> or `<not printable>` when T contains a function or handler, with `\n`
> escaped; output goes to stderr and the exit status is 1. A deferred
> expression that ends in a typed abort is an interpreter error, "typed
> abort escaped cleanup", reported as a difference: it witnesses a hole
> in the strict `defer` rule. Go runtime panics and the missing-handler
> guard cannot be produced by generated programs and are not modeled.

Ruling: adopt, including the soundness witness. Why: the Task 8 review
found five unsound shapes, and the differential run is the cheapest
standing check. Keying by full label instead of key would also agree on
well-typed programs, but only by relying on typing that the oracle should
not assume. Cost if wrong: an interpreter that is stricter than the spec
reports false differences, which the hand traces surface first.

**T10-4 (Step 2, 599-608).** Append:
> Generated `defer` items obey the strict rule (spec §2). They perform
> only non-`Fail` labels from operations or named functions with written
> rows, or they handle their `Fail` inside (`defer handle … { fail(error:
> E) => … }`). They never call a callback parameter, or a local lambda
> also called outside the `defer` in a non-`main` function (FX007). Every
> generated program must compile, and a rejection fails the run with its
> seed (a generator defect). In addition, 25 generated rejection variants
> (a `defer` failing directly, through a called function, through a
> callback parameter with an ambient row, and through one with a named
> row) must give E_EFFECT with the exact Task 8 texts and the `defer`
> span. Payload types are monomorphic, or derivable from constructors and
> literals, so the interpreter can name T as diagnostics print it.

Also extend the cleanup coverage list ("at least 25 each …") to read:
> normal exit, abort, defect, crashing cleanup on normal exit, crashing
> cleanup while an abort is pending (the abort heads the report), several
> crashing cleanups (order), cleanup handling its own failure while an
> abort is pending (the abort then reaches its `handle`), cleanup
> performing an operation under nested handlers while an abort unwinds
> (registration context), unreached `defer`

Ruling: adopt. Why: without this the generator either produces rejected
programs (silently assessing nothing) or never reaches the revised §3
outcomes. Cost: generator size, which needs two modules.

**T10-5 (Step 3, 609-616).** Replace the first sentence with:
> Run, in test/fx-differential.serial.test.mjs (F11), generated
> comparisons of Go stdout, stderr and exit status against the
> interpreter: 500 programs by default from a fixed seed, with
> `WAXWING_FX_SEED` and `WAXWING_FX_PROGRAMS` for larger runs outside
> verify (documented in docs/engineering.md), built in go-batches of at
> most 100 programs each (a batch-level Go failure names its chunk;
> go-batch's build timeout is 300 s), with the coverage above.

Append:
> test/fx-oracle.test.mjs proves the shrinker on a synthetic "differs"
> predicate: it removes items and keeps the program well-typed. It also
> runs a sensitivity check: 50 generated programs against an interpreter
> flag that runs clauses in the inner context must give at least one
> difference.

Ruling: adopt the knob names and chunking. Why: F11 requires seeded runs
and a knob, a single 500-package batch risks the build timeout, and
"0 differences" means nothing unless the comparison is shown able to
differ. Cost: one interpreter flag that is used only by tests.

**T10-6 (Steps, after 616).** Insert before the commit step:
> - [ ] **Step 4: Run** `rm -rf output && npm run verify` (G1) and add the
>   progress entry (census, seed, counts, run time).

Renumber the commit step to Step 5. Ruling: transcription of F18.

**T11-1 (Step 1, 626-630).** Replace with:
> Write the acceptance scenario (§5) as examples/services.wxw, with
> snapshot bootstrap/services.go compared byte for byte in a test (F18):
> services with overlapping requirements, composed with no row
> annotations beyond each service function's own written labels; real
> and stateless fake handler values built inline in `main` and selected
> there. Cleanup goes only through `defer` of operations or of named
> functions with written non-`Fail` rows. There is no effect-polymorphic
> cleanup callback, because the bracket idiom is rejected by the strict
> rule (FX007). A variant with one handler dropped gives the §6
> diagnostic, and its Task 9 origin, boundary and path notes are asserted
> by exact span and text.

Ruling: adopt. Why: under the strict rule, a scenario with a bracket
helper would not compile. "Without annotations" cannot mean unannotated
service signatures, because an ambient row forbids performing through
it (decision 6). Cost: the scenario shows no resource-bracket helper.

**T11-2 (Step 1, key count).** Replace "its key count equals the
effect-free baseline plus its effect keys (asserted)" with:
> its specialization keys (`specializationKeys`) equal those of a
> hand-written baseline plus its effect keys (ruling F6). In the
> baseline, each operation is a plain function parameter and each
> inline handler value is inline lambdas of the operations' types,
> passed where the handler was installed. The test asserts equal type
> keys, equal function keys by declaration name, and that the extra keys
> are exactly the effect keys, and it prints the breakdown.

Ruling: adopt. Why: if handler-constructor functions or multi-operation
service ADTs appear on only one side, the count identity breaks or holds
by accident. Inline handlers and inline lambdas map one to one. Cost if
wrong: the scenario has no handler-constructor functions, and probe 1
already covers those.

**T11-3 (Step 2, 631-634).** Replace with:
> Write serial timing tests of Waxwing-emitted programs, attributed
> separately (installation: repeated shallow `with`; lookup: one
> context of fixed depth 100 built once, then a measured loop of
> operations; unwinding: one `fail` across 1,000 frames, separately from
> 100,000 caught failures), each folding its results into checked
> output, and `go build` of the scenario. Bounds: measure each five times
> on the executing host (median, minimum and maximum, load averages, in
> the progress entry) and set the bound at 3× the median (the
> fx-block.serial convention). Compare the medians with Task 1's
> hand-written figures as an observation for FX005. A later failure
> under load goes to BACKLOG T003/T007 and is never hidden by a rerun or
> a raised bound.

Ruling: adopt. Why: Task 1 timed hand-written Go on another host and
load, and fixed bounds from it fail on this container (T007), so the
tests would fail from day one or tempt a relaxation. Cost if wrong:
bounds fitted to a slow container are loose on fast hosts. Recording
the host makes that visible.

**T11-4 (Step 2 tail, 634-635).** Replace "1,000-label rows and 20,000
`let` items through the CLI" with:
> through the CLI, a declaration with a 1,000-label written row compiles
> (`emit`), and a rejection involving a 1,000-label row prints within
> Task 9's `maxCharacters`; the 20,000-`let` case is the existing
> test/fx-block.serial.test.mjs (ruling F18), not duplicated.

Ruling: transcription of F18 plus an interpretation. Cost: none.

**T11-5 (Files, 622-624).** Replace with:
> - Create: `test/fx-services.test.mjs` (scenario output, snapshot,
>   dropped-handler diagnostic, key counts; parallel phase),
>   `test/fx-scale.serial.test.mjs` (timing only), `examples/services.wxw`,
>   `bootstrap/services.go`

Ruling: adopt. Why: semantic assertions in a serial file run only after
the parallel phase, and when T007 fails that phase they are reported
together with timing noise. Cost: one more file.

**T12-1 (Files, 641-646).** Replace with:
> - Create: `scripts/regression-fx.mjs` (rows, spread into
>   scripts/regression.mjs like `fnRows`), `test/regression-fx.mjs`
>   (probes, merged into test/regression.mjs's external probes like
>   `fnProbes`; ruling F17), `docs/adr/010-effects.md`
> - Modify: `scripts/regression.mjs`, `test/regression.mjs` (243 lines;
>   import only), `docs/language.md` (Effects), `docs/architecture.md`
>   (Check.Defer, provenance modules, Format.Go Context, Effect, Handle,
>   Block, Cleanup and Report), `docs/engineering.md` (regression-fx; FX
>   knobs if Task 10 did not), `BACKLOG.md`, `docs/findings.md`,
>   `docs/progress.md`, `docs/next-session.md`,
>   `docs/sdd/2026-10-09-effects-plan/` (ledger snapshot)

Ruling: transcription of F17 plus the existing SDD-snapshot practice.

**T12-2 (Step 1, 648-655).** Replace with:
> **Add regression rows** in scripts/regression-fx.mjs, each restoring
> one defect in an isolated copy; its probe in test/regression-fx.mjs
> passes on the healthy compiler and fails on the mutant with a named
> message. Rows: side condition removed (the probe compiles in a child
> process with its own 20 s timeout and reports the timeout as the
> detected defect, so the runner's 180 s spawn timeout never fires;
> F17); clauses in the inner context; abort consumed by the nearest
> `handle`; `handle` clauses installed last-innermost (Task 7 Critical);
> cleanup in the exit-time context; cleanup drops the pending cause;
> pending abort delivered despite a cleanup defect; `defer` Fail-label
> check removed; `defer` rigid-tail check removed (a callback parameter
> with an ambient row accepted in a `defer`); deferred row unified with
> the current row (a closure whose `Fail` arrives after the `defer`
> accepted); closed parameter rows opened; `ctx` mode by reachability;
> layout edges omitted; provenance dropped (origin note missing);
> abbreviation disabled (bound exceeded). `ctx` emitted for effect-free
> programs is the existing row `effect-free-ctx` (Task 7), not
> duplicated.

Ruling: adopt the four added rows (clause order, abort heads report,
rigid tail, own row). Why: each guards a shipped decision that a review
found broken once, and the Task 8 "defer check removed" mutant exists
only in a scratch copy. Cost: about 4 × 1-2 minutes of regression time.

**T12-3 (Step 2, 656-659).** Replace with:
> **Write** ADR 010 (as shipped: row erasure revising decision 1; runtime
> keys, EffectId+1 for user effects and `Fail` by declared head; first
> clause innermost; ctx mode over the emitted IR; only keys with type
> arguments count toward the 10,000 limit (F5); the strict `defer` rule
> (CF R0) and its accepted costs (FX007); report conventions: no pending
> cause gives an unprefixed first cleanup crash, Go runtime panics print
> `panic: <text>`; empty Handler(Console)/Handler(Fail(E)) structs (F3);
> Task 11's key-count and timing evidence) and the language Effects
> section, including the documented limits: `with pure` promises neither
> termination nor freedom from `crash` or other recoverable defects; Go
> fatal errors (stack exhaustion, out of memory) skip cleanup; a pending
> typed abort reaches its `handle` only if every cleanup on the way
> completes normally (a cleanup defect makes it head the report, and a
> diverging cleanup never delivers it); `defer` must not fail, including
> through a rigid row tail, so a deferred callback parameter must be
> `with pure`, and a local lambda also called outside the `defer` in a
> non-`main` function is rejected there (FX007); block exits are normal
> completion, typed abort and recoverable defect, with continuation
> discard (FX006) and cancellation (FX002, CF001) as future exit reasons;
> no mutable state (stateless fakes; FX003); `let` is monomorphic;
> eta-expansion for pure locals; no generic Result-to-failure helper.

Ruling: transcription of spec D §1-§3 as revised, CF §11 items 3-4,
and the Task 8 conventions.

**T12-4 (Step 3, 660-664).** Replace with:
> **Update BACKLOG:** FX001 "Done pending whole-branch review"; FN002
> stays Done. New rows: FX002 (concurrency: builds on CF001; first
> settle CF §10 items 1-8, including R0 for `par`, B1 and cancellation
> C1-C4, and apply CF §10 necessary changes 3, 5 and 6), FX003 (local
> state, recording fakes; first B3: sharability as a transitive property
> of handler types plus the capture check, CF §10.3), FX005 (`ctx`
> elimination and cached lookup; Task 1 lookup at depth 10,000 took
> 11.8 s per 10^6; caches are per task or immutable at publication,
> never written into a node reachable from another goroutine, CF §10.4;
> before FX002), FX006 (general resume `ctl`; continuation ownership C6
> and discard as an exit reason; multi-shot `defer` unresolved; no
> capture across a foreign frame, I001; confining CPS without row-keyed
> specialization, since rows are erased, spec §4). Update CF001 (state
> that FX002, FX003 and FX006 depend on its §10 list) and FX007 (link
> ADR 010). Add notes to D001 (user Console handlers;
> Handler(Console)/Handler(Fail(E)) are uninhabited, F3), R001
> (value-level error sums; `Failure(A + B + ...)` as possible row
> sugar), STD001 (no generic Result-to-failure helper), I001 (callback
> boundary; injected foreign-panic tests), PKG001 (export calling
> convention: `ctx *waxwingCtx` first in ctx mode), and FN006 (1) if
> Task 10's parser closed it. FX004 keeps the Task 5 row (F14).

Ruling: transcription. Why: FX007 and CF001 were created in 6f41252,
and FX006's "CPS confinement" wording predates row erasure (D:24-27).
Cost: none.

**T12-5 (Step 4, 665-666).** Replace with "Run per G1; every new
regression proof prints 'fixed compiler passes; restored defect fails'."
Ruling: follows G1.

## 2. Pairwise and self-consistency rows

### Pairwise (producer → consumer)

| # | Producer | Consumer | Shared file or interface | Risk | Ruling |
|---|---|---|---|---|---|
| P1 | T9 NoteReason, Note.purs, Wire `related` | T11 dropped-handler assertion | note texts, `{span,message}` | T11 pins texts T9 never fixed | T9-4 fixes texts; T11 asserts through `wire` |
| P2 | T9 Provenance.purs, Diagnostic/Row.purs | T12 provenance and abbreviation mutants | needles, `context.wire` in probes | mutants vacuous if the bound is never exceeded or notes are absent | T9-6 precondition; T12 picks needles from shipped code |
| P3 | T8 Defer.purs (reviewed) | T9 origin recording | `checkDefer`, `settleDeferred` | T9 changes acceptance, or adds unification after `settleDeferred` | T9 must keep fx-cleanup 32/32 unchanged and add no unification (R11) |
| P4 | T8 fx-cleanup.test.mjs | T10 hand traces | run cases | inline, not importable | T10-1 moves them unchanged; the review checks a pure move |
| P5 | T7/T8 runtime (keys, clause order, report) | T10 interpreter | semantics | interpreter keyed by full label or clause order reversed gives false agreement or false difference | T10-3 pins them |
| P6 | T10 generator | T12 runtime mutants | none (probes standalone) | duplicate effort only | none; regression probes stay fixed programs |
| P7 | T10 serial file | T11 serial file | verify serial phase, `.build/go-batches/<id>` (T002) | runtime budget; per-file ids distinct | chunk ≤ 100 (T10-5); never run two verifies at once (ledger) |
| P8 | T11 key-count and timing evidence | T12 ADR 010 | progress entries | ADR cites numbers before they exist | T12 strictly after T11 (already the order) |
| P9 | T9 `maxCharacters` | T11 1,000-label CLI rejection | constant | T11 asserts a bound T9 named differently | T11 imports the number from the compiled module or the plan constant |
| P10 | T10 FX knobs | T12 docs/engineering.md | env names | documented twice or not at all | T10 documents them; T12 checks |
| P11 | T10 fx-oracle-parse | FN006 (1) | zero-argument calls | poly-parse edited past its cap | new module; T12 updates FN006 |
| P12 | Spec D §2/§3, CF R0 | T12 language and ADR | wording of strict rule and abort delivery | language promises more than the spec | T12-3 quotes D §1-§3 |

### Per-task self-consistency

| # | Task | Inconsistency | Fix |
|---|---|---|---|
| S9a | 9 | Files grow UnifyRow (249) and Diagnostic (232) beyond the cap | T9-1 |
| S9b | 9 | "nothing grows per call during checking" versus maps: they grow per occurrence, not per call | keep the phrase; T9-2 states first-wins, one entry per occurrence |
| S9c | 9 | Interface builds on `RowEvent`s that callers discard | T9-2 |
| S10a | 10 | Files list one parallel test file, but Step 3 needs 500 Go programs (F11) | T10-1, T10-5 |
| S10b | 10 | Step 1 says probes are "already in those tasks' tests", but they are inline | T10-1, T10-2 |
| S10c | 10 | Step 4 commits without verify | T10-6 |
| S10d | 10 | Shrinker is mandated but no test runs it unless a difference exists | T10-5 |
| S11a | 11 | Step 2 bounds from Task 1 versus the plan's "never relax" rule and T007 | T11-3 |
| S11b | 11 | "without annotations" versus decision 6 (ambient rows are rigid) | T11-1 wording |
| S12a | 12 | Step 1 says "a named test fail"; the mechanism is probes with messages | T12-2 |
| S12b | 12 | Step 4 expects exit 0 with proofs, which verify never reaches under T007 | G1, T12-5 |
| S12c | 12 | Step 3 creates ids already present (FX007, CF001) or misdescribes them (FX006) | T12-4 |
| S12d | 12 | Row list duplicates `effect-free-ctx` | T12-2 |

## 3. Items a review rubric would flag

- R1 (T10): "0 differences" over 500 programs asserts nothing unless the
  comparison is shown able to differ. Fix: the T10-5 sensitivity check.
- R2 (T10): the shrinker is code with no test. Fix: T10-5.
- R3 (T10): if generated programs that fail to compile are skipped, the
  run asserts less than its count. Fix: T10-4 (a rejection fails the run).
- R4 (T10): injected cases skipped silently. Fix: list them by name
  (T10-2).
- R5 (T9): length-bound assertions and the abbreviation mutant pass
  vacuously below 2,000 characters. Fix: T9-6.
- R6 (T9): "each note's … text" with no specified texts makes the
  implementer invent the oracle. Fix: T9-4.
- R7 (T11): timing bounds known to fail on this container are a test
  that always fails, or they invite raising a bound. Fix: T11-3.
- R8 (T11): a baseline derived from the effectful program by code makes
  the key identity tautological. F6 requires a hand-written baseline.
  Fix: T11-2.
- R9 (T12): the side-condition mutant hangs, `assert.ifError(broken.error)`
  then throws, and verify crashes instead of recording a proof. Fix: the
  probe-level timeout in T12-2.
- R10 (T12): "FN002 done" is already done (BACKLOG:13). It is a no-op
  step, not a finding; T12-4 says "stays Done".
- R11 (T8 carry-over, T9 watch): `judge` accepts an unsolved deferred
  tail without binding it to empty (re-review minor). It is sound only
  while nothing unifies after `settleDeferred`. Ruling: Task 9 adds no
  unification there, and the whole-branch review decides whether to bind
  it explicitly (2 lines). Cost if ignored: a future pass could bind the
  tail silently.
- R12 (global): every task's verify step must name the T007 set and
  compare it with the base commit (G1). Otherwise "only known failures"
  is unfalsifiable.

## 4. Rulings needed (summary)

1. G1: accept verify with only the named T007 serial set failing,
   identical at the base commit, plus an explicit regression run.
2. G4: reword "pending user confirmation" in D:369 and CF:134/408 now.
   This needs the controller's reading that the user's "strict for now"
   is a confirmation; otherwise ask the user.
3. T9-2: store occurrence links in Subst so that every unification path
   records them, including nested arrow rows and deferred-key retries.
4. T9-4: the controller fixes the `Consumed`/`Boundary`/`NoteReason` ADTs
   and note texts. The user may reword them at the Task 9 review.
5. T10-1: drop the scripts/differential-corpus.mjs change; split the
   oracle files; move the Task 8 cases to a module.
6. T10-3: the interpreter mirrors the shipped key scheme and clause order,
   and treats a typed abort escaping cleanup as a difference (soundness
   witness).
7. T10-4: the generator emits only strict-rule-valid `defer`, every
   generated program must compile, and 25 rejection variants are checked.
8. T10-5: knob names `WAXWING_FX_SEED` and `WAXWING_FX_PROGRAMS`, batches
   of at most 100, a shrinker test and a sensitivity check.
9. T11-2: the hand-written baseline uses inline handlers and inline
   lambdas; assert equal type keys and function names, with the extra
   keys exactly the effect keys.
10. T11-3: bounds are measured on the executing host at 3× the median;
    Task 1's figures are only a comparison.
11. T11-5: acceptance assertions go in a parallel test file; timing alone
    goes in the serial file.
12. T12-2: add four regression rows (clause order, abort heads report,
    rigid tail, own row) and a probe-level timeout for the side
    condition; reuse `effect-free-ctx`.
