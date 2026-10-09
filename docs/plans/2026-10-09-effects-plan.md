# Effects, Handlers and Typed Failures Implementation Plan (FX001)

Status: draft for the user's review (2026-10-09). No task is authorized
and nothing is implemented. Execution method not yet chosen.

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
  existing Bumpus test source (checked 2026-10-09). `pure` is contextual.
- New wire codes: `E_EFFECT`, `E_HANDLER` (ErrorCode `EffectError`,
  `HandlerError`). Expanding declaration cycles reuse `E_SPECIALIZATION`.
- New problem texts, exactly (§5, §6):
  - `Unhandled <L> in main`; `<f> performs <L>, which its signature does
    not allow`; `This function must be pure, but it performs <L>`;
    `<R1> and <R2> cannot be made equal: both end in ...<r>` (E_EFFECT)
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
- Defect report (§5): after all cleanup, one stderr report, exit status 1,
  one cause per line in execution order with `\n` escaped; first line the
  original cause, later lines prefixed `cleanup failed: `; causes
  `crash: V`, `fail(T): V`, `no handler for L`; non-printable payload
  `fail(T): <not printable>`.
- Phase boundaries for tests, as in FN001: until Task 7, Program.Compile
  calls `Features.Specialize.Unlowered.reject` (reinstated), returning
  `Internal "unlowered effect"` for any program whose monomorphic IR
  contains an effect node other than `print`; Task 7 narrows it and Task 8
  deletes it. Each progress entry states how far its tests reach.
- Every task: each new behavioral test seen failing before its code;
  `npm run verify` exits 0; an evidence entry in docs/progress.md; commit
  on branch fx001 in .worktrees/fx001. Never push. Timing failures under
  load are recorded in BACKLOG (T003/T004), never hidden by a rerun.

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

---

### Task 1: Measure the runtime shapes

No compiler change. Confirms §4's Go runtime before lowering code exists.

**Files:**
- Create: `scripts/effect-probe.mjs` (writes hand-written Go programs of
  the §4 shapes to .build/fx001-task1/, builds and runs them with explicit
  timeouts, prints wall times and checks outputs)
- Modify: `docs/findings.md`, `docs/progress.md`

- [ ] **Step 1: Write** probes, each a Go program with a checked output:
  (a) context list `bumpusCtx{key int; handler any; outer *bumpusCtx;
  marker *bumpusMarker}` with a perform function that walks to the key,
  type-asserts the handler struct and calls the clause with `outer`;
  (b) targeted abort: `bumpusMarker struct{ id uint64 }`, `bumpusAbort
  {target *bumpusMarker; payload any}`, a lifted `handle` helper
  returning `(result, *bumpusAbort)` that recovers only its own markers;
  (c) `bumpusCleanup(state *bumpusPending, cleanup func())` implementing
  §3's policy; (d) a lifted block helper with two `defer`s.
- [ ] **Step 2: Check semantics in Go:** a clause reaching the outer
  handler; an abort crossing an unrelated inner `handle` to its target;
  two cleanup failures produce the confirmed report lines in order;
  1,000 markers allocated in a loop are pairwise distinct.
- [ ] **Step 3: Measure, attributed separately:** installation (10^6
  shallow installs); lookup (a context 10,000 deep built once, then 10^6
  performs at depth 1, 100 and 10,000); unwinding (one abort across 1,000
  frames, and 100,000 caught aborts at depth 1); `go build` of 2,000
  lifted helpers. Record under .build/fx001-task1/ and in findings.
- [ ] **Step 4: Decide.** Adopt the shapes if every semantic check passes
  and build time is linear in helpers (2,000 within 5× of 2 × the 1,000
  time). Lookup cost is recorded, not bounded (FX005). Otherwise stop and
  report to the user.
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
- Go: a block is a lifted helper `bumpusFn{f}Block{k}` (pre-order, shared
  counter with Match), captures in LocalId order; `x := e`, `_ = e`,
  `return last`. Unit is Go `struct{}`.

- [ ] **Step 1: Write failing tests** in test/fx-block.test.mjs: block
  value; `let` scoping and shadowing; `{}` and `()` are Unit; trailing
  `;` is Unit and the hinted E_TYPE row exactly; `{ let x = 1 }` exact
  E_SYNTAX row; `main` returning Unit prints nothing; Unit compares and
  prints `()` inside an ADT; evaluation order of items (divergence probe
  as FN001's); 128-deep nested blocks hit E_NESTING exactly at the
  limit; 20,000 `let` items compile in linear time (bounded test).
- [ ] **Step 2: Run** `node --test test/fx-block.test.mjs`. Expected:
  FAIL.
- [ ] **Step 3: Implement** the files above.
- [ ] **Step 4: Run** `rm -rf output && npm run verify`. Expected: exit 0;
  bootstrap snapshots byte-identical.
- [ ] **Step 5: Commit** `feat: Unit, blocks and let (FX001)`; mark
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
- Create: `src/Domain/Row.purs`, `src/Features/Check/UnifyRow.purs`,
  `test/unify-row.test.mjs`, `test/row-oracle.mjs`

**Interfaces:**
- `Domain.Row`: `data Row v = Row (Array (Label v)) (Maybe v)` (`Nothing`
  closed); `data Label v = Label EffectRef (Array (Ty v))`; `data
  EffectRef = UserEffect EffectId | FailEffect | ConsoleEffect`;
  `newtype EffectId = EffectId Int`; `data LabelKey = EffectKey
  EffectRef | FailKey TypeHead` with `data TypeHead = HeadInt | HeadBool
  | HeadUnit | HeadData TypeId`; `labelKey ∷ Label v → Maybe LabelKey`
  (`Nothing` while a Fail payload's head is a variable: deferred key).
- `Domain.Type`: `TFun (Ty v) (Row v) (Ty v)`; `TData TypeId (Array (Ty
  v)) (Array (Row v))` (type arguments, then row arguments, each in
  declaration order); `THandler (Label v) (Row v)`; `TUnit`. A meta is
  used at one sort only; `Subst` gains `rows ∷ Map Int (Row Flex)`.
- `UnifyRow.unifyRows ∷ (Subst → Ty Flex → Ty Flex → Either Failure
  Subst) → Subst → Row Flex → Row Flex → Either Failure Subst`: Leijen
  §7 with the side condition `tail(r1) ∉ dom(θ)`, first occurrence by
  key, label arguments unified with the passed type unifier; a loop over
  labels. `Unify`'s `TFun` case calls it with `unify`.
- `Failure` gains `RowMissing (Label Flex) (Row Flex)`, `RowExtra (Label
  Flex)`, `RowSharedTail (Row Flex) (Row Flex)`; extensions of a meta
  tail are recorded in `Subst` order so Task 9 attaches provenance to
  each extending meta (one meta per scoped occurrence).
- Equality, ordering and `exceedsLimit` walk rows with loops.

- [ ] **Step 1: Write failing tests** (unit and generated, oracle in
  test/row-oracle.mjs written independently): distinct keys commute,
  same keys do not; repeated keys with differing arguments match the
  first occurrence and mismatch is an error, never a skip; `Clock +
  ...r` against `Log + ...r` fails with `RowSharedTail` (timeout-guarded);
  rigid tail missing a label is `RowMissing`; closed row with an extra
  label is `RowExtra`; properties over generated rows with repeated
  keys, shared tails and rigid variables: a success makes both rows
  equal under scoped-label equality after substitution, acceptance is
  symmetric, substitutions are acyclic; 1,000-label rows unify; the
  oracle agrees on every generated pair.
- [ ] **Step 2: Run** `node --test test/unify-row.test.mjs`. Expected:
  FAIL.
- [ ] **Step 3: Implement.** Every existing `TFun` gets the closed empty
  row and every `TData` empty row arguments, so all existing behavior is
  unchanged.
- [ ] **Step 4: Run** `rm -rf output && npm run verify`. Expected: exit 0,
  snapshots byte-identical.
- [ ] **Step 5: Commit** `feat: effect rows and scoped-label unification
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
  `test/fx-signature.test.mjs`, `test/fx-console.test.mjs`

**Interfaces:**
- Signatures (§1, §2): unannotated written arrows and the unannotated or
  spread-free final stage use the ambient row; `with L + ...e` uses rigid
  `e`; `with pure` is closed empty; field and operation arrows without
  `with` are `pure`. A name used as both type and row variable is E_TYPE
  sort error at its second use. A declaration's non-final stages carry
  fresh quantified rows.
- `Consume.consume ∷ Subst → Row Flex → Row Flex → Either Failure Subst`
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

- [ ] **Step 1: Write failing tests:** parsing and printing of rows;
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
- [ ] **Step 2: Run** the two new test files. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `rm -rf output && npm run verify`. Expected: exit 0.
- [ ] **Step 5: Commit** `feat: effect signatures, operations and
  Console (FX001)`.

### Task 5: Handlers, `with`, `handle` and `fail` in the checker

Checked through Specialize; programs with these nodes stop at the
`unlowered effect` guard.

**Files:**
- Modify: `src/Format/Lex.purs`, `src/Domain/Syntax.purs` (`HandlerExpr
  Span LabelRef (Array Clause)`, `With Span Expr Expr`, `Handle Span Expr
  (Array FailClause)`; `THandlerRef`; type declarations' `...r`
  parameters), `src/Domain/Resolved.purs`,
  `src/Domain/Checked/Internal.purs` (nodes `Handler`, `With`, `Handle`,
  `Fail`), `src/Features/Check/Comparable.purs` (handlers not
  comparable), `src/Features/Check/Walk.purs`
- Create: `src/Format/Parse/Handler.purs`,
  `src/Features/Resolve/Handler.purs`, `src/Features/Check/Handler.purs`,
  `src/Features/Check/Failure.purs` (deferred Fail keys),
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

- [ ] **Step 1: Write failing tests:** each E_HANDLER row; partial
  handling forwards the unmentioned family; `Fail(Error(Int))` and
  `Fail(Error(Bool))` share a key and mismatch as a payload error;
  `Fail(DbError)` and `Fail(ValidationError)` are separate; deferred key
  resolves; rigid payload rejected; nested `State(Int)`/`State(Bool)`
  type-check with the first-occurrence rule; comparing, printing or
  returning a handler (also nested in an ADT) rejected; `ctl` rejected;
  `Job(Int, Log + Clock)` accepted, `Job(Log, Int)` sort errors.
- [ ] **Step 2: Run** `node --test test/fx-handler-check.test.mjs`.
  Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `rm -rf output && npm run verify`. Expected: exit 0.
- [ ] **Step 5: Commit** `feat: handler and failure checking (FX001)`.

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
- `Unlowered.reject ∷ IR.Program → Either Diagnostic Unit`: `Internal
  "unlowered effect"` for any program with an effect node other than
  print.

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
  `src/Format/Go/Usage.purs` (`usesContext`), `Unlowered.purs` (narrowed
  to `defer`/`crash`)
- Create: `src/Format/Go/Context.purs` (runtime text and mode),
  `src/Format/Go/Effect.purs` (handler structs, perform functions),
  `src/Format/Go/Handle.purs`, `test/fx-run.test.mjs`

**Interfaces:**
- Mode (§4): `usesContext ∷ IR.Program → Boolean` over the emitted IR
  (operation, handler value or type, `with`, `handle`, `fail`). When
  true every function, stage, lambda and function value takes `ctx
  *bumpusCtx` first; otherwise nothing changes.
- Names: handler struct `bumpusEff{N}` (N = effect key index), perform
  `bumpusEff{N}Op{k}`, helpers `bumpusFn{f}With{k}`,
  `bumpusFn{f}Handle{k}`, clauses lifted as lambdas (pre-order, shared
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
  (`bumpusCleanup`, `bumpusDefect`, main's recovery wrapper), delete
  `src/Features/Specialize/Unlowered.purs`
- Create: `src/Features/Check/Defer.purs`, `test/fx-cleanup.test.mjs`

**Interfaces:**
- §3 exactly: registration context; whole expression evaluated at exit;
  LIFO; four block exits; cleanup-failure policy; `crash(value: a): b`
  printable argument, no effect, uncatchable.
- Report lines and exit status 1 per Global Constraints; `<not
  printable>` decided statically from the payload type.

- [ ] **Step 1: Write failing tests** (exact stdout, stderr, exit status):
  LIFO order; unreached `defer` never runs; two failing defers on normal
  exit; abort with failing cleanup (`fail(DbError): …` then `cleanup
  failed: fail(ReleaseError): …`); `crash` in cleanup; multiple
  recoverable defects in order; cleanup handling its own failure while
  an outer abort is pending completes normally; a discarded normal
  result after a cleanup failure; cleanup performing an operation under
  nested handlers while an abort unwinds uses the registration context;
  `crash` not caught by `handle`; non-printable payload line; a block
  without `defer` emits no Go `defer`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `rm -rf output && npm run verify`. Expected: exit 0.
- [ ] **Step 5: Commit** `feat: defer, crash and cleanup (FX001)`.

### Task 9: Diagnostic quality

**Files:**
- Modify: `src/Features/Check/Consume.purs`, `UnifyRow.purs` (origin
  hooks), `src/Format/Diagnostic.purs`
- Create: `src/Features/Check/Provenance.purs`,
  `src/Format/Diagnostic/Row.purs` (abbreviation),
  `test/fx-diagnostics.test.mjs`

**Interfaces:**
- §6 exactly. `Provenance`: `Map Int Origin` keyed by the meta whose
  binding introduced a label occurrence (Task 3's extension record), plus
  written labels keyed by annotation span; `Origin = { span, consumed ∷
  Consumed, via ∷ Maybe Boundary }`. Reports reconstruct paths from
  these links; nothing grows per call during checking.
- Abbreviation constants (named, in Format.Diagnostic.Row):
  `visibleLabels = 4`, `pathHops = 2` at each end, `maxNotes = 4`,
  `maxCharacters = 2000`; type arguments elided off the path to the
  differing subterm.

- [ ] **Step 1: Write failing tests** asserting code, primary span,
  each note's span and text, and output length: a 30-deep call chain
  missing Database at `main`; an operation in a lambda passed through
  three higher-order functions into a `with pure` parameter; a 50-label
  row missing one label (Review Focus 5); a same-key payload mismatch
  under nested `State` handlers with a note at the innermost occurrence;
  the side condition; repeated `Fail` families attribute each origin to
  its own occurrence.
- [ ] **Step 2: Run** `node --test test/fx-diagnostics.test.mjs`.
  Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `rm -rf output && npm run verify`. Expected: exit 0.
- [ ] **Step 5: Commit** `feat: effect diagnostic provenance (FX001)`.

### Task 10: Reference interpreter and differential execution

**Files:**
- Create: `test/fx-oracle.mjs` (independent parser extension and
  interpreter: evidence context, clause context, targeted aborts, block
  exits, cleanup policy, report lines; no compiler code imported),
  `test/fx-programs.mjs` (generator), `test/fx-oracle.test.mjs`
- Modify: `scripts/differential-corpus.mjs` (effect corpus)

- [ ] **Step 1: Write** the interpreter and a generator of well-typed
  programs over two user effects, nested handlers, `handle`, `fail`,
  `defer`, `crash` and Console traces, with seeds recorded.
- [ ] **Step 2: Run** generated comparisons of Go stdout, stderr and exit
  status against the interpreter (at least 500 programs); every
  executable probe of Tasks 4-8 also runs through the interpreter.
  Expected: 0 differences.
- [ ] **Step 3: Commit** `test: FX001 reference interpreter and
  differential corpus`.

### Task 11: Scale and the acceptance scenario

**Files:**
- Create: `test/fx-scale.serial.test.mjs`, `examples/services.bumpus`,
  `bootstrap/services.go`

- [ ] **Step 1: Write** the acceptance scenario (§5): services with
  overlapping requirements composed without annotations; real and
  stateless fake handlers injected at `main`; dropping one handler gives
  the §6 diagnostic with origin, boundary and path notes; its key count
  equals the effect-free baseline plus its effect keys (asserted).
- [ ] **Step 2: Write** serial timing tests using Task 1's attribution
  (installation, lookup at fixed depth, unwinding, 100,000 caught
  failures) and `go build` of the scenario, bounds fixed from Task 1's
  measurements with the scale rule's headroom; 1,000-label rows and
  20,000 `let` items through the CLI.
- [ ] **Step 3: Run** `rm -rf output && npm run verify`. Expected: exit 0.
- [ ] **Step 4: Commit** `test: FX001 acceptance scenario and scale`.

### Task 12: Regression proofs and documentation

**Files:**
- Create: `scripts/regression-fx.mjs`, `docs/adr/009-effects.md`
- Modify: `scripts/regression.mjs`, `docs/language.md` (Effects),
  `docs/architecture.md`, `docs/engineering.md` if a rule changed,
  `BACKLOG.md`, `docs/findings.md`, `docs/progress.md`,
  `docs/next-session.md`

- [ ] **Step 1: Add regression rows**, each restoring one defect in an
  isolated copy and seeing a named test fail: side condition removed;
  clauses in the inner context; abort consumed by the nearest `handle`;
  cleanup in the exit-time context; cleanup drops the pending cause;
  closed parameter rows opened; `ctx` emitted for effect-free programs;
  `ctx` mode by reachability; layout edges omitted; provenance dropped;
  abbreviation disabled.
- [ ] **Step 2: Write** ADR 009 and the language section, including the
  documented limits: `with pure` promises neither termination nor
  freedom from defects; Go fatal errors skip cleanup; eta-expansion for
  pure locals; no generic Result-to-failure helper.
- [ ] **Step 3: Update BACKLOG:** FX001 done pending review; FN002 done;
  new FX002 (concurrency), FX003 (local state), FX004 (general resume,
  CPS confinement), FX005 (`ctx` elimination, cached lookup); D001 user
  Console handlers; R001 value-level error sums; STD001 limitation;
  I001 callback boundary; PKG001 export calling convention.
- [ ] **Step 4: Run** `rm -rf output && npm run verify`. Expected: exit 0
  with the new regression proofs.
- [ ] **Step 5: Commit** `docs: FX001 ADR 009, language and regression
  proofs`.
