# Effects, Handlers and Typed Failures Implementation Plan (FX001)

Status: revised after the user's plan review (2026-10-09: acyclic row
modules, sort-aware substitution, Task 1 measurement gate, consistent
phase boundaries, differential coverage and reproduction, two smaller
corrections). Execution: subagent-driven (fresh implementer and reviewer
per task, then a whole-branch review), on branch fx001 in
.worktrees/fx001, chosen by the user 2026-10-09. Stop and report if
Task 1's measurements reject a runtime shape. Tasks 1-5 are complete
(Waxwing rename 40cf312). Tasks 6-8 are complete and reviewed on branch
claude/vibrant-cerf-3km61i (cloud session, 2026-10-09; no worktree);
Tasks 9-12 were amended 2026-10-09 after the CF001 design work and an
Opus re-scan (ledger: rescan-9-12, rulings R1-R12); Task 9 is next. Current evidence is in docs/progress.md and the local SDD
ledger (.superpowers/sdd/, git-ignored).

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Direct-style effects: Unit, blocks and `let`; effect rows on
every arrow with ambient open signatures; user effect declarations,
first-class service handlers, `with`, `handle`/`fail` typed failures,
`defer` cleanup, `crash`, and a host Console effect; checked with scoped-
label row unification, specialized with rows erased, and lowered to Go
by evidence passing and targeted panics, with diagnostics that explain
where an effect came from and where it was rejected.

**Architecture:** `Domain.Type.Ty` gains `TUnit`, a row on `TFun`, row
arguments on `TData` and a `THandler` type; rows are a separate sort
(`Row v`, `Label v`) unified by a new scoped-labels module that the type
unifier calls. Parse and Resolve add effect declarations, blocks, the
handler forms and row syntax; Check threads a current row and records
row provenance; Specialize erases rows and adds effect keys to one
dependency worklist; the monomorphic IR gets explicit effect nodes that
Format.Go lowers to an immutable context list, lifted helpers and
targeted panics, emitted only when used.

**Tech Stack:** PureScript 0.15.16, Spago 1.0.4, purs-tidy 0.11.1, Node
test runner, Go 1.26.4. No new dependency.

**Spec:** docs/plans/2026-10-09-effects-design.md (approved for planning
by the user 2026-10-09). "§n" below refers to its sections; "D n" to its
direction decisions.

## Global Constraints

- AGENTS.md governs: `where` not `let … in`; no anonymous lambdas;
  `maybe`/`maybe'`/`either` with named helpers; 250-line files (about 100
  target; Grammar, Unify, Keys, Lex and Parse/Expression are within 50
  lines of the limit, so new work goes in new modules); 80 columns;
  purs-tidy; Unicode punctuation; per-declaration budgets; layer rules;
  both IR allowlists unchanged (only Check*/Specialize* import
  Domain.Checked.Internal; only Specialize*/Format.Go* import
  Domain.IR.Internal).
- bootstrap/answer.go, functions.go, lists.go, shapes.go and tree.go stay
  byte-identical. A program whose emitted IR has no effect node emits
  today's Go (§4 "Uniform `ctx`"); new runtime pieces are emitted only
  when used.
- Evaluation order is FN001's (§2 "Execution boundaries"); stage rows are
  consumed exactly at stage boundaries.
- Rows are walked with loops (no recursion per label) and count toward
  the existing inferred-type depth measure through label arguments only;
  1,000-label rows must unify and print without stack failure.
- Existing diagnostic rows are unchanged. New reserved words (`effect
  handler handle with let defer Unit ctl resume`) collide with no
  existing Waxwing test source (checked 2026-10-09). `pure` is contextual.
- New wire codes: `E_EFFECT`, `E_HANDLER` (ErrorCode `EffectError`,
  `HandlerError`). Expanding declaration cycles reuse `E_SPECIALIZATION`.
- New problem texts, exactly (§5, §6):
  - `Unhandled <L> in main`; `<f> performs <L>, which its signature does
    not allow`; `This function must be pure, but it performs <L>`; `<R1>
    and <R2> cannot be made equal: both end in ...<r>`; `defer must not
    fail, but it performs <L>`; `defer must not fail, but it may perform
    any effect of <r>` (<r> is `...` for the ambient row, `...e` for a
    named one; Task 8 review ruling, strict adopted 2026-10-09) (E_EFFECT)
  - `Missing clause for <op>`; `Duplicate clause for <op>`;
    `<op> is not an operation of <E>` (E_HANDLER)
  - `Fail needs a concrete error family`; `Expected a type, found an
    effect row`; `Expected an effect row, found a type`; `Expected a
    printable value, found <t>`; payload mismatch reuses `Expected <L1>,
    found <L2>` (E_TYPE)
  - `General control (ctl/resume) is not supported yet`; `Expected ;`
    (E_SYNTAX)
  - Hint `; remove the trailing ;?` on `Expected <T>, found Unit` caused
    by a trailing `;` (as FN001's `Hinted` form)
  - Rows print as §5 "Row display": `Log + Clock + ...e`, ambient `...`,
    closed empty `pure`.
  - Labels print capitalized everywhere, including `Unhandled Fail(DbError) in
    main` (F9); spec §6's `fail(DbError)` is a typo.
- Defect report (§5): after all cleanup, one stderr report, exit status 1,
  one cause per line in execution order with `\n` escaped; first line the
  original cause, later lines prefixed `cleanup failed: `; causes
  `crash: V`, `fail(T): V`, `no handler for L`; non-printable payload
  `fail(T): <not printable>`.
- Phase boundaries (every intermediate commit builds and verifies; no
  incomplete node reaches a phase that does not support it):
  - Task 3: rows reach Specialize only as closed empty rows, which
    `Specialize/Lower` already erases.
  - Tasks 4-5: Program.Compile calls `Features.Check.Unlowered.reject ∷
    Checked.Program → Either Diagnostic Unit` after Check and before
    Specialize, returning `Internal "unlowered effect"` for any program
    with an effect declaration, operation invocation, handler value or
    type, `with`, `handle` or `fail` (not `print`, which runs end to end
    from Task 4). Tests of these tasks call Check directly.
  - Task 6: that guard is replaced by `Features.Specialize.Unlowered.reject
    ∷ IR.Program → Either Diagnostic Unit` after Specialize, rejecting the
    same nodes in the monomorphic IR; tests call `specialize` directly.
  - Task 7 deletes the guard; Task 8 adds `defer` and `crash` through
    every phase in one task.
  Each progress entry states how far its tests reach.
- Every task: each new behavioral test seen failing before its code; `npm run
  verify` exits 0, or fails only in its serial phase on the BACKLOG T007
  timing set, named in the progress entry and failing identically at the
  task's base commit; verify then stops before the regression proofs, so `node
  scripts/regression.mjs` is run explicitly and must exit 0. No bound is
  raised and no rerun hides a failure. An evidence entry in docs/progress.md;
  commit on branch claude/vibrant-cerf-3km61i (ruling F15; no worktree). Never
  push. Timing failures under load are recorded in BACKLOG (T003/T004), never
  hidden by a rerun.

## Review Focus

1. A clause that performs its own effect reaches the *outer* handler,
   also when the inner handler was passed in as a value. Tasks 7, 10.
2. `fail` inside a clause is not caught by a `handle` installed inside
   the `with` (targeted abort). Tasks 7, 10.
3. Over-application of an arity-one function returning a function prints
   its body's Console output before evaluating the second argument.
   Tasks 4, 10.
4. An unused generic function performing an effect, never instantiated,
   is not emitted and does not force `ctx`; an unused monomorphic one is
   emitted and does. Task 7.
5. A 50-label row diagnostic stays within its character bound while still
   naming the missing label and the shared tail. Task 9.
6. No accepted program ends a deferred expression in a typed abort (strict
   `defer` rule, including rigid row tails and Fail keys settled after the
   `defer`); a pending abort reaches its `handle` only when every cleanup on
   the way completes normally. Tasks 8, 10.

---

### Task 1: Measure the runtime shapes

No compiler change. Confirms §4's Go runtime before lowering code exists.

**Files:**
- Create: `scripts/effect-probe.mjs` (writes hand-written Go programs of
  the §4 shapes to .build/fx001-task1/, builds and runs them with explicit
  timeouts, prints wall times and checks outputs)
- Modify: `docs/findings.md`, `docs/progress.md`

- [ ] **Step 1: Write** probes, each a Go program with a checked output:
  (a) context list `waxwingCtx{key int; handler any; outer *waxwingCtx;
  marker *waxwingMarker}` with a perform function that walks to the key,
  type-asserts the handler struct and calls the clause with `outer`;
  (b) targeted abort: `waxwingMarker struct{ id uint64 }`, `waxwingAbort
  {target *waxwingMarker; payload any}`, a lifted `handle` helper
  returning `(result, *waxwingAbort)` that recovers only its own markers;
  (c) `waxwingCleanup(state *waxwingPending, cleanup func())` implementing
  §3's policy; (d) a lifted block helper with two `defer`s.
- [ ] **Step 2: Check semantics in Go:** a clause reaching the outer
  handler; an abort crossing an unrelated inner `handle` to its target;
  two cleanup failures produce the confirmed report lines in order;
  1,000 markers allocated in a loop are pairwise distinct.
- [ ] **Step 3: Measure, attributed separately**, each configuration
  five times (report median, minimum and maximum), each run with an
  explicit timeout (build 300 s, run 120 s): installation (10^6 shallow
  installs); lookup (a context 10,000 deep built once, then 10^6 performs
  at depth 1, 100 and 10,000); unwinding (one abort across 1,000 frames;
  100,000 caught aborts at depth 1); `go build` of programs with 1,000,
  2,000 and 4,000 lifted helpers. Every measured loop folds its results
  into a checksum the program prints and the script verifies, so the Go
  compiler cannot remove the measured work. Raw output under
  .build/fx001-task1/; summary in findings.
- [ ] **Step 4: Decide.** Adopt the shapes if every semantic check passes
  and the median `go build` of the 4,000-helper program is at most 10 s
  (the scale rule's per-program build bound). Growth ratios between sizes
  are reported as observations, not as a linearity proof: the scale rule
  claims linearity for Waxwing phases only, and Go builds have measured
  absolute bounds. Lookup, installation and unwinding costs are recorded,
  not bounded (FX005). If a semantic check fails or the bound is
  exceeded, stop and report to the user.
- [ ] **Step 5: Commit** `docs: FX001 runtime shape measurement`.

### Task 2: Unit, blocks and `let` (absorbs FN002)

Pure; runs end to end. No rows yet.

**Files:**
- Modify: `src/Format/Lex.purs` (reserved words; `Unit`),
  `src/Domain/Syntax.purs` (`UnitRef Span`; `Expr`: `UnitValue Span`,
  `Block Span (Array Item) Expr`; `data Item = Let Span (Maybe String)
  Expr | Discard Expr`), `src/Domain/Type.purs` (`TUnit`),
  `src/Domain/Resolved.purs`, `src/Domain/Checked/Internal.purs`,
  `src/Domain/IR/Internal.purs` (`TUnit`; `Block`, `UnitValue`),
  `src/Features/Resolve/Expression.purs`, `src/Features/Check/Infer.purs`,
  `src/Features/Check/Walk.purs`, `src/Features/Specialize/Body.purs`,
  `src/Format/Go/Expression.purs`, `src/Format/Go/Show.purs`,
  `src/Format/Go.purs` (`entryMain`: no print for Unit),
  `src/Domain/Problem.purs` (`Hint` gains `TrailingSemicolon`),
  `test/poly-parse.mjs` and the FN001 interpreter (blocks)
- Create: `src/Format/Parse/Block.purs`, `src/Features/Check/Block.purs`,
  `src/Format/Go/Block.purs`, `test/fx-block.test.mjs`

**Interfaces:**
- Parse (§1): `{` in the loosest expression dispatch starts a block;
  items are `let name = e`, `let _ = e` or `e`, separated by `;`. `{}`
  is `UnitValue`. A trailing `;` makes the block's value `UnitValue`
  with the block's closing span and marks the block `trailing` (for the
  hint). `{ let x = 1 }` is E_SYNTAX `Expected ;` at `}`. `()` is
  `UnitValue`.
- Resolve: `let` opens a scope over later items; shadowing as for match
  binders.
- Check: `let` is monomorphic; `Unit` comparable and printable (prints
  `()`); hint `Hinted (Mismatch …) TrailingSemicolon` when a trailing
  block's Unit fails against a non-Unit requirement.
- Go: a block is a lifted helper `waxwingFn{f}Block{k}` (pre-order, shared
  counter with Match), captures in LocalId order; `x := e`, `_ = e`,
  `return last`. Unit is Go `struct{}`.

- [x] **Step 1: Write failing tests** in test/fx-block.test.mjs: block
  value; `let` scoping and shadowing; `{}` and `()` are Unit; trailing
  `;` is Unit and the hinted E_TYPE row exactly; `{ let x = 1 }` exact
  E_SYNTAX row; `main` returning Unit prints nothing; Unit compares and
  prints `()` inside an ADT; evaluation order of items (divergence probe
  as FN001's); 128 nested blocks compile, build and run, and 129 are
  E_NESTING; 20,000 `let` items compile in linear time (bounded test).
- [x] **Step 2: Run** `node --test test/fx-block.test.mjs`. Expected:
  FAIL.
- [x] **Step 3: Implement** the files above.
- [x] **Step 4: Run** `rm -rf output && npm run verify`. Expected: exit 0;
  bootstrap snapshots byte-identical.
- [x] **Step 5: Commit** `feat: Unit, blocks and let (FX001)`; mark
  FN002 done in BACKLOG.

### Task 3: Rows in the type representation and scoped-label unification

Behavior-preserving: no syntax produces a non-empty row; unit tests
build rows directly.

**Files:**
- Modify: `src/Domain/Type.purs` (below), every module matching on
  `TFun` or `TData` (compile-guided: Unify, Scheme, Walk, Require,
  Expand, Comparable, Inhabited, Nested, Instantiation, Specialize/Lower,
  Specialize/Keys, Format.Diagnostic type names), `test/unify.test.mjs`,
  `test/unify-oracle.mjs`
- Create: `src/Domain/Ids.purs` (`TypeId` moved from Domain.Type and
  re-exported there; `EffectId`), `src/Domain/Row.purs`,
  `src/Features/Check/UnifyRow.purs`,
  `test/unify-row.test.mjs`, `test/row-oracle.mjs`

**Interfaces:**
- Acyclic modules: `Domain.Row` does not import `Domain.Type`; it is
  parameterized over the argument type and `Domain.Type` imports it.
  `Domain.Row`: `data Row t v = Row (Array (Label t)) (Maybe v)`
  (`Nothing` closed); `data Label t = Label EffectRef (Array t)`; `data
  EffectRef = UserEffect EffectId | FailEffect | ConsoleEffect`;
  `newtype EffectId = EffectId Int`; `data LabelKey = EffectKey
  EffectRef | FailKey TypeHead` with `data TypeHead = HeadInt | HeadBool
  | HeadUnit | HeadData TypeId` (TypeId and EffectId live in
  `Domain.Ids`, imported by both); `labelKey ∷ (t → Maybe TypeHead) →
  Label t → Maybe LabelKey` (`Nothing` while a Fail payload's head is a
  variable: deferred key).
- `Domain.Type`: `type TyRow v = Row (Ty v) v`; `TFun (Ty v) (TyRow v)
  (Ty v)`; `TData TypeId (Array (Ty v)) (Array (TyRow v))` (type
  arguments, then row arguments, each in declaration order); `THandler
  (Label (Ty v)) (TyRow v)`; `TUnit`.
- Sort-aware substitution (interface decision): `Ty`'s Monad/Bind
  instance is removed (Functor stays for renaming). `substitute ∷
  Substitution v w → Ty v → Ty w` with `type Substitution v w = { types
  ∷ v → Ty w, rows ∷ v → TyRow w }`; a row tail `v` is replaced by
  splicing `rows v` (its labels appended in order, its tail becoming the
  new tail). Every current `>>=` on `Ty` moves to `substitute`. A
  variable or meta has one sort by construction; the checker's `Subst`
  holds `types ∷ Map Int (Ty Flex)` and `rows ∷ Map Int (TyRow Flex)`
  and `Scheme.instantiate` creates metas per sort.
- `UnifyRow.unifyRows ∷ (Subst → Ty Flex → Ty Flex → Either Failure
  Subst) → Subst → Row Flex → Row Flex → Either Failure Subst`: Leijen
  §7 with the side condition `tail(r1) ∉ dom(θ)`, first occurrence by
  key, label arguments unified with the passed type unifier; a loop over
  labels. `Unify`'s `TFun` case calls it with `unify`.
- `Failure` gains `RowMissing (Label (Ty Flex)) (TyRow Flex)`,
  `RowExtra (Label (Ty Flex))`, `RowSharedTail (TyRow Flex) (TyRow
  Flex)`.
- Occurrences: every label occurrence has an `OccurrenceId = Written
  Span Int | Extended Int` (a written annotation's span and position, or
  the meta whose binding added it). `unifyRows` reports, besides the
  substitution, `Array RowEvent` with `Matched OccurrenceId
  OccurrenceId` (a label matched an existing entry; the rewrite knows
  through which meta binding or written row it reached that entry) and
  `Extended Int OccurrenceId` (a meta tail was extended), so Task 9 can
  attribute provenance on both paths without changing unification.
- Equality, ordering and `exceedsLimit` walk rows with loops.

- [x] **Step 1: Write failing tests** (unit and generated, oracle in
  test/row-oracle.mjs written independently): distinct keys commute,
  same keys do not; repeated keys with differing arguments match the
  first occurrence and mismatch is an error, never a skip; `Clock +
  ...r` against `Log + ...r` fails with `RowSharedTail` (timeout-guarded);
  rigid tail missing a label is `RowMissing`; closed row with an extra
  label is `RowExtra`; properties over generated rows with repeated
  keys, shared tails and rigid variables: a success makes both rows
  equal under scoped-label equality after substitution, acceptance is
  symmetric, substitutions are acyclic; 1,000-label rows unify; the
  oracle agrees on every generated pair. Substitution: identity
  (`{ types: TVar, rows: open-empty-row }`) is the identity; composition
  equals sequential application; two occurrences of one row variable are
  replaced by the same spliced row (shared relationship preserved);
  splicing keeps order and multiplicity; renaming via Functor and
  `substitute` agree on row-free types.
- [x] **Step 2: Run** `node --test test/unify-row.test.mjs`. Expected:
  FAIL.
- [x] **Step 3: Implement.** Every existing `TFun` gets the closed empty
  row and every `TData` empty row arguments, and `Specialize/Lower` erases
  rows, so all existing behavior is unchanged.
- [x] **Step 4: Run** `rm -rf output && npm run verify`. Expected: exit 0,
  snapshots byte-identical.
- [x] **Step 5: Commit** `feat: effect rows and scoped-label unification
  (FX001)`.

### Task 4: Signatures, effect declarations, operations and Console

Console-only programs run end to end.

**Files:**
- Modify: `src/Format/Lex.purs`, `src/Domain/Syntax.purs` (`EffectDecl
  {name, parameters, operations, span}`; `RowRef`: `RowRef Span (Array
  LabelRef) (Maybe RowTail)`, `RowTail = Spread String | Pure`; `FunRef`
  and the signature result gain `Maybe RowRef`), `src/Format/Parse.purs`
  (`on "effect"`), `src/Format/Parse/Type.purs`, `src/Domain/Resolved.purs`
  (`Operation EffectId Int` global), `src/Features/Resolve.purs`,
  `src/Features/Resolve/Variables.purs` (signature variables carry a
  sort; the ambient row is VarId n, after the written ones),
  `src/Domain/Problem.purs`, `src/Format/Diagnostic.purs`,
  `src/Domain/Syntax.purs` (`Diagnostic` gains `related ∷ Array Note`,
  `type Note = { span ∷ Span, reason ∷ NoteReason }`),
  `src/Format/Wire.purs` (`related` list), `src/Features/Check.purs`
  (entry row), `src/Domain/IR/Internal.purs` (`Print` node; `print` and
  later `crash` resolve as built-in globals), `src/Format/Go.purs`
  (`print`)
- Create: `src/Format/Parse/Effect.purs`, `src/Features/Resolve/Row.purs`,
  `src/Features/Check/Consume.purs`, `src/Features/Check/Entry.purs`,
  `src/Features/Check/Unlowered.purs` (the pre-specialization guard),
  `test/fx-signature.test.mjs`, `test/fx-console.test.mjs`

**Interfaces:**
- Signatures (§1, §2): unannotated written arrows and the unannotated or
  spread-free final stage use the ambient row; `with L + ...e` uses rigid
  `e`; `with pure` is closed empty; field and operation arrows without
  `with` are `pure`. A name used as both type and row variable is E_TYPE
  sort error at its second use. A declaration's non-final stages carry
  fresh quantified rows.
- `Consume.consume ∷ Subst → TyRow Flex → TyRow Flex → Either Failure
  Subst`
  (stage row, current row): tail present → unify; closed → unify
  `s + fresh` with current. Instantiating a declaration reference opens a
  closed final-stage row of its own stages only.
- Operations are named functions of declared arity; bare zero-parameter
  operation is the existing E_ARITY `Expected now()`.
- Console: `print(value: a): Unit with Console`, `a` printable (E_TYPE
  `Expected a printable value, found <t>`); lowered to a write of the
  ADR 005 rendering and a newline (no `ctx`).
- Entry (§2): main's row, unsolved tail closed, has only `Console`
  entries; each other entry is E_EFFECT `Unhandled <L> in main` at the
  call through which it arrives (notes added in Task 9).
- Every existing diagnostic has `related: []` and unchanged text.

- [x] **Step 1: Write failing tests:** parsing and printing of rows;
  ambient sharing (`map` with an effectful callback inherits it); a body
  performing an unlisted label at a rigid row is E_EFFECT `<f> performs
  <L>, which its signature does not allow`; `with pure` callback given a
  Console-performing lambda is `This function must be pure, but it
  performs Console`; a `with pure` local passed to a `with Log` slot is
  rejected (eta-expansion accepted); named rows stay shared; partial
  application performs argument effects only; Console traces for
  interleaved application, over-application of an arity-one function
  returning a function, and `|>` (exact stdout); `Unhandled <L> in main`
  for an operation of a declared effect; sort errors both ways.
- [x] **Step 2: Run** the two new test files. Expected: FAIL.
- [x] **Step 3: Implement.**
- [x] **Step 4: Run** `rm -rf output && npm run verify`. Expected: exit 0.
- [x] **Step 5: Commit** `feat: effect signatures, operations and
  Console (FX001)`.

### Task 5: Handlers, `with`, `handle` and `fail` in the checker

Check only: tests call Check directly; Program.Compile stops these
programs at `Features.Check.Unlowered` (Global Constraints).

**Files:**
- Modify: `src/Format/Lex.purs`, `src/Domain/Syntax.purs` (`HandlerExpr
  Span LabelRef (Array Clause)`, `With Span Expr Expr`, `Handle Span Expr
  (Array FailClause)`; `THandlerRef`; type declarations' `...r`
  parameters), `src/Domain/Resolved.purs`,
  `src/Domain/Checked/Internal.purs` (nodes `Handler`, `With`, `Handle`,
  `Fail`), `src/Features/Check/Comparable.purs` (handlers not
  comparable), `src/Features/Check/Walk.purs`
- Create: `src/Format/Parse/Handler.purs`,
  `src/Format/Parse/HandlerType.purs`,
  `src/Features/Resolve/Handler.purs`, `src/Features/Check/Handler.purs`,
  `src/Features/Check/Failure.purs` (deferred Fail keys),
  `src/Features/Resolve/HandlerExpression.purs`,
  `src/Features/Resolve/HandlerType.purs`,
  `src/Features/Resolve/TypeValidation.purs`,
  `test/fx-handler-check.test.mjs`

**Interfaces:**
- §2 "Expression rules", exactly: `handler` performs nothing, one clause
  per operation (E_HANDLER texts); `with h` checks body against `L + ρ`
  and unifies the handler row with ρ (opened if closed); `handle` checks
  body against `Fail(E1) + … + ρ`, clauses against ρ; `fail(e)` consumes
  `Fail(typeOf(e))`, result fresh.
- `Failure.settleKeys`: after a body's other constraints, each Fail label
  with a meta head is re-keyed; a remaining meta or rigid head is E_TYPE
  `Fail needs a concrete error family` at the `fail`.
- `ctl` or `resume` anywhere is E_SYNTAX `General control (ctl/resume) is
  not supported yet`.
- Handler types: not comparable, not printable, rejected in `print`,
  `crash` (Task 8) and main's result (`EntryFunction`).
- Row-parameterized types: `type Job(a, ...effects) = …`; arguments
  checked by sort and arity.

- [x] **Step 1: Write failing tests:** each E_HANDLER row; partial
  handling forwards the unmentioned family; `Fail(Error(Int))` and
  `Fail(Error(Bool))` share a key and mismatch as a payload error;
  `Fail(DbError)` and `Fail(ValidationError)` are separate; deferred key
  resolves; rigid payload rejected; nested `State(Int)`/`State(Bool)`
  type-check with the first-occurrence rule; comparing, printing or
  returning a handler (also nested in an ADT) rejected; `ctl` rejected;
  `Job(Int, Log + Clock)` accepted, `Job(Log, Int)` sort errors.
- [x] **Step 2: Run** `node --test test/fx-handler-check.test.mjs`.
  Focused Task 5 assertions pass (81/81); earlier RED evidence and all
  compatibility failures/fixes are preserved in the Task 5 report.
- [x] **Step 3: Implement.**
- [x] **Step 4: Run** `rm -rf output && npm run verify`. Passed with 722
  parallel tests, 22 serial tests, and 33 actual-source regression proofs;
  `.build/fx-handler-task5-verify5.log`.
- [x] **Step 5: Commit** `feat: handler and failure checking (FX001)`.
  Local-only; no remote publication or merge.

### Task 6: Specialization: row erasure, effect keys and layout cycles

**Files:**
- Modify: `src/Features/Specialize.purs` (worklist), 
  `src/Features/Specialize/Keys.purs` (effect keys; split if over 250
  lines), `src/Features/Specialize/Body.purs`,
  `src/Features/Specialize/Lower.purs` (rows erased; `THandler` lowers
  to its effect key), `src/Domain/IR/Internal.purs` (`THandler EffectKey`;
  effect table; nodes `HandlerValue`, `Install`, `Perform`, `Handle`,
  `Abort`), `src/Features/Check/Nested.purs` (one graph over types and
  effects), `src/Features/Check/Instantiation.purs` (signature variables
  inside labels)
- Create: `src/Features/Specialize/Effects.purs`,
  `src/Features/Specialize/Unlowered.purs`, `test/fx-specialize.test.mjs`

**Interfaces:**
- §4 "Specialization keys and dependencies": function keys reach body
  keys including effect keys; type keys reach field keys; effect keys
  reach operation-signature keys; `Handler(L …)` reaches L's effect key.
  Every key counts toward the 10,000 limit.
- Nested rule over types and effects (§4 "Layout dependencies"); a
  violation is the existing `NestedDatatype` problem, E_SPECIALIZATION,
  at the nested reference.
- `Features.Specialize.Unlowered.reject ∷ IR.Program → Either Diagnostic
  Unit` replaces `Features.Check.Unlowered` (deleted): `Internal
  "unlowered effect"` for any program with an effect node other than
  `print`.

- [ ] **Step 1: Write failing tests:** recursive handler installation
  yields one function key; growing-label recursion (`a := List(a)`
  through `State(a)`) rejected; `Grow`, the mutual pair and the
  data/effect cycle rejected with exact rows, their bare-parameter
  versions accepted; `State(Int)` and `State(Bool)` give two effect
  keys; rows in data arguments give no extra type key; a pure function
  used at three different rows is one key.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `rm -rf output && npm run verify`. Expected: exit 0.
- [ ] **Step 5: Commit** `feat: effect specialization with erased rows
  (FX001)`.

### Task 7: Go lowering of handlers, operations and failures

**Files:**
- Modify: `src/Format/Go.purs`, `src/Format/Go/Expression.purs`,
  `src/Format/Go/Lambda.purs`, `src/Format/Go/Stage.purs`,
  `src/Format/Go/Apply.purs`, `src/Format/Go/Data.purs`,
  `src/Format/Go/Usage.purs` (`usesContext`), delete
  `src/Features/Specialize/Unlowered.purs` and its Program.Compile call
- Create: `src/Format/Go/Context.purs` (runtime text and mode),
  `src/Format/Go/Effect.purs` (handler structs, perform functions),
  `src/Format/Go/Handle.purs`, `test/fx-run.test.mjs`

**Interfaces:**
- Mode (§4): `usesContext ∷ IR.Program → Boolean` over the emitted IR
  (operation, handler value or type, `with`, `handle`, `fail`). When
  true every function, stage, lambda and function value takes `ctx
  *waxwingCtx` first; otherwise nothing changes.
- Names: handler struct `waxwingEff{N}` (N = effect key index), perform
  `waxwingEff{N}Op{k}`, helpers `waxwingFn{f}With{k}`,
  `waxwingFn{f}Handle{k}`, clauses lifted as lambdas (pre-order, shared
  counter with Match and Block).
- Runtime shapes are Task 1's adopted ones; markers non-zero-sized.

- [ ] **Step 1: Write failing tests** (executable, exact stdout): clause
  context (intercept-and-forward Log, Review Focus 1); targeted abort
  past an inner `handle` (Review Focus 2); nested `State(Int)` and
  `State(Bool)`; generic `constant(v: s): Handler(State(s))`; stateless
  fakes vs real handlers passed as values; `Job(Int, Log + Clock)` in a
  list under two handler sets; a lambda created under one handler run
  under another; a pure `main` beside an unused monomorphic effectful
  function builds and runs (Review Focus 4); every bootstrap snapshot
  byte-identical and Console-only programs without `ctx`.
- [ ] **Step 2: Run** `node --test test/fx-run.test.mjs`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `rm -rf output && npm run verify`. Expected: exit 0.
- [ ] **Step 5: Commit** `feat: Go lowering of effect handlers (FX001)`.

### Task 8: `defer`, `crash`, cleanup policy and the defect report

**Files:**
- Modify: Block parser/checker/lowering (`Defer` item), `src/Domain/IR/
  Internal.purs` (`Defer`, `Crash`), `src/Format/Go/Context.purs`
  (`waxwingCleanup`, `waxwingDefect`, main's recovery wrapper); `defer` and
  `crash` go through every phase in this task
- Create: `src/Features/Check/Defer.purs`, `test/fx-cleanup.test.mjs`

**Interfaces:**
- §3 exactly: registration context; whole expression evaluated at exit;
  LIFO; four block exits; cleanup-failure policy (revised by the user
  2026-10-09: `defer` must not fail; only defects fail cleanup);
  `crash(value: a): b` printable argument, no effect, uncatchable.
- §2 `defer` rule: `e : Unit` against the current row; any `Fail` label it
  performs and does not handle inside `e` (deferred keys included) is
  E_EFFECT `defer must not fail, but it performs <L>` at the `defer`.
- Report lines and exit status 1 per Global Constraints; `<not
  printable>` decided statically from the payload type.

- [ ] **Step 1: Write failing tests** (exact stdout, stderr, exit status):
  LIFO order; unreached `defer` never runs; two crashing defers on normal
  exit; abort with crashing cleanup (`fail(DbError): …` then `cleanup
  failed: crash: …`); multiple recoverable defects in order; cleanup
  handling its own failure while an outer abort is pending completes
  normally and the abort then reaches its `handle`; cleanup performing
  an operation under nested handlers while an abort unwinds uses the
  registration context; `crash` not caught by `handle`; non-printable
  payload line; a block without `defer` emits no Go `defer`; rejections
  (exact code, text, span): `defer` performing an unhandled `Fail`
  directly, through a called function, and through a deferred Fail key;
  accepted: `defer` handling its own `Fail`, and `defer` performing a
  non-Fail effect from the current row.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `rm -rf output && npm run verify`. Expected: exit 0.
- [ ] **Step 5: Commit** `feat: defer, crash and cleanup (FX001)`.

### Task 9: Diagnostic quality

**Files:**
- Modify: `src/Features/Check/Subst.purs` (occurrence links, merged on
  composition), `src/Features/Check/UnifyRow.purs` (only calls into the
  hook module; no net growth, 249 lines), `src/Features/Check/Unify.purs`
  (`settleRows` retries record links: deferred `Fail` keys, F13),
  `src/Features/Check/Consume.purs` (`consumeAt` records the consuming
  origin), `src/Features/Check/Defer.purs` and `src/Features/Check.purs`
  (deferred-row origins and the `defer` boundary), the consuming
  checkers that pass a `Consumed` (Operation, Call, Apply, Failure,
  Lambda as needed, compile-guided as F19), `src/Domain/Syntax.purs`
  (`NoteReason`), `src/Format/Diagnostic.purs` (calls only; 232 lines),
  `src/Format/Wire.purs` (`related` as rendered `{ span, message }`)
- Create: `src/Features/Check/Provenance.purs` (origins and links),
  `src/Features/Check/Origin.purs` (row-event hooks, ruling F13),
  `src/Format/Diagnostic/Row.purs` (abbreviation),
  `src/Format/Diagnostic/Note.purs` (note texts, paths),
  `test/fx-diagnostics.test.mjs`

**Interfaces:**
- §6 exactly. `Provenance`: `Map OccurrenceId Origin` (Task 3's
  occurrence identity) with `Origin = { span, consumed ∷ Consumed, via ∷
  Maybe Boundary }`. Both `RowEvent`s attribute origins: `Extended m o`
  records the consuming origin for the new occurrence `Extended m`;
  `Matched o existing` (a consumed label matched an existing entry,
  written or extended, without extending any meta) records the origin for
  `existing` if it has none yet, and links `o` to `existing` so later
  attribution follows the matched occurrence. First origin per
    occurrence wins; occurrences are never merged by effect key. Links are
  recorded by every row unification, not only by `unifyRowsTraced` callers:
  they live in the substitution (`links ∷ Map OccurrenceId OccurrenceId`,
  first link per occurrence wins, merged when substitutions compose). That
  covers rows nested in arrow types (a callback's row reaching a `with pure`
  parameter) and `settleRows` retries of deferred `Fail` keys (Unify.purs).
  Origins (`Map OccurrenceId Origin`, in checker state) are recorded where a
  label is consumed. Neither map is read by unification. A test runs every
  pre-FX001 rejection and acceptance test unchanged, and one asserts that all
  non-effect diagnostics have `related: []`. Reports reconstruct paths from
  these links; nothing grows per call during checking.
- Abbreviation constants (named, in Format.Diagnostic.Row):
  `visibleLabels = 4`, `pathHops = 2` at each end, `maxNotes = 4`,
  `maxCharacters = 2000`; type arguments elided off the path to the
    differing subterm.
- Deferred rows (Task 8): `defer e` is checked against its own row, separate
  from the function row. Origins of its labels are recorded inside `e`.
  Consuming them into the enclosing row (in `checkDefer`, and for labels that
  arrive later in `settleDeferred`) links each enclosing occurrence to its
  deferred occurrence with boundary `DeferItem`. `defer must not fail, but it
  performs <L>` keeps the `defer` item as primary span and gets an origin note
  at the operation, call or `fail` inside `e` that introduced L, following
  links through a called function's row and a `Fail` key settled after the
  `defer`. `defer must not fail, but it may perform any effect of <r>` gets a
  note at the application whose row carried the rigid tail (a callback
  parameter, or a local lambda also called outside the `defer`) and a boundary
  note at <r>'s declaration (the enclosing signature for `...`, the `...e`
  annotation for a named row). Provenance adds no unification after
  `settleDeferred` (an unsolved deferred tail is not bound; see §3 R11).
- `Consumed = Operation String | CallOf String | Application | FailOf String`;
  `Boundary = Signature String | AmbientSignature String | PureParameter |
  Installation String | Main | DeferItem`. `NoteReason` (Domain.Syntax;
  replaces the unused `RequiredBy`) and texts, rendered in
  Format.Diagnostic.Note: origin `<L> is performed here` / `<L> comes from
  this call of <f>` / `<L> comes from this function value` / `Fail(<T>) is
  raised here`; path `through <f>`, elision `… <k> more calls`; boundary `the
  signature of <f> does not allow <L>` / `the signature of <f> has an ambient
  row` / `this parameter must be pure` / `<L> is handled here` / `main may
  perform only Console` / `cleanup registered here must not fail` / `<r> is
  declared here`; same-key `the innermost <L> is here`. The wire's `related`
  is `[{ span, message }]`.

- [ ] **Step 1: Write failing tests** asserting code, primary span, each
  note's span and text, and output length: a 30-deep call chain missing
  Database at `main`; an operation in a lambda passed through three
  higher-order functions into a `with pure` parameter; a 50-label row missing
  one label (Review Focus 5; its labels carry type arguments so that the
  unabbreviated rendering exceeds `maxCharacters` (asserted first, through a
  test-only full renderer exported by Format.Diagnostic.Row), and the
  abbreviated diagnostic is within it); a same-key payload mismatch under
  nested `State` handlers with a note at the innermost occurrence; the side
  condition; repeated `Fail` families attribute each origin to its own
  occurrence; a label consumed into a signature-written row (match without
  extension) and one consumed into an already-extended meta row both get
  origin notes; `Unhandled Fail(DbError) in main` (F9 spelling) with an origin
  note at the `fail`; the existing headline `Unhandled <L> in main` is kept
  and "(required by …)" is an origin note (F10); `defer must not fail, but it
  performs Fail(E)` through a called function and through a `Fail` key settled
  after the `defer`, each with its origin note inside the deferred expression;
  `defer must not fail, but it may perform any effect of ...` (callback
  parameter) and `... of ...e` (named row), with notes at the application and
  at the row's declaration; every pre-FX001 diagnostic keeps `related: []`.
- [ ] **Step 2: Run** `node --test test/fx-diagnostics.test.mjs`.
  Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `rm -rf output && npm run verify`. `npm run verify`
  exits 0, or fails only in its serial phase on the BACKLOG T007 timing set,
  named in the progress entry and failing identically at the task's base
  commit; verify then stops before the regression proofs, so `node
  scripts/regression.mjs` is run explicitly and must exit 0. No bound is
  raised and no rerun hides a failure.
- [ ] **Step 5: Commit** `feat: effect diagnostic provenance (FX001)`.

### Task 10: Reference interpreter and differential execution

**Files:**
- Create: `test/fx-oracle-parse.mjs` (independent parser for the effect
  forms; extends test/poly-parse.mjs by import, which stays unedited at
  226 lines; parses zero-argument calls `f()`, FN006 (1)),
  `test/fx-oracle.mjs` (interpreter; no compiler code imported; split
  further to stay within 250 lines), `test/fx-programs.mjs` (generator,
  census), `test/fx-shrink.mjs`, `test/fx-oracle.test.mjs` (hand-trace
  validation, shrinker test, sensitivity check; parallel phase),
  `test/fx-differential.serial.test.mjs` (generated comparisons, serial
  phase, ruling F11), `test/fx-cleanup-programs.mjs` (Task 8's run cases
  moved unchanged out of test/fx-cleanup.test.mjs)
- Modify: `test/fx-cleanup.test.mjs` and any other probe file whose run
  cases are inline (import them instead), `docs/engineering.md` (the
  corpus knobs)

- [ ] **Step 1: Write** the interpreter. Validate it first against
  hand-derived traces: every executable probe of Tasks 2, 4, 7 and 8
  (fx-block-programs `runs`, the Console probes, fx-run-programs `cases` with
  empty stderr and status 0, fx-cleanup-programs with stdout, stderr and
  status), imported, never copied. Task 5 tests are check-only and Task 6 has
  no executable probes (F12). Cases whose Go is transformed after emission
  (fx-cleanup `injected`: missing-handler guard, newline escaping) are outside
  the interpreter's language and are listed by name as excluded in the test. A
  disagreement there is an interpreter or probe defect, investigated before
  Step 3.

  The interpreter models the shipped semantics exactly: handler lookup by
  runtime key, user effects by effect identity regardless of type arguments
  (innermost State wins for State(Int) and State(Bool)), and `Fail` by the
  payload's declared head (Error(Int) and Error(Bool) share a key). The
  clauses of one `handle` are frames with the first clause innermost. A clause
  runs in its `with`'s outer context. Aborts target their frame. `defer`
  registers when reached and runs LIFO, once per exiting activation, in the
  registration context. A pending abort reaches its `handle` only if every
  cleanup on the way completes normally. If a cleanup crashes, the pending
  abort heads the report as `fail(T): V` and its `handle` never runs. With no
  pending cause, the first cleanup crash is the unprefixed first line. Later
  causes follow with `cleanup failed: `, in execution order. Payloads print by
  ADR 005, or `<not printable>` when T contains a function or handler, with
  `\n` escaped; output goes to stderr and the exit status is 1. A deferred
  expression that ends in a typed abort is an interpreter error, "typed abort
  escaped cleanup", reported as a difference: it witnesses a hole in the
  strict `defer` rule. Go runtime panics and the missing-handler guard cannot
  be produced by generated programs and are not modeled.
- [ ] **Step 2: Write** a generator of well-typed programs over two user
  effects with Console traces, and a per-program feature census. Required
  coverage per run, failing the run when unmet: at least 50 programs each with
  nested same-key handlers (including intercept-and-forward), targeted aborts
  crossing an unrelated `handle`, interleaved stage ordering with
  over-application, and escaped callbacks invoked under a different handler;
  at least 25 each for every cleanup outcome (normal exit, abort, defect,
  crashing cleanup on normal exit, crashing cleanup while an abort is pending
  (the abort heads the report), several crashing cleanups (order), cleanup
  handling its own failure while an abort is pending (the abort then reaches
  its `handle`), cleanup performing an operation under nested handlers while
  an abort unwinds (registration context), unreached `defer`). The census is
  printed with the run. Generated `defer` items obey the strict rule (spec
  §2). They perform only non-`Fail` labels from operations or named functions
  with written rows, or they handle their `Fail` inside (`defer handle … {
  fail(error: E) => … }`). They never call a callback parameter, or a local
  lambda also called outside the `defer` in a non-`main` function (FX007).
  Every generated program must compile, and a rejection fails the run with its
  seed (a generator defect). In addition, 25 generated rejection variants (a
  `defer` failing directly, through a called function, through a callback
  parameter with an ambient row, and through one with a named row) must give
  E_EFFECT with the exact Task 8 texts and the `defer` span. Payload types are
  monomorphic, or derivable from constructors and literals, so the interpreter
  can name T as diagnostics print it.
- [ ] **Step 3: Run** in test/fx-differential.serial.test.mjs (F11), generated
  comparisons of Go stdout, stderr and exit status against the interpreter:
  500 programs by default from a fixed seed, with `WAXWING_FX_SEED` and
  `WAXWING_FX_PROGRAMS` for larger runs outside verify (documented in
  docs/engineering.md), built in go-batches of at most 100 programs each (a
  batch-level Go failure names its chunk; go-batch's build timeout is 300 s),
  with the coverage above. Expected: 0 differences. Every program's seed is
  recorded; a differing program's seed and source are written to
  .build/fx001-differential/, and a shrinker (drop block items, handlers,
  clauses and defers; replace subexpressions by literals of their type; keep
  only while still well-typed and still differing) writes the minimized source
  beside it. test/fx-oracle.test.mjs proves the shrinker on a synthetic
  "differs" predicate: it removes items and keeps the program well-typed. It
  also runs a sensitivity check: 50 generated programs against an interpreter
  flag that runs clauses in the inner context must give at least one
  difference.
- [ ] **Step 4: Run** `rm -rf output && npm run verify` (G1) and add the
  progress entry (census, seed, counts, run time).
- [ ] **Step 5: Commit** `test: FX001 reference interpreter and differential
  corpus`.

### Task 11: Scale and the acceptance scenario

**Files:**
- Create: `test/fx-services.test.mjs` (scenario output, snapshot,
  dropped-handler diagnostic, key counts; parallel phase),
  `test/fx-scale.serial.test.mjs` (timing only), `examples/services.wxw`,
  `bootstrap/services.go`

- [ ] **Step 1: Write** the acceptance scenario (§5) as examples/services.wxw,
  with snapshot bootstrap/services.go compared byte for byte in a test (F18):
  services with overlapping requirements, composed with no row annotations
  beyond each service function's own written labels; real and stateless fake
  handler values built inline in `main` and selected there. Cleanup goes only
  through `defer` of operations or of named functions with written non-`Fail`
  rows. There is no effect-polymorphic cleanup callback, because the bracket
  idiom is rejected by the strict rule (FX007). A variant with one handler
  dropped gives the §6 diagnostic, and its Task 9 origin, boundary and path
  notes are asserted by exact span and text; its specialization keys
  (`specializationKeys`) equal those of a hand-written baseline plus its
  effect keys (ruling F6). In the baseline, each operation is a plain function
  parameter and each inline handler value is inline lambdas of the operations'
  types, passed where the handler was installed. The test asserts equal type
  keys, equal function keys by declaration name, and that the extra keys are
  exactly the effect keys, and it prints the breakdown.
- [ ] **Step 2: Write** serial timing tests of Waxwing-emitted programs,
  attributed separately (installation: repeated shallow `with`; lookup: one
  context of fixed depth 100 built once, then a measured loop of operations;
  unwinding: one `fail` across 1,000 frames, separately from 100,000 caught
  failures), each folding its results into checked output, and `go build` of
  the scenario. Bounds: measure each five times on the executing host (median,
  minimum and maximum, load averages, in the progress entry) and set the bound
  at 3× the median (the fx-block.serial convention). Compare the medians with
  Task 1's hand-written figures as an observation for FX005. A later failure
  under load goes to BACKLOG T003/T007 and is never hidden by a rerun or a
  raised bound; through the CLI, a declaration with a 1,000-label written row
  compiles (`emit`), and a rejection involving a 1,000-label row prints within
  Task 9's `maxCharacters`; the 20,000-`let` case is the existing
  test/fx-block.serial.test.mjs (ruling F18), not duplicated.
- [ ] **Step 3: Run** `rm -rf output && npm run verify`. `npm run verify`
  exits 0, or fails only in its serial phase on the BACKLOG T007 timing set,
  named in the progress entry and failing identically at the task's base
  commit; verify then stops before the regression proofs, so `node
  scripts/regression.mjs` is run explicitly and must exit 0. No bound is
  raised and no rerun hides a failure.
- [ ] **Step 4: Commit** `test: FX001 acceptance scenario and scale`.

### Task 12: Regression proofs and documentation

**Files:**
- Create: `scripts/regression-fx.mjs` (rows, spread into
  scripts/regression.mjs like `fnRows`), `test/regression-fx.mjs`
  (probes, merged into test/regression.mjs's external probes like
  `fnProbes`; ruling F17), `docs/adr/010-effects.md`
- Modify: `scripts/regression.mjs`, `test/regression.mjs` (243 lines;
  import only), `docs/language.md` (Effects), `docs/architecture.md`
  (Check.Defer, provenance modules, Format.Go Context, Effect, Handle,
  Block, Cleanup and Report), `docs/engineering.md` (regression-fx; FX
  knobs if Task 10 did not), `BACKLOG.md`, `docs/findings.md`,
  `docs/progress.md`, `docs/next-session.md`,
  `docs/sdd/2026-10-09-effects-plan/` (ledger snapshot)

- [ ] **Step 1: Add regression rows** in scripts/regression-fx.mjs, each
  restoring one defect in an isolated copy; its probe in
  test/regression-fx.mjs passes on the healthy compiler and fails on the
  mutant with a named message. Rows: side condition removed (the probe
  compiles in a child process with its own 20 s timeout and reports the
  timeout as the detected defect, so the runner's 180 s spawn timeout never
  fires; F17); clauses in the inner context; abort consumed by the nearest
  `handle`; `handle` clauses installed last-innermost (Task 7 Critical);
  cleanup in the exit-time context; cleanup drops the pending cause; pending
  abort delivered despite a cleanup defect; `defer` Fail-label check removed;
  `defer` rigid-tail check removed (a callback parameter with an ambient row
  accepted in a `defer`); deferred row unified with the current row (a closure
  whose `Fail` arrives after the `defer` accepted); closed parameter rows
  opened; `ctx` mode by reachability; layout edges omitted; provenance dropped
  (origin note missing); abbreviation disabled (bound exceeded). `ctx` emitted
  for effect-free programs is the existing row `effect-free-ctx` (Task 7), not
  duplicated.
- [ ] **Step 2: Write** ADR 010 (as shipped: row erasure revising decision 1;
  runtime keys, EffectId+1 for user effects and `Fail` by declared head; first
  clause innermost; ctx mode over the emitted IR; only keys with type
  arguments count toward the 10,000 limit (F5); the strict `defer` rule (CF
  R0) and its accepted costs (FX007); report conventions: no pending cause
  gives an unprefixed first cleanup crash, Go runtime panics print `panic:
  <text>`; empty Handler(Console)/Handler(Fail(E)) structs (F3); Task 11's
  key-count and timing evidence) and the language Effects section, including
  the documented limits: `with pure` promises neither termination nor freedom
  from `crash` or other recoverable defects; Go fatal errors (stack
  exhaustion, out of memory) skip cleanup; a pending typed abort reaches its
  `handle` only if every cleanup on the way completes normally (a cleanup
  defect makes it head the report, and a diverging cleanup never delivers it);
  `defer` must not fail, including through a rigid row tail, so a deferred
  callback parameter must be `with pure`, and a local lambda also called
  outside the `defer` in a non-`main` function is rejected there (FX007);
  block exits are normal completion, typed abort and recoverable defect, with
  continuation discard (FX006) and cancellation (FX002, CF001) as future exit
  reasons; no mutable state (stateless fakes; FX003); `let` is monomorphic;
  eta-expansion for pure locals; no generic Result-to-failure helper.
- [ ] **Step 3: Update BACKLOG:** FX001 "Done pending whole-branch review";
  FN002 stays Done. New rows: FX002 (concurrency: builds on CF001; first
  settle CF §10 items 1-8, including R0 for `par`, B1 and cancellation C1-C4,
  and apply CF §10 necessary changes 3, 5 and 6), FX003 (local state,
  recording fakes; first B3: sharability as a transitive property of handler
  types plus the capture check, CF §10.3), FX005 (`ctx` elimination and cached
  lookup; Task 1 lookup at depth 10,000 took 11.8 s per 10^6; caches are per
  task or immutable at publication, never written into a node reachable from
  another goroutine, CF §10.4; before FX002), FX006 (general resume `ctl`;
  continuation ownership C6 and discard as an exit reason; multi-shot `defer`
  unresolved; no capture across a foreign frame, I001; confining CPS without
  row-keyed specialization, since rows are erased, spec §4). Update CF001
  (state that FX002, FX003 and FX006 depend on its §10 list) and FX007 (link
  ADR 010). Add notes to D001 (user Console handlers;
  Handler(Console)/Handler(Fail(E)) are uninhabited, F3), R001 (value-level
  error sums; `Failure(A + B + ...)` as possible row sugar), STD001 (no
  generic Result-to-failure helper), I001 (callback boundary; injected
  foreign-panic tests), PKG001 (export calling convention: `ctx *waxwingCtx`
  first in ctx mode), and FN006 (1) if Task 10's parser closed it. FX004 keeps
  the Task 5 row (F14).
- [ ] **Step 4: Run** per G1; every new regression proof prints 'fixed
  compiler passes; restored defect fails'.
- [ ] **Step 5: Commit** `docs: FX001 ADR 010, language and regression
  proofs`.
