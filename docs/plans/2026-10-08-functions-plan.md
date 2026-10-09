# First-Class Functions Implementation Plan (FN001)

Status: all tasks complete on branch fn001. Task 9 complete 2026-10-09
(regression proofs and documentation; ADR 008; docs/progress.md).
Task 6 complete 2026-10-08 (Go lowering; docs/progress.md).
Task 5 complete 2026-10-08 (instantiation rule and
specialization; docs/progress.md). Task 4 complete 2026-10-08 (checking;
docs/progress.md).
Task 3 complete 2026-10-08 (syntax and resolution;
docs/progress.md). Task 2 complete 2026-10-08 (arrow type).
Task 1 complete 2026-10-08 (three measurement rounds; design §13
records the adopted convention and the scale rule, both approved by the
user, adoption conditional on round 3, which passed). Nine-task
structure approved by the user 2026-10-08 with three changes, applied
here: no quadratic fallback in Task 1; equality,
ordering and type interning in the scale work (Tasks 2, 5, 6, 8); the
core timing probes in Task 6's first step. Design Amendment A1's
architecture is approved; its linked representation awaits Task 1. Task
1 (measurement only) is authorized; Tasks 2-9 follow Task 1's result.
Nothing is implemented.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Function types, lambdas, closures, staged partial and
over-application, named functions and constructors as values, and `|>`,
checked by the P001 unifier and lowered to monomorphic Go with nested
function values whose stage boundaries follow declared arity.

**Architecture:** `Domain.Type.Ty` gains a binary arrow shared by the
resolved program, the checker and the checked IR; the monomorphic IR gets
its own `TFun`. Parse and Resolve add lambdas, postfix application, pipes
and bare global references. Check types them and records instantiations
on every named reference; the instantiation rule counts value references
as edges. Specialize copies the new nodes. Format.Go emits one named Go
type per ground function type, lifts every lambda and every staged
wrapper into top-level stage functions over linked environments
(Amendment A1), and keeps direct saturated calls as today.

**Tech Stack:** PureScript 0.15.16, Spago 1.0.4, purs-tidy 0.11.1, Node
test runner, Go 1.26.4. No new dependency.

**Spec:** docs/plans/2026-10-08-functions-design.md (approved 2026-10-08;
§13 proposed). Section numbers below (§n) refer to it.

## Global Constraints

- AGENTS.md governs: `where` not `let … in`; no anonymous lambdas;
  `maybe`, `maybe'`, `either` with named helpers; 250-line files (about
  100 target); 80 columns; purs-tidy; Unicode punctuation;
  per-declaration budgets; layer rules; both IR allowlists unchanged.
- bootstrap/answer.go, shapes.go, tree.go and lists.go stay
  byte-identical. Direct saturated calls emit today's Go in every program.
- Linear cost. test/large-source.test.mjs already checks 20,000
  parameters and 4,000 `Nil` arguments in linear time. A named callee's
  parameters stay an array when called directly: the checker builds the
  curried arrow of a scheme only for a value reference or a partial
  application, and every pass over an arrow walks its result spine with a
  loop (§3). No existing large-source bound is raised.
- Go build bounds (scale rule, user 2026-10-08, design §13): linearity is
  claimed for Bumpus phases only. Each generated program's total `go
  build` time must be at most 10 s at 5,000 parameters (tests in `npm run
  verify`) and at most 100 s at 20,000 parameters (the milestone probe,
  run after Task 6's lowering is complete and before the final branch
  review, its result recorded in progress). User decisions 2026-10-09:
  (A) verify times these builds in a separate serial phase after the
  parallel `node --test` run (`test/*.serial.test.mjs`), bound and
  workload unchanged; (B) the milestone programs' bodies read a bounded
  handful of parameters, because a 2n-term `+` chain in one Go
  expression does not build at 20,000 even for direct calls (pre-existing
  lowering, BACKLOG G003), so the milestone measures FN001's machinery
  at full width.
- Existing assertions are unchanged except the rows of §9, which change in
  the task that changes the behavior, each listed in that task's progress
  entry with its old and new code, span and text. Known rows:
  test/diagnostics.test.mjs `fn f(): P = Pair;`; test/adt-types.test.mjs
  `Cons`, `Cons(1)` and `helper` rows; test/adt-match.test.mjs
  `Cons(f, _) => f(1)`. Rows that keep their outcome: `x()` on a local and
  `N()` on a nullary constructor stay E_NOT_CALLABLE (application needs
  at least one argument); `f()` on a one-parameter function stays E_ARITY
  `Wrong number of arguments`; over-application whose result is not a
  function keeps E_ARITY `Wrong number of arguments` (design §4 and §9,
  amended 2026-10-08 at the user's decision, so no existing text
  changes).
- New problem texts, exactly:
  - `FunctionNeedsCall f` (E_ARITY) → `Expected <f>()`
  - `NotAFunction t` (E_TYPE) → `Expected a function, found <t>`
  - `EntryProblem EntryFunction` (E_ENTRY) →
    `Expected fn main() with a printable result type`
  - `Hinted problem (MissingArguments f n)`: the code of `problem`, its
    text, then `; missing 1 argument to <f>?` or
    `; missing <n> arguments to <f>?`
  - Syntax: `Expected ->`, `Expected a type` (existing), `Expected a
    parameter` (lambda parameter list)
  - Type names: `FunctionName parameter result`, rendered with
    right-associative ` -> ` and a function parameter parenthesized:
    `(Int -> Int) -> List(Int) -> List(Int)`.
- Phase boundaries for tests, as in P001. Until Task 6 the CLI cannot emit
  a program that uses a function type, lambda, function value, partial
  application or pipe. Through Task 4, Check returns `Internal "unchecked
  function"` for nodes it does not yet type and Specialize's `lowerType`
  returns `Internal "unlowered function"` for an arrow. In Task 5
  Specialize copies everything, and Program.Compile calls a temporary
  guard, `Features.Specialize.Unlowered.reject`, that returns the same
  Internal for any program whose monomorphic IR holds an arrow type or a
  new node (Task 5 review clarification: an arrow that is only a phantom
  type argument, `Proxy(Int -> Int)`, is neither, so that program reaches
  Go; a generic function never instantiated is not emitted); Task 6
  deletes the guard. Task 3 tests through Parse → Resolve, Task 4 through Check, Task
  5 through Specialize (calling `specialize` directly); execution starts
  in Task 6. Each progress entry states how far its tests reach.
- No existing row is reworded to an interim outcome: every resolution
  change that moves a row's outcome into Check (bare references, calls of
  locals) lands in Task 4 together with the checking that gives the row
  its final outcome.
- A regression row whose needle a task rewrites is updated in the same
  task so it still has exactly one target.
- Every task: each new behavioral test seen failing before its code;
  `npm run verify` exits 0; an evidence entry in docs/progress.md; commit
  on branch fn001 in .worktrees/fn001. Never push.

## Review Focus

1. Timing survives value use: `use(add)` prints 0 and `use(stuck)`
   reaches `stuck` (§4 example). Tasks 6-7.
2. Partial application is strict and shared: `g = k3(probe(1))` built
   once, applied twice, enters `probe` once. Task 7.
3. Pipe order: `probe1(1) |> g(probe2(2))` enters `probe1` first. Task 7.
4. A lambda inside a match arm reading a binder, returned from the
   function and applied later, sees the binder's value. Task 6.
5. 20,000-parameter direct calls stay linear; a 5,000-parameter function
   used as a value builds within a measured bound. Task 8.

---

### Task 1: Measure the linked-environment lowering

No compiler change. Confirms Amendment A1's chosen shape before any
lowering code exists.

**Files:**
- Create: `scripts/stage-probe.mjs` (generates hand-written Go of the
  §13 shapes at a given `n`, builds and runs it, prints wall times)
- Modify: `docs/findings.md`, `docs/progress.md`,
  `docs/plans/2026-10-08-functions-design.md` (§13 result)

- [ ] **Step 1: Write** the generator for the linked environment at
  `n` Int parameters (each stage allocates `{ value, previous }`; the
  last stage reads the chain into `F`'s arguments once), plus the copied
  struct and nested closures as reference points only. `F` consumes every
  argument (for example a position-weighted sum), so no argument is dead.
  The program applies the staged value through all `n` stages `R` times,
  `R` chosen so the run phase lasts well over process start-up (at least
  about a second at the largest `n`), varying the arguments per round,
  and prints a checksum the script verifies against its own computation.
  Run time is measured inside the program around the `R` rounds, apart
  from build and start-up.
- [ ] **Step 2: Run** at n = 50, 300, 1,000, 5,000 and 20,000 (nested
  closures only up to 200). Every `go build` and run has an explicit
  timeout (builds 300 s, runs 120 s); a timeout is recorded as such.
  Record build time, per-application run time and binary size per shape
  and `n`, raw output under .build/fn001-task1/.
- [ ] **Step 3: Decide.** The linked environment is adopted if its build
  time grows at most linearly (20,000 within 5× of 4 × the 5,000 time) and
  its per-application run time is linear in `n` (20,000 within 5× of 4 ×
  the 5,000 time). If it fails either, stop: report the measurements to
  the user and reconsider the representation. The copied struct is not a
  fallback (it is O(n²) per application). Record the result in design
  §13 and findings.
- [ ] **Step 4: Commit** `docs: FN001 staged lowering measurement`.

### Task 2: The arrow type through every type pass

Behavior-preserving: no syntax produces an arrow yet; unit tests build
arrows directly.

**Files:**
- Modify: `src/Domain/Type.purs` (`TFun (Ty v) (Ty v)`; Bind, `ground`),
  `src/Domain/Problem.purs` (`FunctionName`), `src/Format/Diagnostic.purs`
  (rendering), `src/Features/Check/Unify.purs`,
  `src/Features/Check/Require.purs`, `src/Features/Check/Expand.purs`,
  `src/Features/Check/Comparable.purs`, `src/Features/Check/Inhabited.purs`,
  `src/Features/Check/Nested.purs`, `src/Features/Check/Instantiation.purs`,
  `src/Features/Specialize/Lower.purs` (arrow: `Internal "unlowered
  function"` until Task 5), `test/unify.test.mjs`, `test/unify-oracle.mjs`
- Create: `src/Domain/Spine.purs` if a shared spine view is needed
  (`spine ∷ Ty v → { parameters ∷ Array (Ty v), result ∷ Ty v }`,
  a loop)

**Interfaces:**
- Unify: `TFun a b` against `TFun c d` unifies `a, c` at `level + 1`
  and `b, d` at the same level (§1 measure), walking the result spine in a
  loop; a meta against an arrow binds as against any type; the occurs
  check and `exceedsLimit` enter parameters at `level + 1` and results at
  the same level.
- Equality and ordering: `Ty`'s derived `Eq` and `Ord` recurse once per
  arrow, so a 20,000-long spine can overflow the stack wherever types are
  compared (`bindMeta`'s self test, Map keys, test helpers). Replace them
  with hand-written instances that walk result spines in a loop and
  recurse only into parameters and type arguments (bounded by the depth
  measure), keeping today's order on existing types.
- Comparable: a type containing `TFun`, directly or through applied
  fields, is `NotComparable`, after the rigid and hole checks (§3).
- Inhabited: every arrow is inhabited.
- Expand and the type-reference graph treat `TFun` as a constructor of
  two arguments; `Key` renders arrows distinctly from data types.

- [x] **Step 1: Write failing unifier tests:** arrow against arrow;
  mismatch inside a parameter and inside a result names the first
  differing subterms; meta against an arrow; occurs through an arrow
  (`α` against `α -> Int`); rigid against an arrow fails; a 5,000-long
  spine unifies without stack failure; a 1,001-deep parameter nesting is
  `TooDeep` while a 5,000-long spine is not; `==` and `compare` on two
  equal 20,000-long spines and on two differing only in the last
  parameter terminate without stack failure, and `compare` agrees with
  the derived order on generated arrow-free types. Extend the generated
  property tests and the independent oracle with arrows.
- [x] **Step 2: Run** `node --test test/unify.test.mjs`. Expected: FAIL.
- [x] **Step 3: Implement.** Comparable, Inhabited and Expand cases get
  unit tests through `checkedPoly` only once Task 4 can produce arrows;
  here their new cases are total and covered by the checker identity
  (all existing tests pass unchanged).
- [x] **Step 4: Run** `rm -rf output && npm run verify`. Expected: exit 0,
  snapshots byte-identical, twelve regression proofs.
- [x] **Step 5: Commit** `feat: arrow type in unification and type passes
  (FN001)`.

### Task 3: Syntax and resolution

**Files:**
- Modify: `src/Format/Lex.purs` (`->`, `|>` in `twoCharacterTokens`,
  longest first), `src/Domain/Syntax.purs` (`TypeRef`: `FunRef Span
  TypeRef TypeRef`; `Expr`: `Lambda Span (Array LambdaParam) Expr`,
  `Apply Span Expr (Array Expr)`, `Pipe Span Expr Expr`; `LambdaParam =
  { name ∷ Maybe String, ty ∷ Maybe TypeRef, span ∷ Span }`),
  `src/Format/Parse/Expression.purs`, `src/Format/Parse/Declaration.purs`
  (types), `src/Format/Parse/Grammar.purs` if a combinator is missing,
  `src/Domain/Resolved.purs` (`FunctionRef Span FunctionId`, `CtorRef Span
  CtorId`, `Lambda Span (Array Param) Expr`, `Apply Span Expr (Array
  Expr)`, `Pipe Span Expr Expr`), `src/Features/Resolve/Expression.purs`,
  `src/Features/Resolve/Types.purs`, `src/Features/Resolve/Variables.purs`,
  `src/Features/Check/Infer.purs` (new nodes: `Internal "unchecked
  function"` until Task 4), `test/poly-parse.mjs` (the oracle's own
  parser, independently)
- Create: `test/fn-syntax.test.mjs`

**Interfaces:**
- Types: an arrow chain is parsed as a list of operands and folded right,
  never one recursion per `->`; nesting (ADR 006) counts a parameter side
  one level deeper and a result side not (§1).
- Expressions: `fn` then `(` at expression start is a lambda; postfix
  `(args)` repeats on any primary; a name immediately followed by `(`
  stays `Call` (so existing spans and diagnostics are unchanged), and a
  further `(…)` is `Apply`; `|>` is a left fold over comparisons.
- Resolution in this task: lambdas, `Apply` on a non-name primary or a
  further `(…)`, pipes and arrow types. Bare names and calls of locals
  keep today's resolution (E_UNBOUND, E_ARITY, E_NOT_CALLABLE) until
  Task 4. Lambda parameters
  open a scope over the body; `_` binds nothing; duplicate named
  parameters are E_DUPLICATE `Duplicate parameter x`; annotation
  variables must be the enclosing signature's (E_UNBOUND `Unbound type
  variable b`).

- [x] **Step 1: Write failing tests** in test/fn-syntax.test.mjs: each
  E_SYNTAX form of §1 with span and text; `(A, B) -> C` and `A -> B -> C`
  resolve equal; precedence of lambda, `|>` and comparison; postfix
  chains `f(1)(2)` and `(g)(x)`; `->`/`|>` lexing beside `-1` and `|`;
  the nesting measure (a 200-long written spine accepted, 129 nested
  parameter positions rejected with E_NESTING); each §2 table row,
  shadowing, `_` repetition, duplicate and unbound annotation rows. Reach:
  Parse → Resolve (test/phases.mjs).
- [x] **Step 2: Run** `node --test test/fn-syntax.test.mjs`. Expected: FAIL.
- [x] **Step 3: Implement.** No existing row changes in this task.
- [x] **Step 4: Run** `rm -rf output && npm run verify`. Expected: exit 0.
- [x] **Step 5: Commit** `feat: function types, lambdas, application and
  pipe syntax (FN001)`.

### Task 4: Checking

**Files:**
- Modify: `src/Domain/Checked/Internal.purs` (`FunctionRef`, `CtorRef`,
  partial `Call`/`Construct`, `Apply`, `Lambda (Array Param) Expr`,
  `Pipe Expr Expr`; `Param = { local ∷ Maybe LocalId, ty ∷ Ty Open }`),
  `src/Features/Check/Infer.purs`, `src/Features/Check/Call.purs`,
  `src/Features/Check/Walk.purs`, `src/Features/Check.purs` (printable
  entry; as built, Check.Signature and Check.Match needed no change: a
  function scrutinee is handled by unification and Signature's arrow
  column), `src/Domain/Problem.purs`, `src/Format/Diagnostic.purs`,
  the rows listed under Global Constraints
- Create: `src/Features/Check/Apply.purs` (application and pipe),
  `src/Features/Check/Lambda.purs`, `src/Features/Check/Hint.purs`,
  `test/fn-check.test.mjs`

**Interfaces:**
- Resolution (§2 table), moved here from Task 3 so the changed rows go
  straight to their final outcomes: a bare name is a local, else a
  function with parameters (`FunctionRef`), else a zero-parameter function
  (`FunctionNeedsCall`), else a constructor (`Construct` with no
  arguments if nullary, `CtorRef` otherwise), else today's E_UNBOUND; a
  call with arguments whose head is a local becomes `Apply (Local …)`.
  (Files: `src/Features/Resolve/Expression.purs`, `src/Domain/Resolved.purs`.)
- Named callee `f(a1…aj)`: `j = n` is today's path unchanged (arity
  checked first, arguments inferred, then unified field by field);
  `0 < j < n` checks the first `j` fields and types the result as the
  arrow of the remaining fields to the result; `j > n` checks `n`, then
  applies the result per §3 to the rest, E_ARITY `Wrong number of
  arguments` if the instantiated result is Int, Bool, a declared type or
  a rigid variable.
- Application per §3, one argument at a time; `NotAFunction` at the first
  argument that does not fit.
- Pipe checked as §5's application, recorded as `Pipe`.
- Lambda per §3; parameters unannotated get fresh metas.
- Hint per §4's provenance rules, computed in Hint.purs from the checked
  argument after `require` fails, wrapping only that failure's problem.
- Coverage: a function-typed scrutinee admits `_` and binders only.

- [x] **Step 1: Write failing tests** (Parse → Resolve → Check): partial,
  saturated and over-application of functions, constructors and locals;
  application of a non-function; `fn(f) => f(f)` E_TYPE `Infinite type`;
  comparison of `Int -> Int` and of `Box(Int)`; patterns on a function
  scrutinee; non-printable `main`; each hint provenance row of §8, and for
  each hinted row the same program's unhinted diagnostic compared field by
  field except the suffix; type rendering of nested arrows; a lambda
  annotated with the signature's rigid `a`.
- [x] **Step 2: Run** `node --test test/fn-check.test.mjs`. Expected: FAIL.
- [x] **Step 3: Implement**; update the known changed rows to their
  checked outcomes (E_TYPE texts as rendered by §3) and list each in
  progress.
- [x] **Step 4: Run** `rm -rf output && npm run verify`. Expected: exit 0;
  `twenty thousand parameters are checked in linear time` unchanged.
- [x] **Step 5: Commit** `feat: checking functions, lambdas and pipes
  (FN001)`.

### Task 5: Instantiation rule and specialization

**Files:**
- Modify: `src/Features/Check/Components.purs`,
  `src/Features/Check/Instantiation.purs` (value references and references
  inside lambdas at any depth are edges), `src/Domain/IR/Internal.purs`
  (mirrored nodes and `TFun Ty Ty`), `src/Features/Specialize/Lower.purs`,
  `src/Features/Specialize/Keys.purs`, `src/Format/Go/Data.purs` (a total
  `goType` case rendering `func(A) R` inline, unreachable behind the
  guard and replaced in Task 6), `src/Program/Compile.purs` (guard),
  `src/Features/Specialize/Body.purs`,
  `src/Features/Specialize/Seeds.purs`, `src/Features/Specialize/Copy.purs`,
  `test/poly-termination.test.mjs`, `test/poly-components.mjs`,
  `test/specialize.test.mjs` (as built: Components, Copy and
  test/specialize.test.mjs needed no change; test/poly-keys.mjs,
  test/fn-check.test.mjs and scripts/regression.mjs's `spec-key` row did)
- Create: `src/Features/Specialize/Unlowered.purs` (the guard),
  `src/Features/Specialize/Values.purs` if Body exceeds budget (created),
  `src/Features/Specialize/Intern.purs` (the arrow table, as built),
  `test/fn-specialize.test.mjs`, `test/fn-representative.test.mjs`

**Interfaces:** (Task 5 review clarification, 2026-10-08: `IR.Ty` is
`TInt | TBool | TData TypeId | TFun FunTypeId` with derived constant-time
`Eq`/`Ord`, and `IR.Program` carries `funTypes ∷ Array { parameter ∷ Ty,
result ∷ Ty }` in interned-number order, emitted from Specialize's arrow
table; this replaces the hand-written spine-loop instances first built.)
Specialize.Keys interns arrows as hash-consed nodes
(parameter number, result number), as ruling R15 interns applications,
so every suffix of a spine is numbered once and a key is compared by
numbers, never by spelling or by walking a whole type: total work linear
in the size of all key types.

- [x] **Step 1: Write failing tests:** `fn f(x: a): Int = g(fn(y) =>
  f(Cons(x, Nil)))`-shaped polymorphic recursion through a lambda inside
  a match arm is E_SPECIALIZATION at the reference; a bare `f` at a
  changed instantiation inside its component likewise; `type T(a) = C(a
  -> T(List(a)));` is E_SPECIALIZATION; the component generator gains
  value-reference edges (some inside lambdas) and still meets the §4.2
  bound; `map(id, …)` at Int and Bool specializes `id` twice; a
  5,000-parameter function type as a generic argument (`id(f)` and
  `Box(f)` with `f` a 5,000-parameter function) specializes, with two
  such keys differing only in the last parameter kept distinct, within a
  time bound that a spelling-based or re-walking key fails; the
  representative-independence property gains lambdas with unused
  parameters (checked on the IR here, executed in Task 6).
- [x] **Step 2: Run** the three files. Expected: FAIL.
- [x] **Step 3: Implement**, including the guard; a CLI test asserts a
  program with a lambda is rejected with `Internal "unlowered function"`
  (deleted with the guard in Task 6).
- [x] **Step 4: Run** `rm -rf output && npm run verify`. Expected: exit 0.
- [x] **Step 5: Commit** `feat: specialize function values (FN001)`.

### Task 6: Go lowering

**Files:**
- Modify: `src/Format/Go/Data.purs` (named function types, emitted with
  the data types, one per `IR.funTypes` entry in interned-number order;
  Task 5 review clarification, replacing first-use order; Task 5's review
  fixes already emit them),
  `src/Format/Go/Layout.purs`, `src/Format/Go/Expression.purs`,
  `src/Format/Go/Capture.purs` (a lambda's named parameters are bound in
  its body), `src/Format/Go/Usage.purs`, `src/Format/Go.purs`,
  `src/Program/Compile.purs` (guard removed)
- Delete: `src/Features/Specialize/Unlowered.purs` and its CLI test
- Create: `src/Format/Go/Stage.purs` (stage chains for wrappers and
  lambdas, Task 1's environment shape), `src/Format/Go/Apply.purs`,
  `test/fn-run.test.mjs`, `test/fn-timing.test.mjs`,
  `examples/functions.bumpus`, `bootstrap/functions.go`
- Modify: `test/support.mjs` (`panicOnEntry(goSource, functionIndex,
  label)`, beside `traceCalls`: inserts `panic("bumpus-probe: <label>")`
  as the first statement of `bumpusFn<index>`)
- As built: Format.Go.Value (named calls, partials, references, value
  application), .Lambda, .Pipe and .Entry were also created; Usage and
  Layout needed no change; test/fn-scale.test.mjs (the 5,000-parameter
  build bound) and test/fn-lambdas.mjs (Task 5's wrappers, shared with
  test/fn-representative.test.mjs) created; test/specialize.test.mjs
  excludes the new polymorphic example from its monomorphic identity
  set; scripts/depth-forms.mjs, scripts/depth-probe.mjs and
  test/fn-depth.test.mjs's comment follow the forms' move.

**Interfaces:** design §13 "adopted convention", rules 1-8, exactly:
direct calls unchanged; one node type per distinct ground Go argument
type, `{ value; previous any }`; staged wrappers `FValue`/`FStage<k>`
and an entry that fills per-type arrays through package-level kind and
slot tables and makes one n-ary call of `F`; lambdas lifted to n-ary
functions of their free locals then parameters, valued as that wrapper
partially applied to the free locals; application chains longer than 64
split into per-owner helpers that evaluate each argument in place; pipe
with a temporary unless the left operand is a literal or a local.
Named Go function types are numbered from
Task 5's interned arrow numbers, one declaration per suffix, each
declaration naming its result's type by number, so emitting them is
linear in the number of distinct suffixes; no type name is derived by
spelling a type.

- [x] **Step 1a: Write failing timing probes** in test/fn-timing.test.mjs
  with `panicOnEntry`: named value `use(stuck)`, lambda
  `use(fn(x) => stuck(x))`, partial strictness `ignore(k3(probe(1)))`,
  sharing (Review Focus 2, `traceCalls` count) and pipe order
  `probe1(1) |> g(probe2(2))`. Each asserts a non-zero exit whose output
  contains exactly its label, within the batch timeout; none recurses.
  They fail first because the guard rejects every such program.
- [x] **Step 1b: Write failing execution tests** (runGoBatch): a
  65-argument application split into two helpers and a 64-argument one
  inline, both printing the expected value; a lambda with three free
  locals and two parameters; a function of three distinct parameter
  types used as a value and also called directly (one body in the Go);
  `map`,
  `fold`, compose-by-lambda; closures capturing parameters and match
  binders (Review Focus 4); returning closures; partial and
  over-application; `add`/`stuck` timing through `use(add)` printing 0;
  constructor values and partial constructors (`map(Just, xs)`,
  `Cons(1)`); a lifted match inside a lambda reading the lambda's
  parameter; nested lambdas three deep; `|>` chains; a type with a
  function field; the Task 5 representative-independence programs run
  with Int and Bool representatives and print the same.
- [x] **Step 2: Run** `node --test test/fn-run.test.mjs
  test/fn-timing.test.mjs`. Expected: FAIL.
- [x] **Step 3: Implement.** examples/functions.bumpus: `map`, `filter`,
  `foldLeft`, `compose` written as a two-parameter function returning a
  lambda, a partial application, a pipe chain; snapshot
  bootstrap/functions.go asserted byte-equal by test/compiler.test.mjs
  alongside the others. Replace Task 5's temporary catch-all arms with
  explicit exhaustive ones: src/Format/Go/Expression.purs `_ → leaf next
  (unlowered …)` and src/Format/Go/Compare.purs `TFun _ → malformed`
  (Task 5 review, M2).
- [x] **Step 3a: Re-measure** ADR 006's margin for the FN001 forms with
  scripts/depth-probe.mjs after lowering (`functionForms` in
  scripts/depth-forms.mjs, named on the command line), then move them
  into `forms` so test/depth.test.mjs runs them through the CLI (added
  by the Task 3 review).
- [x] **Step 4: Run** `rm -rf output && npm run verify`. Expected: exit 0,
  four existing snapshots byte-identical.
- [x] **Step 5: Commit** `feat: lower functions to staged Go (FN001)`.

### Task 7: The reference interpreter and generated comparisons

The core timing probes are Task 6's. This task adds independent
evidence.

**Files:**
- Modify: `test/poly-oracle.mjs`, `test/poly-parse.mjs`,
  `test/poly-programs.mjs`, `test/poly-properties.test.mjs`,
  `test/fn-timing.test.mjs` (oracle agreement on the probes)
- Create: `test/fn-programs.mjs` (generator)

- [x] **Step 1: Write failing tests:** the interpreter, on each Task 6
  probe program, reports the same first entered probe as the Go run; the
  generated-program property (below) runs. Both fail until Step 2.
- [x] **Step 2: Extend** the reference interpreter independently:
  closures, staged application with declared arity (a function value
  remembers its remaining stage count), constructor values, `|>` with
  left-first order, and an `enters` trace so the oracle can assert the
  same first entered probe. The generator emits higher-order functions,
  lambdas, partial and over-application and pipes over the P001 types.
- [x] **Step 3: Run**; the oracle property (at least 30 programs, as P001)
  compares Go output with the interpreter.
- [x] **Step 4: Run** `rm -rf output && npm run verify`. Expected: exit 0.
- [x] **Step 5: Commit** `test: FN001 timing probes and execution oracle`.

### Task 8: Scale

**Files:**
- Modify: `test/large-source.test.mjs` (or a new
  `test/fn-scale.test.mjs` to stay under 250 lines)
- Create: `test/fn-linear.test.mjs` (Bumpus-phase cost of function
  forms), `scripts/fn-milestone.mjs` (the 20,000 tier, committed so it
  can be rerun; durability additions approved by the user 2026-10-08)

- [x] **Step 1: Write tests with time bounds**: Bumpus phases at three
  times Task 1's measured time, recorded in the test's comment, and each
  program's total `go build` at most 10 s (scale rule): a 5,000-parameter
  declaration with a mixed body, called directly, used as a value and
  partially applied with the partial shared, compiled, built and run; a
  chain of 1,000 partial applications; a 1,000-long written arrow type;
  a 5,000-parameter function type passed through a generic function and
  stored in a generic type (equality, ordering and interned keys end to
  end, with its Go types emitted); the existing 20,000-parameter and
  4,000-`Nil` tests unchanged.
- [x] **Step 1b: Commit the Task 4 review's linear-cost table as tests**
  in test/fn-linear.test.mjs, through Parse → Resolve → Check →
  Specialize: a value reference `g(f)`, over-application `id(f, …)`, a
  wide lambda, a mismatch `f(1)`, partial applications `f(1)` and
  `f(1…n-1)`, `(f)(1…n)` and a pipe, each at 20,000 parameters under a
  bound of three times its measured time (recorded in the test's
  comment), and each at 80,000 without stack failure.
- [x] **Step 2: Run** each in an isolated copy with one linear piece
  replaced at a time (derived `Eq`/`Ord` restored; spelling-based arrow
  keys; recursive spine walk; nested closures), and record that a bound
  fails (quadratic or stack failure) for each; restore.
- [x] **Step 3: Run** `rm -rf output && npm run verify`. Expected: exit 0.
- [x] **Step 4: Run the milestone tier** with the committed
  `scripts/fn-milestone.mjs`: the Step 1 programs (and Step 1b's forms
  that reach Go) at 20,000 parameters, generated as Bumpus source,
  compiled by the CLI and built with `go build`, each build at most
  100 s with an explicit timeout, run and output checked; it prints one
  line per program and exits non-zero on any failure. Not part of
  verify; run after Task 6's lowering is complete and before the final
  branch review, times recorded in progress.
- [x] **Step 5: Commit** `test: FN001 scale`.

Executed 2026-10-09 (docs/progress.md "FN001 Task 8: scale"): Step 1's
Go-building tests are in test/fn-scale.serial.test.mjs (verify's serial
phase, decision A), the 20,000-parameter milestone bodies are bounded
(decision B), and Step 2 ran three representative mutants (derived
`Eq`/`Ord`, recursive spine walk, spelling-based arrow keys) as the user
limited it; nested closures were not rerun here.

### Task 9: Regression proofs and documentation

**Files:**
- Create: `test/regression-fn.mjs` (probes, imported by
  test/regression.mjs), `docs/adr/008-functions.md`
- Modify: `scripts/regression.mjs`, `test/regression.mjs`,
  `docs/language.md`, `docs/architecture.md`, `docs/engineering.md`,
  `BACKLOG.md` (FN001 Done; follow-ups: let binding, placeholder
  application, saturation optimization, I001 wrapper arity),
  `docs/progress.md`, `docs/findings.md`, `docs/next-session.md`, README

- [x] **Step 1: Add six rows**, each with one exact needle and a probe
  that passes healthy and fails on its mutant: `stage-value` (a named
  function value lowered uncurried with an eta adapter; probe:
  `use(stuck)` must panic in `stuck`); `stage-lambda` (a lambda stage
  chain extended to its type's full arity; probe: lambda variant);
  `partial-strict` (partial arguments evaluated inside the closure;
  probe: strictness); `pipe-order` (pipe lowered as the rewritten call;
  probe: pipe order); `lambda-capture` (Capture leaves a lambda's
  parameter free; probe: lifted match in a lambda builds and prints);
  `fun-compare` (Comparable ignores arrows; probe: `Type Int -> Int is
  not comparable`). Each needle's surrounding code is shaped so the
  mutant compiles.
- [x] **Step 1b: Promote four scratchpad mutants** from Tasks 2-6 to rows
  (durability, approved by the user 2026-10-08): `block-order` (an
  application helper evaluates its block's arguments before applying
  any; probe: a 65-argument application through a declared-arity
  boundary must enter the body after argument m and before argument
  m + 1, as Task 1's order check); `value-edge` (a bare function
  reference or a reference inside a lambda is not an instantiation
  edge; probe: polymorphic recursion through a lambda is
  E_SPECIALIZATION); `functional-fixpoint` (Functional returns only its
  seeds; probe: a type functional only through another type's field is
  not comparable); `arrow-key` (arrows interned without their
  parameter; probe: `id` at two function types differing in a parameter
  specializes twice and prints both).
- [x] **Step 2: Run** `node scripts/regression.mjs`. Expected: twenty-two
  `Regression proof (…)` lines.
- [x] **Step 3: Write** ADR 008 (staging by declared arity, nested
  values, A1 lowering with Task 1's numbers, pipe order, hint
  provenance) and the language.md grammar, names, typing, evaluation and
  diagnostics sections, each claim naming its test file.
- [x] **Step 4: Run** `rm -rf output && npm run verify`. Expected: exit 0,
  twenty-two proofs; record wall time and test count.
- [x] **Step 5: Commit** `docs: FN001 ADR 008, language and regression
  proofs`.

Executed 2026-10-09 (docs/progress.md "FN001 Task 9"): the rows are in
scripts/regression-fn.mjs, the probes in test/regression-fn.mjs. As
built there is no uncurried representation to restore, so `stage-value`
and `stage-lambda` restore the defect's effect: an eta adapter at the
type's full arity. The Task 8 Step 2 derived `Eq`/`Ord` gap was not a
gap: test/type-order.test.mjs (Task 2) fails on that mutant; no
pipeline phase compares long source arrows with `Eq`/`Ord`.
