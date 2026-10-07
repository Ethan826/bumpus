# Closed ADTs and Exhaustive Matching Implementation Plan

Status: Tasks 1-8 executed 2026-10-07 (commit range c2a9788..HEAD on main).
Final review complete; findings fixed in COMMIT (record:
docs/plans/closed-adts-review.md).

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add monomorphic recursive closed ADTs, typed construction, nested
`match` with Maranget exhaustiveness/redundancy, and nil-safe Go lowering.

**Architecture:** Grow each existing pure phase (Lex → Parse → Resolve →
Check → Go) and add one post-check phase, `Sprig.Check.Coverage`, over
checked IR. Constructor identity is `CtorId` in every IR; the Go tag exists
only in `Sprig.Go.Data`. Mutual recursion across modules is impossible in
PureScript, so the pattern, match and arm modules receive the expression
function as a parameter.

**Tech Stack:** PureScript 0.15.16, Spago 1.0.4, purs-tidy 0.11.1, Node test
runner, Go 1.26.4.

**Specs:** Tasks 5–7 implement `docs/plans/2026-10-07-five-layers-design.md`
(approved 2026-10-07, added mid-execution). Otherwise the spec is
`docs/plans/2026-10-07-closed-adts-design.md` (approved, including
its plan-time amendments in section 10).

## Global Constraints

- AGENTS.md governs. Use `where`, never `let … in`. No anonymous lambdas. Use
  `maybe'` for computed fallbacks. Put branch work in named helpers.
- Each maintained file is at most 250 physical lines. PureScript is 80
  columns with Unicode punctuation and is purs-tidy formatted.
- `Sprig.*` stays pure. The core library allowlist in `scripts/structure.mjs`
  stays unchanged (no `Data.Map`; use arrays).
- Only Check/*, Go/* and `Sprig.Check`/`Sprig.Go` import `Sprig.IR.Internal`.
- From Task 5 on, module names and the import rules are those of the
  five-layers design: `Sprig.*` becomes Domain/Features/Format, `Shell.*`
  becomes Runtime/Program, and the IR boundary is `Features.Check*` plus
  `Format.Go*` importing `Domain.IR.Internal`.
- `bootstrap/answer.go` stays byte-identical, and all 19 existing tests keep
  their assertions. Only two existing test lines change: the `Float` row (see
  Task 1) and the property test's parse accessor (`.functions[0]`).
- Diagnostics report the first error in phase/traversal order. E_DUPLICATE
  reports at the first duplicated declaration.
- Every task ends with `npm run verify` exiting 0, an evidence line in
  `docs/progress.md`, a BACKLOG update when its status changes, and a commit.
  Never push.
- Each new behavioral test must be seen failing before the code exists.
  Regression probes are shown failing against an isolated mutated copy.

## Review Focus

1. Deep runtime values: an 8192-element list built by repeated doubling must
   sum correctly. Its test is in Task 3.
2. `1 + match x {…}` without parentheses is E_SYNTAX, as with `if`; an empty
   `match x {}` is E_SYNTAX; a trailing comma is accepted. Tests in Task 3.
3. A binder called as a function, `Cons(f, _) => f(1)`, is E_NOT_CALLABLE.
   Using a binder outside its arm is E_UNBOUND. Tests in Task 3.
4. A match in scrutinee position and a match nested in an arm body must both
   build and run (the depth-naming amendment). Tests in Task 3.
5. A wildcard fallback over a type whose only other constructors are
   uninhabited is E_REDUNDANT. Coverage errors yield to type errors in later
   functions. Tests in Task 4.

## Shared test helpers (created in Task 1, used throughout)

`test/support.mjs` gains three helpers:

- `spanAt(source, text, nth = 0)` returns the single-line span object for the
  nth occurrence of `text`: `{start:{offset,line:1,column:offset+1}, end:…}`.
- `rejectedAt(source, code, text, nth = 0)` asserts the code, then
  `deepEqual(span, spanAt(…))`, and returns the diagnostic.
- `goTest(source, testGo)` writes the emitted `main.go` and `main_test.go` to
  a temporary directory and runs `go test main.go main_test.go`. It returns
  `{status, output}` and does not assert the status.

---

### Task 1: Syntax: tokens, reserved words, TypeRef, type declarations

**Files:**
- Modify: `src/Sprig/Model.purs`, `src/Sprig/Lex.purs`,
  `src/Sprig/Parse/Core.purs`, `src/Sprig/Parse.purs`,
  `src/Sprig/Resolve.purs`, `scripts/structure.mjs`, `test/support.mjs`,
  `test/compiler.test.mjs` (`Float` row only), `test/properties.test.mjs`
  (accessor only)
- Create: `src/Sprig/Parse/Declaration.purs`, `test/adt-syntax.test.mjs`
- Modify: `scripts/verify.mjs` (add each new test file to the `--test` list)

**Interfaces:**
- Produces in Model:
  - `data TypeRef = IntRef Span | BoolRef Span | NamedRef Span String`
  - `type CtorDecl = { name ∷ String, fields ∷ Array TypeRef, span ∷ Span }`
    (span from the name to `)`, or the name alone)
  - `type TypeDecl = { name ∷ String, ctors ∷ Array CtorDecl, span ∷ Span }`
    (span from `type` to `;`)
  - `type Program = { types ∷ Array TypeDecl, functions ∷ Array FunctionDecl }`
  - `Parameter.ty` and `FunctionDecl.result` become `TypeRef`.
  - `isUpper ∷ String → Boolean` (first character is `A`–`Z`)
- Produces elsewhere:
  - `Parse.Core.typeRef ∷ Parser TypeRef` replaces `typeName`.
    Non-`Int`/`Bool` non-uppercase input is E_SYNTAX "Expected a type".
  - `Parse.Declaration.typeDeclaration ∷ Parser TypeDecl`
  - `Parse.parse ∷ String → Either Diagnostic Program`. It dispatches on
    `type` versus `fn`.
- Transitional (removed in Task 2): Resolve maps IntRef/BoolRef to the
  existing `Ty`, makes any NamedRef E_UNBOUND "Unbound type X" at its span,
  and ignores `types`.

- [ ] **Step 1: Write failing tests in `test/adt-syntax.test.mjs`**
  - `parse` shapes:
    - `type IntList = Nil | Cons(Int, IntList);` gives two ctors; field 1 is
      `NamedRef` "IntList"; the decl span runs from offset 0 to after `;`.
    - A Tree/Forest pair parses in either order.
  - Rejections:
    - `rejectedAt` E_SYNTAX at the name for `type shape = A;`,
      `type S = a;`, `type S = _A;`
    - E_SYNTAX at `)` for `type S = A();`
    - E_SYNTAX for `fn type(): Int = 1;`, `fn f(match: Int): Int = 1;`,
      `fn f(_: Int): Int = 1;`, and `fn main(): int = 1;`
    - E_LEX for a lone `>`
  - Lexing: `=>`, `|`, `{`, `}` are single tokens. Assert via `lex` output
    texts for `a=>b|{}`: `["a","=>","b","|","{","}"]`.
  - Changed Stage 0 row in `compiler.test.mjs`:
    `['fn main(): Float = 1;', 'E_UNBOUND']`.
    `fn main(): int = 1;` (above) is the new syntax case.
- [ ] **Step 2: Run** `npm run build && node --test test/adt-syntax.test.mjs`.
  Expected: FAIL (`parse` returns an array; `type` is not reserved).
- [ ] **Step 3: Implement**
  - Lex: add `|{}` to punctuation. Scan `=>` before `=`. Reserve `type`,
    `match`, `_`.
  - Parse: TypeRef, Declaration, Program dispatch.
  - Resolve: the transitional mapping above.
  - Register `Sprig.Parse.Declaration` in `structure.mjs`.
  - Update the properties accessor to `parsed.value0.functions[0]`.
- [ ] **Step 4: Run** `npm run verify`. Expected: exit 0, all old tests green,
  `answer.go` unchanged.
- [ ] **Step 5: Commit** `feat: lex and parse ADT type declarations (A001 T1)`.

### Task 2: Types and construction end-to-end

**Files:**
- Modify: `src/Sprig/Model.purs` (remove `Ty`; it moves),
  `src/Sprig/Resolved.purs`, `src/Sprig/Resolve.purs`,
  `src/Sprig/Check.purs`, `src/Sprig/IR/Internal.purs`, `src/Sprig/Go.purs`,
  `scripts/structure.mjs`, `src/Sprig/Parse/Expression.purs` (none expected;
  construction reuses `Variable`/`Call` syntax)
- Create: `src/Sprig/Resolve/Types.purs`,
  `src/Sprig/Resolve/Expression.purs`, `src/Sprig/Go/Data.purs`,
  `test/adt-types.test.mjs`

**Interfaces:**
- Produces in Resolved:
  - `newtype TypeId = TypeId Int`, `newtype CtorId = CtorId Int`, both with
    `Eq`.
  - `data Ty = TInt | TBool | TData TypeId`
  - `type TypeInfo = { name ∷ String, ctors ∷ Array CtorId, span ∷ Span }`
  - `type CtorInfo = { name ∷ String, owner ∷ TypeId, fields ∷ Array Ty, span ∷ Span }`
  - `type Parameter = { name ∷ String, ty ∷ Ty, span ∷ Span }`
  - `type Tables = { types ∷ Array TypeInfo, ctors ∷ Array CtorInfo }`
  - `type Local = { name ∷ String, id ∷ LocalId }` (the resolver's scope)
  - `data GlobalRef = FunctionRef FunctionId | CtorRef CtorId`; the
    resolver's `Global` becomes `{ name ∷ String, ref ∷ GlobalRef }`
  - `Expr += Construct Span CtorId (Array Expr)`
  - `Program = { types ∷ Array TypeInfo, ctors ∷ Array CtorInfo, functions, entry }`
  - `describe ∷ Array TypeInfo → Ty → String` gives "Int", "Bool" or the
    type name. Stage 0 messages are unchanged.
- Produces in other modules:
  - `Resolve.Types.typeTable ∷ Syntax.Program → Either Diagnostic { types ∷
    Array TypeInfo, ctors ∷ Array CtorInfo }`. Pass 1 assigns TypeId/CtorId
    in declaration order; pass 2 resolves fields.
  - `Resolve.Types.resolveType ∷ Array TypeInfo → TypeRef → Either
    Diagnostic Ty`
  - `IR.Internal`: `Node += Construct CtorId (Array Expr)`, and `Program`
    gains `types` and `ctors`.
  - `Go.Data.declarations ∷ Array TypeInfo → Array CtorInfo → String`
    (empty string when there are no types)
  - `Go.Data.goType ∷ Ty → String`
  - `Go.Data.ctorName ∷ CtorId → String`
- Resolution order (spec section 2, with the amendments):
  1. duplicate types
  2. constructors in declaration order, against constructors plus functions
     (span: the constructor)
  3. Stage 0 `unique` over functions and parameters
  4. constructor field types
  5. signatures (parameters, then result)
  6. entry: a named result is E_ENTRY at main's span
  7. bodies
- Go bytes, pinned by the spec:
  - Struct `type sprigTy<n> struct {` with `tag uint32` and fields
    `c<ctor>f<i>`, one per line, unindented, `}`.
  - Constructor `func sprigCtor<k>(f0 …) sprigTy<n> { return sprigTy<n>{tag: t, c<k>f0: f0, …} }`.
    ADT fields are stored as `&f<i>`; primitive fields directly.
  - Declarations go after `sprigAdd`'s blank line and before the functions,
    each followed by one blank line.

- [ ] **Step 1: Write failing tests in `test/adt-types.test.mjs`**
  - Executables:
    - `type IntList = Nil | Cons(Int, IntList); fn ignore(xs: IntList): Int
      = 7; fn main(): Int = ignore(Cons(1, Cons(2, Nil)));` prints `7`.
    - A Tree/Forest pair declared after use, constructed in `main`, prints
      the constant.
    - `fn f(Nil: Int): Int = Nil;` with `Nil` declared as a constructor
      prints the argument (local first).
  - `rejectedAt` cases:

    | Source feature | Code | Span text |
    |---|---|---|
    | `type T = A; type T = B;` | E_DUPLICATE | first `type T = A;` |
    | `type A = X; type B = X;` | E_DUPLICATE | first `X` |
    | `type T = F; fn F(): Int = 1;` | E_DUPLICATE | `F` in the type |
    | field `Missing` | E_UNBOUND | `Missing` |
    | parameter type `Missing` | E_UNBOUND | `Missing` |
    | bare `Cons` | E_ARITY | `Cons` |
    | `Nil()` | E_NOT_CALLABLE | `Nil()` |
    | `Cons(1)` | E_ARITY | `Cons(1)` |
    | `Cons(true, Nil)` | E_TYPE | `true` |
    | `Foo(1)` | E_UNBOUND | `Foo(1)` |
    | `fn main(): IntList = Nil;` | E_ENTRY | the whole main declaration |
    | a bare function name `f` | E_UNBOUND | `f` (Stage 0 rule) |

  - Go: `checked` output for the IntList program contains the exact struct
    and both constructor lines given above.
- [ ] **Step 2: Run** `npm run build && node --test test/adt-types.test.mjs`.
  Expected: FAIL.
- [ ] **Step 3: Implement**
  - Move `Ty` into Resolved and update its importers.
  - Split expression resolution into `Resolve/Expression.purs`, with bare
    name and call lookup as in spec section 2.
  - The Check environment becomes `Array { id ∷ LocalId, ty ∷ Ty }` with
    E_INTERNAL on a miss.
  - Construct checking in `Check.purs`.
  - Go emission of construction and declarations.
  - Register the new modules in `structure.mjs` (only Go.Data gets IR access
    if it needs it).
- [ ] **Step 4: Run** `npm run verify`. Expected: exit 0.
- [ ] **Step 5: Commit** `feat: resolve, check and lower ADT construction (A001 T2)`.

### Task 3: Patterns and match end-to-end, without coverage

**Files:**
- Modify: Model, Resolved, IR/Internal, `Parse/Expression.purs`,
  `Resolve/Expression.purs`, `Check.purs`, `Go.purs`, `structure.mjs`,
  `scripts/regression.mjs`, `test/regression.mjs`, `test/support.mjs`
- Create: `src/Sprig/Parse/Literal.purs`, `src/Sprig/Parse/Pattern.purs`,
  `src/Sprig/Resolve/Pattern.purs`, `src/Sprig/Check/Match.purs`,
  `src/Sprig/Go/Match.purs`, `examples/shapes.sprig`, `bootstrap/shapes.go`,
  `test/adt-match.test.mjs`, `test/adt-properties.test.mjs`

**Interfaces:**
- Model:
  - `data Pattern = PWildcard Span | PBind Span String | PInt Span Int |
    PBool Span Boolean | PCtor Span String (Array Pattern)`
  - `type Arm = { pattern ∷ Pattern, body ∷ Expr, span ∷ Span }`
  - `Expr += Match Span Expr (Array Arm)`. The span runs from `match` to `}`.
- Parsing:
  - `Parse.Literal.integerLiteral ∷ Parser { value ∷ Int, span ∷ Span }`
    moves Stage 0's minus/digits/range logic here unchanged, and
    Parse/Expression uses it.
  - `Parse.Pattern.pattern ∷ Parser Pattern`
  - `Parse.Pattern.arms ∷ Parser Expr → Parser (Array Arm)`: one or more
    arms, an optional trailing comma, then `}`.
- Resolved/IR:
  - Resolved `Pattern` mirrors Model with `Bind Span LocalId` and
    `Ctor Span CtorId (Array Pattern)`.
  - IR: `Pattern`, `Shape`, `Arm` and `Match` exactly as in spec section 5.
- Resolution:
  - `type Numbered a = { value ∷ a, next ∷ Int }`, where `next` is the next
    LocalId. Expression resolution threads it in source pre-order.
  - `Resolve.Pattern.resolvePattern ∷ Array Global → Int → Pattern → Either
    Diagnostic (Numbered { pattern ∷ Resolved.Pattern, binders ∷ Array
    Local })`
  - A duplicate binder is E_DUPLICATE at the first occurrence.
- Checking:
  - `Check.Match.checkPattern ∷ Tables → Ty → Resolved.Pattern → Either
    Diagnostic { pattern ∷ IR.Pattern, locals ∷ Array { id ∷ LocalId, ty ∷
    Ty } }`
  - `Check.Match.checkMatch` takes `infer` as a parameter. It checks each arm
    as pattern, then body, then requires the first arm's type.
- Lowering:
  - `Go.Match.lowerMatch ∷ (Int → IR.Expr → String) → Int → Ty → IR.Expr →
    Array IR.Arm → String`, where the Int is the nesting depth.
  - `Go.expression` becomes depth-indexed. Function bodies start at 0;
    scrutinees use the enclosing depth; arm bodies use depth + 1.
  - Exact helper `nilGuard path = path <> " != nil"`. The regression
    mutation targets this line.
  - Each arm's condition and binders follow spec section 6. An irrefutable
    arm's condition is `true`. The function ends with
    `panic("sprig: unmatched value")`.

- [ ] **Step 1: Write failing tests in `test/adt-match.test.mjs`**
  - Executables:
    - List sum → `6`.
    - An expression-tree evaluator with nested patterns, e.g.
      `Add(Lit(n), Lit(m))` special-cased → expected value.
    - Int literal match with `-1` and a wildcard.
    - Bool match.
    - Tree/Forest size.
    - A match in an arm body, and a match in scrutinee position (Focus 4).
    - A binder shadowing a parameter.
    - Doubling `Cons(1, Nil)` 13 times and summing → `8192` (Focus 1).
    - A trailing comma.
  - `rejectedAt` cases:

    | Source feature | Code | Span text |
    |---|---|---|
    | `Cons(x, Cons(x, _))` | E_DUPLICATE | first `x` |
    | unknown pattern constructor `X` | E_UNBOUND | `X` |
    | `Cons(h)` | E_ARITY | `Cons(h)` |
    | a constructor of another type | E_TYPE | that pattern |
    | `1` against Bool | E_TYPE | `1` |
    | second arm body Bool vs Int | E_TYPE | that body |
    | `Cons(f, _) => f(1)` | E_NOT_CALLABLE | `f(1)` |
    | binder used in another arm | E_UNBOUND | the use |
    | `1 + match …` | E_SYNTAX | `match` |
    | `match x {}` | E_SYNTAX | `}` |

  - Representation, via `goTest`. Program:
    `fn second(xs: IntList): Int = match xs { Nil => 0, Cons(_, Nil) => 1,
    Cons(_, Cons(y, _)) => y }`. The test calls `sprigFn0` with
    `sprigTy0{}` and with `sprigTy0{tag: 2}`.
    - Both must recover exactly `"sprig: unmatched value"`.
    - `Cons(h, _) => h` with `sprigTy0{tag: 2, c1f0: 5}` returns `5` without
      a panic, which documents that wildcards skip validation.
  - Snapshot: `checked(examples/shapes.sprig)` equals `bootstrap/shapes.go`.
    The example uses a Shape type with a nested match, and `node
    scripts/sprig.mjs run` prints its value.
- [ ] **Step 2: Write the failing property in `test/adt-properties.test.mjs`**
  - Fixed type: `type T = A | B(Int) | C(T, T);`.
  - Seeded generator, no discards:
    - Values of depth ≤ 3.
    - 1–4 patterns of depth ≤ 2 whose root is always a constructor.
  - Each program is `fn pick(v: T): Int = match v { p1 => b1, _ => match v
    { p2 => b2, _ => … _ => 0 } };`. Each match has only two arms, so the
    `_` arm is never redundant; this stays valid once Task 4 adds coverage.
    Bodies are the arm constant plus the sum of its Int binders.
  - A JS first-match interpreter (BigInt, `asIntN(32)`) gives the expected
    value. Run 12 Go executions.
- [ ] **Step 3: Run** both new files. Expected: FAIL.
- [ ] **Step 4: Implement** the files listed above. Register the new modules
  in `structure.mjs`; only `Check.Match` and `Go.Match` get IR.Internal.
- [ ] **Step 5: Generalize `scripts/regression.mjs`**
  - Change it to a table of `{ name, file, needle, replacement, probe,
    message }`. Each row gets its own `.build/regression/<name>` copy, and
    each row keeps the exactly-one-target assertion.
  - `test/regression.mjs` takes the probe name as `argv[4]`.
  - Existing row: `branch`.
  - New row `nil-guard`: replace `nilGuard path = path <> " != nil"` with
    `nilGuard _ = "true"`. The probe compiles the `second` program with the
    given compiler, runs `goTest` for the `{tag: 2}` value, and exits 1 with
    "nil guard missing" unless the output contains `sprig: unmatched value`.
- [ ] **Step 6: Run** `npm run verify`. Expected: exit 0, and the regression
  output reports both rows failing as required on their mutants.
- [ ] **Step 7: Commit** `feat: parse, check and lower nested match (A001 T3)`.

### Task 4: Inhabitedness and coverage

**Files:**
- Modify: `src/Sprig/Model.purs` (`ErrorCode += Redundant | NonExhaustive`;
  `codeName` gains `E_REDUNDANT` and `E_NON_EXHAUSTIVE`),
  `src/Sprig/Check.purs`, `scripts/structure.mjs`, `scripts/regression.mjs`,
  `test/regression.mjs`
- Create: `src/Sprig/Check/Usefulness.purs`, `src/Sprig/Check/Coverage.purs`,
  `test/adt-coverage.test.mjs`, `test/coverage-oracle.mjs`,
  `test/coverage.test.mjs`

**Interfaces:**
- Usefulness:
  - `type Signature = { types ∷ Array TypeInfo, ctors ∷ Array CtorInfo,
    inhabited ∷ Array Boolean }`. `inhabited` is indexed by CtorId.
  - `inhabitation ∷ Array TypeInfo → Array CtorInfo → Array Boolean` is the
    least fixed point (start all false, iterate until unchanged).
  - `data Witness = WAny | WCtor CtorId (Array Witness) | WInt Int | WBool
    Boolean`
  - `useful ∷ Signature → Array (Array IR.Pattern) → Array IR.Pattern →
    Boolean`. This is U(P, q): an explicit head specializes syntactically;
    a wildcard head is complete only when it covers every inhabited
    constructor.
  - `uncovered ∷ Signature → Array (Array IR.Pattern) → Array Ty → Maybe
    (Array Witness)` is algorithm I with spec section 4's canonical choices.
- Coverage:
  - `coverage ∷ IR.Program → Either Diagnostic Unit`. Order: functions in
    declaration order, matches in pre-order. Per match, the first redundant
    arm, then exhaustiveness.
  - `renderWitness ∷ Array CtorInfo → Witness → String`
  - `Coverage.purs` contains the text `uncovered signature` exactly once (the
    regression target).
- `Check.check` runs `coverage` after all functions check.

- [ ] **Step 1: Write failing fixtures in `test/adt-coverage.test.mjs`**
  - E_NON_EXHAUSTIVE, with the span of the whole match and the exact message:
    - `Missing pattern: Cons(_, Nil)` for `Nil => 0, Cons(_, Cons(_, _)) => 1`
    - `false` for `true => 1`
    - `2` for `0 => 1, 1 => 2`
    - `Nil` for `Cons(_, _) => 1`
    - `Pair(false, _)` for `type P = Pair(Bool, Int)` with `Pair(true, _)`
    - `Pair(_, false)` for `Pair(Int, Bool)` with `Pair(_, true)`
  - Uninhabited cases, with `type Void = V(Void)`:
    - `type U = Z(Void) | Y | X`, `match u { X => 1 }` → `Y`
    - `type T = A | C(Void)`:
      - `A => 1` is accepted (exhaustive) and runs.
      - `A => 1, C(x) => 2` is accepted.
      - `A => 1, _ => 2` is E_REDUNDANT at `_` (Focus 5).
  - E_REDUNDANT at the arm pattern:
    - `_ => 0, Nil => 1` → `Nil`
    - `true => 1, true => 2` → second `true`, not non-exhaustive
  - Ordering:
    - In an outer non-exhaustive match whose arm holds a redundant inner
      match, the outer is reported.
    - An earlier function's non-exhaustive match loses to a later function's
      E_TYPE (Focus 5).
  - Wire: CLI JSON `code` is `E_NON_EXHAUSTIVE` for a fixture file.
- [ ] **Step 2: Write the failing oracle property (`test/coverage.test.mjs`,
  helpers in `test/coverage-oracle.mjs`)**
  - Types, all inhabited: `type T = A | B(Bool) | C(T, Int);` and Bool.
  - Seeded, 300 cases, compile only. Each case has 1–4 arms with pattern
    depth ≤ 2, Int literals from {0, 1, -1}, and binders and wildcards.
  - Enumerate values to max depth + 1. Int values are the literals present
    plus one fresh value. Deeper subtrees are an opaque leaf that only
    wildcards and binders match.
  - Expected result: the first arm that first-matches no value gives
    E_REDUNDANT at that arm's pattern offset; otherwise, if some value is
    unmatched, E_NON_EXHAUSTIVE; otherwise accepted.
  - For E_NON_EXHAUSTIVE, parse the witness text and assert that some
    enumerated value matching it is matched by no arm.
- [ ] **Step 3: Run** both files. Expected: FAIL (non-exhaustive programs
  compile).
- [ ] **Step 4: Implement** Usefulness and Coverage, register both in
  `structure.mjs` with IR.Internal access, and add the new error codes.
- [ ] **Step 5: Add regression row `exhaustive`**
  - Replace `uncovered signature` with `const (const Nothing)`.
  - The probe requires `fn main(): Int = 0; type L = N | K(Int, L); fn
    f(x: L): Int = match x { N => 0 };` to be rejected E_NON_EXHAUSTIVE.
    Otherwise it exits 1 with "non-exhaustive match was accepted".
- [ ] **Step 6: Run** `npm run verify`. Expected: exit 0, and all three
  regression rows are proven.
- [ ] **Step 7: Commit** `feat: Maranget coverage with inhabitedness (A001 T4)`.

### Task 5: Five-layer module moves and layer gate

Spec: `docs/plans/2026-10-07-five-layers-design.md`. This task is mechanical:
no behavior, bytes, diagnostic text, spans or exit statuses change.

**Files (module renames, `git mv` plus import updates):**

| From | To |
|---|---|
| `Sprig.Model` | `Domain.Syntax`; `Token` and `isUpper` move to `Format.Lex`; `codeName` moves to `Format.Diagnostic` |
| `Sprig.Resolved` | `Domain.Resolved` |
| `Sprig.IR.Internal` | `Domain.IR.Internal` |
| `Sprig.Resolve`, `Sprig.Resolve.{Expression,Pattern,Types}` | `Features.Resolve`, `Features.Resolve.{…}` |
| `Sprig.Check`, `Sprig.Check.{Match,Usefulness,Coverage}` | `Features.Check`, `Features.Check.{…}` |
| `Sprig.Lex` | `Format.Lex` |
| `Sprig.Parse`, `Sprig.Parse.{Core,Declaration,Expression,Literal,Pattern}` | `Format.Parse`, `Format.Parse.{…}` |
| `Sprig.Go`, `Sprig.Go.{Data,Match}` | `Format.Go`, `Format.Go.{…}` |
| `Sprig.Compiler` | `Program.Compile` |
| `Shell.CLI` (.purs) | `Program.Main` |
| `Shell/CLI.js` (the FFI) | `Runtime.Node` (`src/Runtime/Node.purs` with its `.js`). `Program.Main` imports `launch` from it. |

- Modify: `scripts/structure.mjs`, `test/structure.test.mjs` (fixture module
  names only), `scripts/regression.mjs` and `test/regression.mjs` (paths and
  module names), every `test/*.mjs` import of `output/<Module>`,
  `scripts/sprig.mjs`, `AGENTS.md` (the two lines naming `Sprig.*`, `Shell.*`
  and `Sprig.IR.Internal`), `docs/engineering.md` (the gate description).

**Interfaces:**
- Produces in `scripts/structure.mjs`:
  - `layers = ['Domain', 'Features', 'Format', 'Runtime', 'Program']`
  - `layerOf(moduleName)` returns the first segment. A module under `src/`
    whose first segment is not a layer is a finding: "unlayered module".
- Rules replacing today's per-module `dependencies` table:
  1. A project import must go to the same or an earlier layer; otherwise
     "`A` (Layer) imports `B` (LaterLayer)".
  2. Domain/Features/Format import only `Prelude`, `Data.(Array|Either|Maybe|
     Int|String|Foldable|Traversable)` and project modules. `Unsafe`/
     `Partial`, `Effect` and any FFI file are findings.
  3. Only `Features.Check*` and `Format.Go*` import `Domain.IR.Internal`.
  4. `.js` files under `src/` exist only under `src/Runtime/`.
- `graphFindings` and `textFindings` keep their exported names and shapes.

- [ ] **Step 1: Update `test/structure.test.mjs`**
  - Rename the existing fixture modules to their new names. Each existing
    case keeps its meaning: an effect in Domain, a reverse dependency, an
    unchecked IR access, `Unsafe.Coerce` in Format, Domain importing
    `Format.Go`, `Data.String.Unsafe`, the accepted `Features.Check`
    case, and an unknown module.
  - Add failing cases:
    - `Features.Resolve` importing `Format.Parse` → 1 finding (a later
      layer).
    - `Runtime.Node` importing `Program.Main` → 1 finding.
    - `Program.Main` importing `Effect` → 0 findings.
    - `Sprig.Old` under `src/` → 1 "unlayered module" finding.
- [ ] **Step 2: Run** `npm run build && node --test test/structure.test.mjs`.
  Expected: FAIL (the new layer cases).
- [ ] **Step 3: Implement** the moves and the gate rules above. Update every
  import, script path and regression needle path.
- [ ] **Step 4: Run** `npm run verify`. Expected: exit 0, test count
  unchanged plus the new structure cases, all three regression rows proven.
  `cmp` shows `bootstrap/answer.go` and `bootstrap/shapes.go` unchanged.
  `git grep -n "Sprig\.\|Shell\." src scripts test` shows no stale module
  names (prose mentioning the language name Sprig is fine).
- [ ] **Step 5: Commit** `refactor: adopt five named layers (A001 T5)`.

### Task 6: Structured diagnostics rendered by Format

Spec: five-layers design, evaluation 1. Messages stay byte-identical.

**Files:**
- Modify: `src/Domain/Syntax.purs`, the `Features.*` modules that build
  messages, `Format.Lex`/`Format.Parse*` (diagnostic construction only),
  `src/Format/Diagnostic.purs`, `src/Program/Main.purs`,
  `src/Domain/Resolved.purs` (`describe` leaves), `scripts/structure.mjs`
  if imports change
- Create: `test/diagnostics.test.mjs`

**Interfaces:**
- Domain:
  - `type Diagnostic = { problem ∷ Problem, span ∷ Span }`
  - `data TypeName = IntName | BoolName | DataName String`
  - `data Witness = WAny | WCtor String (Array Witness) | WInt Int | WBool
    Boolean` (constructor names resolved; no surface syntax)
  - `data Problem` has one constructor per distinct message family produced
    today, carrying data rather than text. It must include:
    - `TypeMismatch TypeName TypeName`
    - `NonExhaustive Witness`
    - `RedundantArm`
    - `Unbound UnboundKind String`
    - `Duplicate DuplicateKind String`
    - `Arity`
    - `NotCallable String`
    - `EntryProblem EntryKind`
    - `IntegerOutOfRange`
    - `Internal String`
    - `Lexical` and `Syntax String`. The parser and lexer are Format, so
      their payload may be text.
  - `ErrorCode` stays the closed ADT in Domain.
- Format:
  - `Format.Diagnostic.code ∷ Problem → ErrorCode`
  - `Format.Diagnostic.codeName ∷ ErrorCode → String` (moved in Task 5)
  - `Format.Diagnostic.message ∷ Problem → String`. It renders type names
    (`Int`, `Bool`, the declared name) and witnesses (`Cons(_, Nil)`,
    `-1`, `true`, `_`) exactly as today.
  - `Format.Diagnostic.wire ∷ Diagnostic → { code ∷ String, message ∷
    String, span ∷ Span }`
- Features modules no longer build message strings, and `describe` and
  `renderWitness` leave Features/Domain. Coverage returns `NonExhaustive
  (Witness …)` with names resolved from `CtorInfo`.

- [ ] **Step 1: Write `test/diagnostics.test.mjs` as a characterization test
  at HEAD before any change.** For one source per message family (every
  rejection source already used in compiler, adt-syntax, adt-types,
  adt-match and adt-coverage tests is acceptable), record
  `{code, span, message}` from the current compiler into the test as
  literal expected values, and assert them exactly. Run it. Expected: PASS
  at HEAD. This is the behavior-preservation baseline; there is no RED for
  a refactor.
- [ ] **Step 2: Add the failing structural assertion**
  - Import `Format.Diagnostic.message` from `output/` and assert that
    `message` applied to a constructed `TypeMismatch (DataName "IntList")
    IntName` gives `"Expected IntList, found Int"`.
  - Add `NonExhaustive` with a constructed nested witness for `Cons(_,
    Nil)` and assert its exact text.
  - Run. Expected: FAIL (module/constructors absent).
- [ ] **Step 3: Implement.** Change every diagnostic site to construct
  `Problem` data. Have `Program.Main`/`Program.Compile` render through
  `Format.Diagnostic.wire`.
- [ ] **Step 4: Run** `npm run verify`. Expected: exit 0; the
  characterization test is unchanged and passing; the regression rows'
  probes still match on code (update a probe only if it asserted a
  constructor name that moved, and keep its assertion's meaning).
- [ ] **Step 5: Commit** `refactor: structured diagnostics rendered in Format (A001 T6)`.

### Task 7: Capability ports and fakeable commands

Spec: five-layers design, evaluations 3–4. CLI behavior stays identical:
- usage error is `E_USAGE`, status 2;
- IO failure is `E_IO`, status 1;
- tool failure is `E_TOOL`, status 1, wire `{ ok: false, code, message,
  command }`;
- a source diagnostic is status 1, wire `{ code, message, span, file }`;
- emit writes the Go text; build writes the binary; run prints the
  program's stdout;
- the temporary directory is always removed; `GOCACHE` handling is
  unchanged.

**Files:**
- Create: `src/Domain/Host.purs`, `src/Format/Arguments.purs`,
  `src/Program/Command.purs`, `test/program.test.mjs`
- Modify: `src/Runtime/Node.purs` and `src/Runtime/Node.js` (they become
  port implementations only, with no command logic and no argv
  interpretation), `src/Program/Main.purs`, `scripts/structure.mjs`

**Interfaces:**
- `Domain.Host`:
  - `data HostFailure = IoFailure String | ToolFailure { message ∷ String,
    command ∷ String }`
  - ```text
    type Host m =
      { readSource ∷ String → m (Either HostFailure String)
      , writeText ∷ String → String → m (Either HostFailure Unit)
      , buildExecutable ∷ String → String → m (Either HostFailure Unit)
      , runProgram ∷ String → m (Either HostFailure String)
      }
    ```
  - `buildExecutable goSource binaryPath` and `runProgram goSource` own
    their temporary directory and its removal in Runtime.
- `Format.Arguments`:
  - `data Invocation = Emit String String | Build String String | Run String`
  - `invocation ∷ Array String → Either String Invocation`. The Left is the
    usage text, unchanged.
- `Program.Command`:
  - `type Outcome = { status ∷ Int, stdout ∷ String, stderr ∷ Maybe
    WireRecord }`
  - `command ∷ ∀ m. Monad m ⇒ Host m → Array String → m Outcome`
  - `WireRecord` is the plain record Format builds for each failure kind.
    Runtime JSON-serializes it.
- `Runtime.Node`: `nodeHost ∷ Host Effect`, plus the argv, stdout/stderr
  and exit-code primitives `Program.Main` uses.
- `Program.Main.main` wires `nodeHost` into `command`, then writes the
  outcome.

- [ ] **Step 1: Write failing `test/program.test.mjs`**
  - Import `command` from `output/Program.Command` and `monadEffect` from
    `output/Effect`. Build fake hosts as JS records whose functions return
    Effect thunks producing `Left`/`Right` values from `output/Data.Either`.
  - Assert exact `status`, `stdout` and parsed `stderr` for:
    - bad arguments → 2, `E_USAGE`;
    - `readSource` → `IoFailure` → 1, `E_IO`;
    - a source with a type error → 1, the wire diagnostic with `file`;
    - `emit` → the fake `writeText` received exactly `checked(source)` at
      the destination;
    - `build` with `ToolFailure` → 1, `E_TOOL` with `ok: false` and
      `command`;
    - `run` → stdout is the fake `runProgram`'s output.
  - The fakes record calls, so the test also asserts that `run` never calls
    `writeText` and that a failed read calls nothing else.
  - Run. Expected: FAIL (module absent).
- [ ] **Step 2: Implement** `Domain.Host`, `Format.Arguments`,
  `Program.Command`, `Runtime.Node` (ports) and `Program.Main` (wiring).
  Register them in `structure.mjs`; `Runtime.Node` holds the only FFI.
- [ ] **Step 3: Run** `npm run verify`. Expected: exit 0. The existing
  end-to-end `test/shell.test.mjs`, which spawns real processes, passes
  unchanged, alongside the new fake-host tests.
- [ ] **Step 4: Commit** `refactor: capability ports with fakeable commands (A001 T7)`.

### Task 8: Documentation, closure and final review

**Files:**
- Create: `docs/adr/003-closed-adts.md`. It covers representation A, the
  nil-guard safety policy, the uppercase rule, the reserved words and the
  `Float` change, CtorId versus tag, depth naming, and why decision trees are
  deferred.
- Modify:
  - `docs/language.md`: the full grammar from spec section 1 and the
    semantics from sections 2–4.
  - `docs/architecture.md`: rewritten around the five layers (from the
    layers design), plus the coverage phase, the type table, and the
    future-stages line (target-neutral `Features.Lower` deferred).
  - Create `docs/adr/004-five-layers.md`: the layer rule, the four-change
    evaluation, ports, structured diagnostics, and the UTF-16 offset leak.
  - `docs/provenance.md`: a Maranget JFP 2007 row, independent
    implementation; a row for MileAhead `AGENTS.md` "Layers, and where
    PureScript stops" and "Dependencies are values", and
    `docs/writing/2026-09-16-an-svg-is-not-a-drawing.md` (conceptual only).
  - `docs/engineering.md`: the allowlist modules, the regression rows, and
    the E003 count.
  - `BACKLOG.md`: A001 Done. E003 widens to twelve arms. New Planned rows:
    decision-tree match compilation; ADT printing/equality; full-value FFI
    validation (fold into I001).
  - `docs/plans/bootstrap.md` index, `docs/progress.md`,
    `docs/next-session.md`, and `README.md` if it lists language features.

- [ ] **Step 1:** Write the docs above. Docs claim only behavior that a test
  in Tasks 1–7 verifies; label everything else as proposed.
- [ ] **Step 2:** Run `npm run verify` to `.build/a001-final.log`. Expected:
  exit 0, all tests (19 original plus the new files), zero skips, and three
  regression rows proven.
- [ ] **Step 3:** Two CLI emits of `examples/shapes.sprig` compare
  byte-equal to each other and to `bootstrap/shapes.go`; `answer.go` is
  unchanged (`cmp`).
- [ ] **Step 4:** Dispatch one fresh reviewer over the A001 commit range
  against both specs. Record the findings in
  `docs/plans/closed-adts-review.md`, and fix or backlog every one.
- [ ] **Step 5: Commit** `docs: close A001 closed ADTs milestone`.
