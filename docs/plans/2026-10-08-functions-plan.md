# First-Class Functions Implementation Plan (FN001)

Status: draft for the user's review, written 2026-10-08 after the design
was approved. It assumes design Amendment A1 (linear staged lowering,
design §13), which the user has not yet confirmed. Nothing is
implemented.

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
- Existing assertions are unchanged except the rows of §9, which change in
  the task that changes the behavior, each listed in that task's progress
  entry with its old and new code, span and text. Known rows:
  test/diagnostics.test.mjs `fn f(): P = Pair;`; test/adt-types.test.mjs
  `Cons`, `Cons(1)` and `helper` rows; test/adt-match.test.mjs
  `Cons(f, _) => f(1)`. Rows that keep their outcome: `x()` on a local and
  `N()` on a nullary constructor stay E_NOT_CALLABLE (application needs
  at least one argument); `f()` on a one-parameter function stays E_ARITY
  `Wrong number of arguments`; over-application whose result is not a
  function keeps E_ARITY `Wrong number of arguments` (the design's
  `Expected n argument(s)` wording is not adopted, so no existing text
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
  Internal for any program containing the new IR nodes; Task 6 deletes the
  guard. Task 3 tests through Parse → Resolve, Task 4 through Check, Task
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

- [ ] **Step 1: Write** the generator for three shapes at `n` Int
  parameters: nested closures (§7 as first approved), copied environment
  struct, linked environment (each stage allocates `{ value, previous }`;
  the last stage reads the chain into `F`'s arguments once). Each is
  called through all `n` stages and prints a value that depends on the
  first and last arguments.
- [ ] **Step 2: Run** at n = 50, 300, 1,000, 5,000 and 20,000 (the nested
  shape only up to 200). Record build and run times per shape and `n`.
- [ ] **Step 3: Decide.** Linked environment is adopted if its build at
  5,000 is within 2× of the copied struct and its run is linear in `n`
  (20,000 within 8× of 5,000 doubled twice). Otherwise adopt the copied
  struct and record the O(n²) run cost in findings. Write the result into
  design §13 and remove "proposed" only if the user has confirmed A1.
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
- Comparable: a type containing `TFun`, directly or through applied
  fields, is `NotComparable`, after the rigid and hole checks (§3).
- Inhabited: every arrow is inhabited.
- Expand and the type-reference graph treat `TFun` as a constructor of
  two arguments; `Key` renders arrows distinctly from data types.

- [ ] **Step 1: Write failing unifier tests:** arrow against arrow;
  mismatch inside a parameter and inside a result names the first
  differing subterms; meta against an arrow; occurs through an arrow
  (`α` against `α -> Int`); rigid against an arrow fails; a 5,000-long
  spine unifies without stack failure; a 1,001-deep parameter nesting is
  `TooDeep` while a 5,000-long spine is not. Extend the generated
  property tests and the independent oracle with arrows.
- [ ] **Step 2: Run** `node --test test/unify.test.mjs`. Expected: FAIL.
- [ ] **Step 3: Implement.** Comparable, Inhabited and Expand cases get
  unit tests through `checkedPoly` only once Task 4 can produce arrows;
  here their new cases are total and covered by the checker identity
  (all existing tests pass unchanged).
- [ ] **Step 4: Run** `rm -rf output && npm run verify`. Expected: exit 0,
  snapshots byte-identical, twelve regression proofs.
- [ ] **Step 5: Commit** `feat: arrow type in unification and type passes
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

- [ ] **Step 1: Write failing tests** in test/fn-syntax.test.mjs: each
  E_SYNTAX form of §1 with span and text; `(A, B) -> C` and `A -> B -> C`
  resolve equal; precedence of lambda, `|>` and comparison; postfix
  chains `f(1)(2)` and `(g)(x)`; `->`/`|>` lexing beside `-1` and `|`;
  the nesting measure (a 200-long written spine accepted, 129 nested
  parameter positions rejected with E_NESTING); each §2 table row,
  shadowing, `_` repetition, duplicate and unbound annotation rows. Reach:
  Parse → Resolve (test/phases.mjs).
- [ ] **Step 2: Run** `node --test test/fn-syntax.test.mjs`. Expected: FAIL.
- [ ] **Step 3: Implement.** No existing row changes in this task.
- [ ] **Step 4: Run** `rm -rf output && npm run verify`. Expected: exit 0.
- [ ] **Step 5: Commit** `feat: function types, lambdas, application and
  pipe syntax (FN001)`.

### Task 4: Checking

**Files:**
- Modify: `src/Domain/Checked/Internal.purs` (`FunctionRef`, `CtorRef`,
  partial `Call`/`Construct`, `Apply`, `Lambda (Array Param) Expr`,
  `Pipe Expr Expr`; `Param = { local ∷ Maybe LocalId, ty ∷ Ty Open }`),
  `src/Features/Check/Infer.purs`, `src/Features/Check/Call.purs`,
  `src/Features/Check/Walk.purs`, `src/Features/Check/Signature.purs`
  (printable entry), `src/Features/Check/Match.purs` (function
  scrutinee), `src/Domain/Problem.purs`, `src/Format/Diagnostic.purs`,
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

- [ ] **Step 1: Write failing tests** (Parse → Resolve → Check): partial,
  saturated and over-application of functions, constructors and locals;
  application of a non-function; `fn(f) => f(f)` E_TYPE `Infinite type`;
  comparison of `Int -> Int` and of `Box(Int)`; patterns on a function
  scrutinee; non-printable `main`; each hint provenance row of §8, and for
  each hinted row the same program's unhinted diagnostic compared field by
  field except the suffix; type rendering of nested arrows; a lambda
  annotated with the signature's rigid `a`.
- [ ] **Step 2: Run** `node --test test/fn-check.test.mjs`. Expected: FAIL.
- [ ] **Step 3: Implement**; update the known changed rows to their
  checked outcomes (E_TYPE texts as rendered by §3) and list each in
  progress.
- [ ] **Step 4: Run** `rm -rf output && npm run verify`. Expected: exit 0;
  `twenty thousand parameters are checked in linear time` unchanged.
- [ ] **Step 5: Commit** `feat: checking functions, lambdas and pipes
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
  `test/specialize.test.mjs`
- Create: `src/Features/Specialize/Unlowered.purs` (the guard),
  `src/Features/Specialize/Values.purs` if Body exceeds budget

- [ ] **Step 1: Write failing tests:** `fn f(x: a): Int = g(fn(y) =>
  f(Cons(x, Nil)))`-shaped polymorphic recursion through a lambda inside
  a match arm is E_SPECIALIZATION at the reference; a bare `f` at a
  changed instantiation inside its component likewise; `type T(a) = C(a
  -> T(List(a)));` is E_SPECIALIZATION; the component generator gains
  value-reference edges (some inside lambdas) and still meets the §4.2
  bound; `map(id, …)` at Int and Bool specializes `id` twice; the
  representative-independence property gains lambdas with unused
  parameters (checked on the IR here, executed in Task 6).
- [ ] **Step 2: Run** the three files. Expected: FAIL.
- [ ] **Step 3: Implement**, including the guard; a CLI test asserts a
  program with a lambda is rejected with `Internal "unlowered function"`
  (deleted with the guard in Task 6).
- [ ] **Step 4: Run** `rm -rf output && npm run verify`. Expected: exit 0.
- [ ] **Step 5: Commit** `feat: specialize function values (FN001)`.

### Task 6: Go lowering

**Files:**
- Modify: `src/Format/Go/Data.purs` (named function types, emitted with
  the data types, one per distinct ground `TFun`, in first-use order),
  `src/Format/Go/Layout.purs`, `src/Format/Go/Expression.purs`,
  `src/Format/Go/Capture.purs` (a lambda's named parameters are bound in
  its body), `src/Format/Go/Usage.purs`, `src/Format/Go.purs`,
  `src/Program/Compile.purs` (guard removed)
- Delete: `src/Features/Specialize/Unlowered.purs` and its CLI test
- Create: `src/Format/Go/Stage.purs` (stage chains for wrappers and
  lambdas, Task 1's environment shape), `src/Format/Go/Apply.purs`,
  `test/fn-run.test.mjs`, `examples/functions.bumpus`,
  `bootstrap/functions.go`

**Interfaces (§7 table with §13):** `F` for a one-parameter function
value; `FValue` stage chain, generated once per specialization used as a
value; partial `FValue(a1)…(aj)`; over-application `F(a…)(b1)…`; value
application `h(a1)(a2)…`; every lambda lifted to a stage chain numbered
per owner like lifted matches; pipe with a temporary unless the left
operand is a literal or a local; a constructor value through the
constructor's own stage chain.

- [ ] **Step 1: Write failing execution tests** (runGoBatch): `map`,
  `fold`, compose-by-lambda; closures capturing parameters and match
  binders (Review Focus 4); returning closures; partial and
  over-application; `add`/`stuck` timing through `use(add)` printing 0;
  constructor values and partial constructors (`map(Just, xs)`,
  `Cons(1)`); a lifted match inside a lambda reading the lambda's
  parameter; nested lambdas three deep; `|>` chains; a type with a
  function field; the Task 5 representative-independence programs run
  with Int and Bool representatives and print the same.
- [ ] **Step 2: Run** `node --test test/fn-run.test.mjs`. Expected: FAIL.
- [ ] **Step 3: Implement.** examples/functions.bumpus: `map`, `filter`,
  `foldLeft`, `compose` written as a two-parameter function returning a
  lambda, a partial application, a pipe chain; snapshot
  bootstrap/functions.go asserted byte-equal by test/compiler.test.mjs
  alongside the others.
- [ ] **Step 4: Run** `rm -rf output && npm run verify`. Expected: exit 0,
  four existing snapshots byte-identical.
- [ ] **Step 5: Commit** `feat: lower functions to staged Go (FN001)`.

### Task 7: Timing probes and the reference interpreter

**Files:**
- Modify: `test/support.mjs` (`panicOnEntry(goSource, functionIndex,
  label)`, beside `traceCalls`: inserts `panic("bumpus-probe: <label>")`
  as the first statement of `bumpusFn<index>`), `test/poly-oracle.mjs`,
  `test/poly-parse.mjs`, `test/poly-programs.mjs`,
  `test/poly-properties.test.mjs`
- Create: `test/fn-timing.test.mjs`, `test/fn-programs.mjs` (generator)

- [ ] **Step 1: Write failing tests:** each probe of §8 (named value
  `use(stuck)`, lambda `use(fn(x) => stuck(x))`, partial strictness
  `ignore(k3(probe(1)))`, Review Focus 2 sharing via `traceCalls` count,
  pipe order). A probe asserts a non-zero exit whose output contains
  exactly its label, within the batch timeout; none recurses.
- [ ] **Step 2: Extend** the reference interpreter independently:
  closures, staged application with declared arity (a function value
  remembers its remaining stage count), constructor values, `|>` with
  left-first order, and an `enters` trace so the oracle can assert the
  same first entered probe. The generator emits higher-order functions,
  lambdas, partial and over-application and pipes over the P001 types.
- [ ] **Step 3: Run**; the oracle property (at least 30 programs, as P001)
  compares Go output with the interpreter.
- [ ] **Step 4: Run** `rm -rf output && npm run verify`. Expected: exit 0.
- [ ] **Step 5: Commit** `test: FN001 timing probes and execution oracle`.

### Task 8: Scale

**Files:**
- Modify: `test/large-source.test.mjs` (or a new
  `test/fn-scale.test.mjs` to stay under 250 lines)

- [ ] **Step 1: Write tests with time bounds** set at three times Task 1's
  measured wall time on this machine, recorded in the test's comment: a
  5,000-parameter declaration called directly, used as a value and
  partially applied through every stage, compiled, built and run; a
  chain of 1,000 partial applications; a 1,000-long written arrow type;
  the existing 20,000-parameter and 4,000-`Nil` tests unchanged.
- [ ] **Step 2: Run** each with the linear helpers temporarily replaced by
  recursive ones in an isolated copy, and record that the bound fails
  (quadratic or stack failure); restore.
- [ ] **Step 3: Run** `rm -rf output && npm run verify`. Expected: exit 0.
- [ ] **Step 4: Commit** `test: FN001 scale`.

### Task 9: Regression proofs and documentation

**Files:**
- Create: `test/regression-fn.mjs` (probes, imported by
  test/regression.mjs), `docs/adr/008-functions.md`
- Modify: `scripts/regression.mjs`, `test/regression.mjs`,
  `docs/language.md`, `docs/architecture.md`, `docs/engineering.md`,
  `BACKLOG.md` (FN001 Done; follow-ups: let binding, placeholder
  application, saturation optimization, I001 wrapper arity),
  `docs/progress.md`, `docs/findings.md`, `docs/next-session.md`, README

- [ ] **Step 1: Add six rows**, each with one exact needle and a probe
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
- [ ] **Step 2: Run** `node scripts/regression.mjs`. Expected: eighteen
  `Regression proof (…)` lines.
- [ ] **Step 3: Write** ADR 008 (staging by declared arity, nested
  values, A1 lowering with Task 1's numbers, pipe order, hint
  provenance) and the language.md grammar, names, typing, evaluation and
  diagnostics sections, each claim naming its test file.
- [ ] **Step 4: Run** `rm -rf output && npm run verify`. Expected: exit 0,
  eighteen proofs; record wall time and test count.
- [ ] **Step 5: Commit** `docs: FN001 ADR 008, language and regression
  proofs`.
