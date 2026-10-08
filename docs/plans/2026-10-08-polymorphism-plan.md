# Rank-1 Polymorphism Implementation Plan (P001)

Status: written 2026-10-08; awaiting the user's review and choice of
execution method. Nothing is implemented.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Parameterized types and rank-1 polymorphic functions, checked
with rigid and flexible variables and occurs-checked unification, and
lowered by a separate whole-program specialization phase to the existing
monomorphic Go.

**Architecture:** One parameterized type `Ty v` (Domain.Type) serves the
resolved program (`Ty VarId`), the checker (`Ty Flex`, rigid or meta) and
the new checked IR (`Ty Open`, rigid or hole); substitution is its monadic
bind. Check produces Domain.Checked.Internal (polymorphic, with recorded
instantiations); the new pure Features.Specialize produces the existing
Domain.IR.Internal, whose own `Ty` has no variable case, so Format.Go is
unchanged except imports. Coverage runs on the checked IR over applied
types; the instantiation rule (spec section 4) runs before it.

**Tech Stack:** PureScript 0.15.16, Spago 1.0.4, purs-tidy 0.11.1, Node test
runner, Go 1.26.4; adds the `ordered-collections` and `tuples` packages
(already in spago.lock through the style tool).

**Spec:** docs/plans/2026-10-08-polymorphism-design.md (approved
2026-10-08). Section numbers below (§n) refer to it.

## Global Constraints

- AGENTS.md governs: `where` not `let … in`; no anonymous lambdas; `maybe`,
  `maybe'`, `either` with named helpers; 250-line files (about 100 target);
  80 columns; purs-tidy; Unicode punctuation; per-declaration budgets
  (30 lines, 3 nested decisions, 8 branches, 8 where bindings); layer rules.
- bootstrap/answer.go, shapes.go and tree.go stay byte-identical (§ Preserved).
- Every existing assertion stays unchanged; every existing diagnostic keeps
  its code, span and text (test/diagnostics.test.mjs passes untouched).
- New problem texts, exactly:
  - `TypeArguments name` → `Wrong number of type arguments for <name>`
  - `Unbound UnboundTypeVariable n` → `Unbound type variable <n>`
  - `Duplicate DuplicateTypeParameter n` → `Duplicate type parameter <n>`
  - `EntryProblem EntryPolymorphic` →
    `Expected fn main() with a concrete result type`
  - `InfiniteType a b` → `Infinite type: <a> occurs in <b>`
  - `NotComparable t` → `Type <t> is not comparable`
  - `AmbiguousType t` → `Ambiguous type <t> in comparison`
  - `PolymorphicRecursion f` →
    `Recursive call to <f> changes its type arguments`
  - `NestedDatatype t` → `Recursive use of <t> changes its type arguments`
  - `SpecializationLimit n` → `More than <n> specializations`
  - Type names render `Int`, `Bool`, `a`, `_` (hole/meta), `List(Pair(Int, a))`.
- New wire code: `E_SPECIALIZATION` (ErrorCode `SpecializationError`).
- Specialization limit: `specializationLimit = 10000`, global, functions
  plus types (§6); representative for holes: `TInt` (§6).
- A regression row (scripts/regression.mjs) whose needle a task rewrites is
  updated in the same task so it still has exactly one target.
- Every task: each new behavioral test is seen failing before its code;
  `npm run verify` exits 0; an evidence entry in docs/progress.md; commit on
  branch p001 in .worktrees/p001. Never push.

## Review Focus

1. Namespaces stay separate: `fn a(a: a): a = a;` (function, parameter and
   type variable all named `a`) compiles and `a(5)` prints 5. Task 2 test
   `type variables do not collide with value names`; run in Task 7.
2. A variable fixed only by the caller's context: `fn loop(): a = loop();
   fn main(): Int = if true then 1 else loop();` prints 1. Task 7.
3. A specialized value printed and re-read: `main` returning
   `List(Pair(Int, Bool))` built by generic `zip` prints
   `Cons(Pair(1, true), Nil)`, and that text as `main`'s body prints the
   same. Task 7.
4. Depth: an 8192-element `List(Int)` built by generic `append` and counted
   by generic `length` runs without stack failure. Task 7.
5. Comparison at a ground applied type, inside a generic function too:
   `fn f(x: a, xs: List(Int)): Bool = xs < Cons(2, Nil);` with
   `f(true, Cons(1, Nil))` prints `true` (the `List(Int)` compare helper
   is generated). Task 7.

---

### Task 1: The parameterized type, the checked IR and the Specialize seam

A behavior-preserving refactor: after it, the pipeline is Parse → Resolve →
Check → Specialize → Go with no language change.

**Files:**
- Create: `src/Domain/Type.purs`, `src/Domain/Checked/Internal.purs`,
  `src/Features/Specialize.purs`, `test/specialize.test.mjs`
- Modify: `src/Domain/Resolved.purs` (re-export `Ty` as `Ty VarId`),
  `src/Domain/IR/Internal.purs` (own monomorphic `Ty`), every
  `src/Features/Check*` module (produce Checked IR), every `src/Format/Go*`
  module (import `Ty` from IR.Internal), `src/Program/Compile.purs`,
  `scripts/structure.mjs`, `test/structure.test.mjs`, `AGENTS.md`,
  `docs/engineering.md`, `docs/architecture.md`, `scripts/regression.mjs`
  (`branch` needle)

**Interfaces:**
- Produces, Domain.Type: `newtype VarId = VarId Int`; `data Ty v = TInt |
  TBool | TData TypeId (Array (Ty v)) | TVar v` with `Eq`, `Ord`,
  `Functor`, `Apply`, `Applicative`, `Bind`, `Monad` (bind = substitution);
  `ground ∷ ∀ v. Ty v → Maybe (Ty Void)`.
- Produces, Domain.Checked.Internal: the current IR shape (`Program`,
  `FunctionDecl`, `Expr`, `Node`, `Arm`, `Pattern`, `Shape`, `typeOf`,
  `spanOf`) over `Ty Open`, with `data Open = Rigid VarId | Hole Int`;
  `Call` and `Construct` carry `instantiation ∷ Array (Ty Open)` (empty now).
- Produces, Domain.IR.Internal: `data Ty = TInt | TBool | TData TypeId`;
  everything else unchanged.
- Produces, Features.Specialize: `specialize ∷ Checked.Program →
  Either Diagnostic IR.Program` (Task 1: converts ground `TData id []`;
  any argument or variable is `Internal "unspecialized type"`, unreachable
  until Task 2).
- Produces, Features.Check: `check ∷ Resolved.Program → Either Diagnostic
  Checked.Program`. Program.Compile: `parse >=> resolve >=> check >=>
  specialize`, then `emit`.
- Structure gate: Domain.Checked.Internal importable only by
  `Features.Check*` and `Features.Specialize*`; Domain.IR.Internal only by
  `Features.Specialize*` and `Format.Go*`.

- [ ] **Step 1: Write the failing gate tests** in test/structure.test.mjs:
  `graphFindings` reports `Features.Check imports Domain.IR.Internal`,
  `Format.Go imports Domain.Checked.Internal` and
  `Features.Resolve imports Domain.Checked.Internal`, and reports nothing for
  `Features.Specialize` importing both.
- [ ] **Step 2: Run** `node --test test/structure.test.mjs`. Expected: FAIL
  (the first finding is absent today).
- [ ] **Step 3: Write the failing identity test** in test/specialize.test.mjs:
  `specialize is the identity on monomorphic programs`: for
  examples/*.bumpus and the generated programs of test/properties.test.mjs
  and test/adt-properties.test.mjs (export their generators if needed),
  the specialized IR has the checked program's functions, types and
  constructors in the same order and count, and each type equal after
  dropping `[]` arguments. Byte identity is pinned by the existing
  bootstrap snapshot assertions in test/compiler.test.mjs.
- [ ] **Step 4: Implement** the modules above; the gate in
  scripts/structure.mjs becomes two `{ module, importers }` rules.
- [ ] **Step 5: Run** `rm -rf output && npm run verify`. Expected: exit 0,
  bootstrap snapshots byte-identical, eight regression proofs.
- [ ] **Step 6: Document** the two-IR gate in AGENTS.md (the "Only checking
  and lowering…" sentence), docs/engineering.md and docs/architecture.md;
  progress entry; commit `refactor: separate checked IR and specialization
  seam (P001)`.

### Task 2: Type parameters and applied types: syntax and resolution

**Files:**
- Modify: `src/Domain/Syntax.purs` (`TypeRef`: add `VarRef Span String`,
  `NamedRef Span String (Array TypeRef)`; `TypeDecl` gains `parameters ∷
  Array { name ∷ String, span ∷ Span }`), `src/Format/Parse/Declaration.purs`,
  `src/Domain/Problem.purs`, `src/Format/Diagnostic.purs`,
  `src/Domain/Resolved.purs` (`TypeInfo` gains `parameters ∷ Array String`;
  `FunctionDecl` gains `variables ∷ Array String`; `CtorInfo` gains
  `fieldSyntax ∷ Array Syntax.TypeRef` for nested reference spans),
  `src/Features/Resolve.purs`,
  `src/Features/Resolve/Types.purs` (split variable scoping into
  `src/Features/Resolve/Variables.purs` if it passes 200 lines)
- Test: `test/poly-syntax.test.mjs`

**Interfaces:**
- Consumes: Task 1's `Ty v`, `VarId`.
- Produces: resolved types `Ty VarId`. In a type declaration, VarId i is
  its i-th parameter; in a function, VarId i is the i-th distinct variable
  in first-occurrence order across parameters then result. Problems:
  `TypeArguments String`, `UnboundKind.UnboundTypeVariable`,
  `DuplicateKind.DuplicateTypeParameter`, `EntryKind.EntryPolymorphic`;
  `TypeName` gains `AppliedName String (Array TypeName)`, `VariableName
  String`, `HoleName`.

- [ ] **Step 1: Write failing rows** (exact code, span via `rejectedAt`,
  message) in test/poly-syntax.test.mjs:
  - E_SYNTAX: `type T() = A;` at `)`; `fn f(x: List()): Int = 0;` at `)`;
    `fn f(x: Int(a)): Int = 0;` at `(`; `fn f(x: a(Int)): Int = 0;` at `(`.
  - `type T(a, a) = A(a);` E_DUPLICATE at the second `a`,
    `Duplicate type parameter a`.
  - `type T(a) = A(b);` E_UNBOUND at `b`, `Unbound type variable b`.
  - With `type List(a) = Nil | Cons(a, List(a));`: `fn f(x: List): Int = 0;`
    and `fn f(x: List(Int, Int)): Int = 0;` E_ARITY at the reference,
    `Wrong number of type arguments for List`; `fn f(x: Int): Int = 0;`
    with `type B = B(List);` likewise.
  - `fn main(): List(a) = Nil;` E_ENTRY span of the declaration,
    `Expected fn main() with a concrete result type`.
  - Positive: `type List(a) = …; type Pair(a, b) = Pair(a, b); type
    Proxy(a) = Proxy; fn main(): Int = 0;` compiles; `type variables do not
    collide with value names`: `fn a(a: a): a = a; fn main(): Int = 0;`
    compiles.
  - Nesting: a type argument nested 129 deep is E_NESTING (ADR 006 limit).
- [ ] **Step 2: Run** `node --test test/poly-syntax.test.mjs`. Expected: FAIL.
- [ ] **Step 3: Implement** parser and resolver. Resolution order: type
  names, duplicates (existing order), then each declaration's parameters,
  then field types; unknown lowercase in a field is UnboundTypeVariable;
  `EntryPolymorphic` is checked where `EntryParameters` is. Constructors
  using a parameter fail checking with E_TYPE until Task 4 (record this
  intermediate limit in docs/progress.md).
- [ ] **Step 4: Run** `rm -rf output && npm run verify`. Expected: exit 0.
- [ ] **Step 5: Commit** `feat: parse and resolve type parameters (P001)`.

### Task 3: The unifier

**Files:**
- Create: `src/Features/Check/Unify.purs`, `test/unify.test.mjs`,
  `test/unify-oracle.mjs`
- Modify: `spago.yaml` (add `ordered-collections`, `tuples`),
  `scripts/structure.mjs` (`coreLibraries` adds `Data.Map`, `Data.Set`,
  `Data.Tuple`), `test/structure.test.mjs`, `docs/engineering.md`,
  `src/Domain/Problem.purs`, `src/Format/Diagnostic.purs`

**Interfaces:**
- Produces, Features.Check.Unify:
  - `data Flex = Rigid VarId | Meta Int` (`Eq`, `Ord`);
  - `newtype Subst = Subst (Map Int (Ty Flex))`; `empty ∷ Subst`;
    `apply ∷ Subst → Ty Flex → Ty Flex` (fully resolving);
    `compose ∷ Subst → Subst → Subst` (`apply (compose s2 s1) t = apply s2
    (apply s1 t)`);
  - `data Failure = Mismatch (Ty Flex) (Ty Flex) | Occurs Int (Ty Flex)`;
  - `unify ∷ Subst → Ty Flex → Ty Flex → Either Failure Subst`.
  - Rules: rigid unifies only with the same rigid; a meta binds to any type
    not properly containing it (after `apply`); `TData` unifies
    argument-wise left to right, stopping at the first failure.
- Produces, Domain.Problem: `InfiniteType TypeName TypeName` (E_TYPE).

- [ ] **Step 1: Write failing gate test**: `graphFindings` accepts
  `Data.Map` in a Features module and still rejects `Data.List`.
- [ ] **Step 2: Write failing unifier tests** in test/unify.test.mjs
  (loading `output/Features.Check.Unify/index.js`):
  - pairs: rigid a ~ Int fails `Mismatch`; rigid a ~ rigid b fails; rigid a
    ~ rigid a succeeds with empty substitution; meta ~ Int, meta ~ rigid a,
    meta ~ `List(a)` succeed; meta m ~ `List(m)` fails `Occurs`; meta m ~ m
    succeeds.
  - properties over 500 generated pairs (types of depth ≤ 4 over Int, Bool,
    two generated constructors of arity 1 and 2, rigid 0..1, metas 0..3):
    soundness `apply s l = apply s r`; idempotence `apply s (apply s t) =
    apply s t`; composition law on generated substitutions; most-general:
    pairs built as `(t1, t2)` with `σ t1 = σ t2` for a generated σ succeed,
    and `apply σ (apply s t) = apply σ t` for both sides.
  - reference: test/unify-oracle.mjs (union-find, written without reading
    Unify.purs) agrees on success for every generated pair, and on the
    unified type up to renaming of metas.
- [ ] **Step 3: Run** `node --test test/unify.test.mjs`. Expected: FAIL
  (module missing).
- [ ] **Step 4: Implement**; the occurs check and `apply` must be stack-safe
  for types nested 128 deep (E_NESTING bounds source types) and for
  substitution chains of 10,000 metas (`tailRecM` or iterative resolution).
- [ ] **Step 5: Run** `rm -rf output && npm run verify`. Expected: exit 0.
- [ ] **Step 6: Commit** `feat: occurs-checked unification with rigid
  variables (P001)`.

### Task 4: Polymorphic checking

**Files:**
- Create: `src/Features/Check/Scheme.purs` (instantiation, holes),
  `src/Features/Check/Comparable.purs`, `test/poly-check.test.mjs`
- Modify: `src/Features/Check.purs`, `src/Features/Check/Match.purs` (split
  so both stay under 200 lines), `src/Domain/Problem.purs`,
  `src/Format/Diagnostic.purs`, `scripts/regression.mjs` (`branch` needle)

**Interfaces:**
- Consumes: Task 3's `unify`, `apply`, `Flex`, `Subst`.
- Produces: `Checked.Program` whose expression and pattern types are
  `Ty Open`; each `Call`/`Construct` carries its scheme's instantiation in
  the callee's VarId order, after `apply`, with unsolved metas renamed to
  `Hole k` (k dense per function, first-occurrence order). Check state is a
  `Subst` and a meta counter threaded through `infer` (a small state record,
  not a monad transformer stack beyond what Data.Either gives).
- Produces, Domain.Problem: `NotComparable TypeName`, `AmbiguousType
  TypeName` (E_TYPE).
- Function checking order (keeps today's first-error order): parameters
  bind rigid types; body inferred with unification wherever `require`
  compared types; then the result unifies; then comparison groundness
  (§3) over the body's comparisons in source order; then holes.

- [ ] **Step 1: Write failing rows** in test/poly-check.test.mjs, with
  `List`, `Pair`, `Maybe` declared:
  - `fn f(x: a): Int = x;` E_TYPE at `x` (body), `Expected Int, found a`.
  - `fn g(x: a, y: b): a = y;` E_TYPE at `y`, `Expected a, found b`.
  - `fn id(x: a): a = x; fn pair(x: a, y: b): Pair(a, b) = Pair(x, y);
    fn main(): Pair(Int, Bool) = pair(id(1), id(true));` checks.
  - occurs: `fn same(x: a, y: a): Int = 0; fn main(): Int = match Nil {
    Cons(h, t) => same(h, t), Nil => 0 };` E_TYPE at `t`,
    `Infinite type: _ occurs in List(_)`.
  - `fn same(x: a, y: a): Bool = x == y;` E_TYPE at the first `x` of the
    comparison, `Type a is not comparable`; same for `List(a)` operands,
    `Type List(a) is not comparable`.
  - `fn main(): Bool = Nil == Nil;` E_TYPE at the first `Nil`,
    `Ambiguous type List(_) in comparison`; `Proxy == Proxy` likewise.
  - `fn f(x: a): Int = match x { 1 => 0, _ => 1 };` E_TYPE at `1`.
  - checked-IR test: the instantiation recorded for `length(Nil)` inside
    `main` is `[Hole 0]`; for `pair(id(1), id(true))`, `[Int, Bool]`.
- [ ] **Step 2: Run** `node --test test/poly-check.test.mjs`. Expected: FAIL.
- [ ] **Step 3: Implement.** Constructors get schemes from their owner's
  parameters; a call instantiates the callee's `variables`.
- [ ] **Step 4: Run** `rm -rf output && npm run verify`. Expected: exit 0,
  diagnostics characterization untouched.
- [ ] **Step 5: Commit** `feat: rank-1 polymorphic checking (P001)`.

### Task 5: The instantiation rule

**Files:**
- Create: `src/Features/Check/Components.purs` (strongly connected
  components), `src/Features/Check/Instantiation.purs`,
  `test/poly-termination.test.mjs`
- Modify: `src/Features/Check.purs` (run after typing, before coverage),
  `src/Domain/Syntax.purs` (ErrorCode `SpecializationError`),
  `src/Domain/Problem.purs`, `src/Format/Diagnostic.purs`

**Interfaces:**
- Produces: `components ∷ Array (Array Int) → Array Int` (adjacency by
  node → component index; Tarjan or Kosaraju, iterative, stack-safe for
  20,000 nodes in one chain and one cycle);
  `instantiationRule ∷ Checked.Program → Either Diagnostic Unit`.
  Problems `PolymorphicRecursion String`, `NestedDatatype String`, both
  E_SPECIALIZATION, at the reference's span (the call's span for
  functions; for types, the offending nested type reference, found by
  walking Task 2's `fieldSyntax` alongside the resolved field type).
- Rule (§4.1): each instantiation argument at an intra-component reference
  is a bare `TVar (Rigid _)` of the referrer or has no `Rigid` anywhere.

- [ ] **Step 1: Write failing rows**: accepted — `length(t)`; mutual
  `even`/`odd` over `List(a)`; `f(a, b)` calls `g(b, a)` and back; `f(a,
  b)` calls `g(a)` and back; `f(a, b)` calls `g(a, Int)`, `g(a, b)` calls
  `f(b, a)`; `type Rose(a) = Node(a, Forest(a)); type Forest(a) = Empty |
  More(Rose(a), Forest(a));`; `type T(a, b) = C(T(b, a)) | D;`.
  Rejected (E_SPECIALIZATION, exact span and text) — `fn f(x: a): Int =
  f(Cons(x, Nil));` at the call; `f(a)` calls `g(List(a))`, `g(a)` calls
  `f(a)`, at the first call; `type Nest(a) = Nil | Cons(a, Nest(List(a)));`
  at `Nest(List(a))`; the conservative case of §4.3 rejected (documented).
- [ ] **Step 2: Write the failing generated test** `wrapping an
  intra-component argument is rejected`: 200 generated components (2–4
  functions, arities 1–3, edges mixing permutation, dropping and ground
  substitution) are accepted; the same programs with one argument replaced
  by `List(v)` on an intra-component edge are rejected at that call.
- [ ] **Step 3: Run** `node --test test/poly-termination.test.mjs`.
  Expected: FAIL.
- [ ] **Step 4: Implement.**
- [ ] **Step 5: Run** `rm -rf output && npm run verify`. Expected: exit 0.
- [ ] **Step 6: Commit** `feat: reject expanding instantiations (P001)`.

### Task 6: Coverage over applied types

**Files:**
- Create: `src/Features/Check/Expand.purs`, `test/poly-coverage.test.mjs`
- Modify: `src/Features/Check/Coverage.purs`, `Signature.purs`,
  `Matrix.purs`, `Missing.purs`, `Usefulness.purs`, `Inhabited.purs` as
  needed

**Interfaces:**
- Produces, Features.Check.Expand: `expand ∷ Array TypeInfo → Array
  CtorInfo → Array (Ty Open) → Lookup Expansion`, where `Expansion` numbers
  every application reachable from the roots (finite by Task 5) and gives
  monomorphic-shaped `types`/`ctors` tables over those numbers, rigid
  variables and holes mapped to an abstract inhabited type with no heads;
  `inhabitation` then runs on these tables unchanged.
- Signature: `fieldTypes ∷ Signature → Ty Open → Head → Lookup (Array (Ty
  Open))` (the owner's arguments substituted); `candidates ∷ Signature →
  Ty Open → Lookup (Array Head)` (rigid and hole: none).

- [ ] **Step 1: Write failing rows**: `match xs { Nil => 0, Cons(_, _) =>
  1 }` over `List(a)` is exhaustive; `match x { y => 1 }` over `a` is
  exhaustive and `match x { Nothing => 0 }` is E_TYPE at the pattern
  (Task 4) — not a coverage case; with `type Void = Void(Void)`,
  `match m { Nothing => 0 }` over `Maybe(Void)` is exhaustive and
  `match m { Nothing => 0, Just(_) => 1 }` follows the ADR 003 uninhabited
  arm policy exactly as the monomorphic `type MV = N | J(Void)` does
  (assert both programs give the same verdict); a missing `Cons(_, Cons(_,
  _))` witness through `List(List(Int))`; a generic function with a
  non-exhaustive match called at two types reports one diagnostic at the
  source span.
- [ ] **Step 2: Run** `node --test test/poly-coverage.test.mjs`. Expected:
  FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `rm -rf output && npm run verify`, including
  test/coverage.test.mjs and coverage-scale.test.mjs unchanged. Expected:
  exit 0.
- [ ] **Step 5: Commit** `feat: coverage over applied types (P001)`.

### Task 7: Specialization

**Files:**
- Create: `src/Features/Specialize/Keys.purs` (key types, memo tables),
  `src/Features/Specialize/Body.purs` (copying a body under a
  substitution), `examples/lists.bumpus`, `bootstrap/lists.go`,
  `test/poly-run.test.mjs`
- Modify: `src/Features/Specialize.purs`, `test/compiler.test.mjs`
  (snapshot list), `test/large-source.test.mjs`

**Interfaces:**
- Produces, Features.Specialize: `specialize ∷ Checked.Program → Either
  Diagnostic IR.Program` (= `specializeWith TInt`); `specializeWith ∷ Ty
  Void → Checked.Program → Either Diagnostic IR.Program` (representative
  for holes; test-only use); `specializationKeys ∷ Checked.Program →
  Either Diagnostic (Array Key)` with `type Key = { declaration ∷ Int,
  function ∷ Boolean, arguments ∷ Array (Ty Void) }` in output-id order.
- Keys compared by `Ord` on `Ty Void`, never by text. Worklist and id order
  exactly as §6.

- [ ] **Step 1: Write failing tests** in test/poly-run.test.mjs, one Go
  batch (`runGoBatch`):
  - examples/lists.bumpus functions of §9, each printed from `main`.
  - Review Focus 1–5 (exact outputs above).
  - two instantiations of one function in one program (`length` at
    `List(Int)` and `List(Bool)`) both run.
  - `length(Nil)` prints `0` and shares the `List(Int)` key
    (`specializationKeys` has one `length` key).
  - limit (compile only, no Go build): a generated program with 10,000
    keys compiles; with 10,001,
    E_SPECIALIZATION `More than 10000 specializations` at the reference
    creating key 10,001.
  - large-source: 3,000 distinct instantiations compile within 5 s.
- [ ] **Step 2: Run** `node --test test/poly-run.test.mjs`. Expected: FAIL.
- [ ] **Step 3: Implement**; the worklist loop uses `tailRecM`.
- [ ] **Step 4: Generate** bootstrap/lists.go with the CLI, review it, add
  it to the snapshot assertions.
- [ ] **Step 5: Run** `rm -rf output && npm run verify`. Expected: exit 0;
  the three old snapshots unchanged.
- [ ] **Step 6: Commit** `feat: whole-program specialization (P001)`.

### Task 8: Specialization properties

**Files:**
- Create: `test/poly-oracle.mjs` (generator and untyped reference
  interpreter for polymorphic programs), `test/poly-properties.test.mjs`

**Interfaces:**
- Consumes: Task 7's `specializeWith`, `specializationKeys`; Task 5's
  accepted-component generator (export it from the Task 5 test helper
  module if shared: `test/poly-components.mjs`).

- [ ] **Step 1: Write the properties** (each must fail against a stub
  `specialize` that returns `Left`):
  - execution oracle: 30 generated programs (generic functions over
    generated parameterized types, nested ground instantiations) print what
    the interpreter computes (one Go batch);
  - uniqueness: no two keys equal in `specializationKeys`, over the same
    programs;
  - determinism: compiling twice gives equal Go; reversing declaration
    order gives the same printed output and the same key set;
  - representative independence: 30 programs with holes print the same
    under `specializeWith TInt` and `specializeWith TBool`;
  - termination bound: for Task 5's 200 accepted components at random entry
    keys, keys per component ≤ `Σ |T|^arity(d)` computed in the test (§4.2).
- [ ] **Step 2: Run** `node --test test/poly-properties.test.mjs` against the
  stub. Expected: FAIL; then against the implementation: PASS.
- [ ] **Step 3: Run** `rm -rf output && npm run verify`. Expected: exit 0.
- [ ] **Step 4: Commit** `test: specialization properties (P001)`.

### Task 9: Regression proofs and documentation

**Files:**
- Create: `test/regression-poly.mjs` (probes; test/regression.mjs imports
  it to stay under 250 lines), `docs/adr/007-specialization.md`
- Modify: `scripts/regression.mjs`, `test/regression.mjs`,
  `docs/language.md`, `docs/architecture.md`, `docs/engineering.md`,
  `BACKLOG.md` (P001 Done; follow-ups), `docs/progress.md`,
  `docs/findings.md`, `docs/next-session.md`

- [ ] **Step 1: Add four rows** to scripts/regression.mjs, each with one
  exact needle in Task 3/4/7 code and a probe in test/regression-poly.mjs:
  - `occurs`: the occurs check removed; probe compiles the Task 4 occurs
    program and requires E_TYPE `Infinite type…`;
  - `rigid`: a rigid variable unifies with any type; probe requires
    `fn f(x: a): Int = x;` rejected;
  - `instantiate`: one scheme's metas reused across uses; probe requires
    `pair(id(1), id(true))` accepted and printing `Pair(1, true)`;
  - `spec-key`: keys compare only each argument's outermost constructor;
    probe runs `fn main(): Pair(Int, Int) = Pair(length(Cons(Cons(1, Nil),
    Nil)), length(Cons(Cons(true, Nil), Cons(Nil, Nil))));` and requires it
    to build and print `Pair(1, 2)` (under the mutant both lists share one
    Go type and the build fails).
- [ ] **Step 2: Run** `node scripts/regression.mjs`. Expected: twelve
  `Regression proof (…)` lines.
- [ ] **Step 3: Write** ADR 007 (specialization phase, the instantiation
  rule and proof reference, holes and representative, opaque variables)
  and the language.md grammar, scoping, typing, rule and limit sections.
- [ ] **Step 4: Run** `rm -rf output && npm run verify`. Expected: exit 0,
  twelve regression proofs; record wall time and test count in progress.
- [ ] **Step 5: Commit** `docs: P001 ADR 007, language and regression
  proofs`.
