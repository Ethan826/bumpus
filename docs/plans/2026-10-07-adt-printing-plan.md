# ADT Printing, Equality and Ordering Implementation Plan (A003)

Status: in review (Tasks 1, 2, 3, 3a, 3b, 4 done; final whole-branch review pending, Done only after its fixes). Approved 2026-10-07 for subagent-driven execution (fresh
implementer and reviewer per task, then whole-branch review). User additions
folded in: operand evaluation order tests (Tasks 1, 2), the malformed-value
visiting boundary (Task 2), helper generation split across modules.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Comparison operators on every type with one structural total
order, and printing of `main`'s value whatever its type.

**Architecture:** One new expression form, `Compare Operator Expr Expr`,
flows through every phase (Syntax → Resolved → IR). Format.Go lowers Int and
Bool comparisons to Go operators and declared types to generated per-type
helpers (`bumpusCmpN`, `bumpusShowN`). Helper generation is split by
responsibility so each file stays well under 250 lines: Format.Go.Compare
(operator text, Bool helper, comparison helpers), Format.Go.Show (printing
helpers) and Format.Go.Usage (whether the Bool helper is needed).

**Tech Stack:** PureScript 0.15.16, Spago 1.0.4, purs-tidy 0.11.1, Node test
runner, Go 1.26.4.

**Spec:** docs/plans/2026-10-07-adt-printing-design.md (approved 2026-10-07).

## Global Constraints

- AGENTS.md governs: `where` not `let … in`, no anonymous lambdas, `maybe'`
  for computed fallbacks, branch work in named helpers, 250-line files,
  80 columns, purs-tidy, layer and IR.Internal import rules.
- `bootstrap/answer.go` stays byte-identical. `bootstrap/shapes.go` changes
  only by added helpers; review each regenerated diff.
- Existing test assertions are unchanged except: the two E_ENTRY rows in
  test/diagnostics.test.mjs (missing-main message becomes
  `Expected fn main()`; the `main must return Int or Bool` row is removed)
  and the `fn main(): IntList = Nil;` E_ENTRY row in test/adt-types.test.mjs
  (becomes a positive test in Task 3), and shapes.go snapshot bytes.
- Panic text for malformed values is exactly `bumpus: malformed value`.
- Every task: each new behavioral test is seen failing before the code;
  `npm run verify` exits 0; evidence line in docs/progress.md; commit.
  Never push.

## Review Focus

1. Comparisons as `if` conditions, `match` scrutinees (`match a < b { true
   => 1, false => 0 }` is exhaustive) and call arguments run. Task 1.
2. int32 extremes and wraparound: `-2147483648 < 2147483647` is `true`;
   `2147483647 + 1 < 0` is `true`. Task 1.
3. Precedence and parentheses: `1 + 2 == 3` is `true`; `(1 == 1) == true`
   is accepted; `a < b < c` is rejected. Task 1.
4. Comparing two separately built 8192-element lists (`==` true, and `<`
   after changing the last element) runs without stack failure. Task 2;
   printing such a list ends with `Nil` plus 8192 closing parentheses, Task 3.
5. A comparison on an uninhabited type (`type V = V(V); fn f(a: V, b: V):
   Bool = a < b; fn main(): Int = 0;`) compiles and the Go builds. Task 2.

---

### Task 1: Comparison syntax, typing and primitive lowering

**Files:**
- Modify: `src/Domain/Syntax.purs` (add `Operator`, `Compare`),
  `src/Domain/Resolved.purs`, `src/Domain/IR/Internal.purs`,
  `src/Format/Lex.purs`, `src/Format/Parse/Expression.purs`,
  `src/Features/Resolve/Expression.purs`, `src/Features/Check.purs`,
  `src/Features/Check/Coverage.purs`, `src/Format/Go.purs`
- Create: `src/Format/Go/Compare.purs`, `src/Format/Go/Usage.purs`
- Test: `test/compare.test.mjs`

**Interfaces:**
- Produces, in Domain.Syntax: `data Operator = Equal | NotEqual | Less |
  LessEqual | Greater | GreaterEqual` (derive Eq); `Syntax.Compare Span
  Operator Expr Expr`; `Resolved.Compare Span Operator Expr Expr`;
  `IR.Compare Operator Expr Expr` (result `ty` is `TBool`).
- Produces, in Format.Go.Compare: `goOperator ∷ Operator → String` (`==`,
  `!=`, `<`, `<=`, `>`, `>=`); `boolHelper ∷ String` (the
  `bumpusCmpBool(a bool, b bool) int` declaration). In Format.Go.Usage:
  `needsBoolHelper ∷ IR.Program → Boolean` (Task 1: some `IR.Compare` with
  an ordering operator has Bool operands).

- [ ] **Step 1: Write failing tests in test/compare.test.mjs**

`runGo` results (each `fn main(): Bool = …;` unless shown):
`1 < 2` → `true\n`; `2 <= 2`, `3 > 2`, `2 >= 3` → `true`, `true`, `false`;
`1 == 1`, `1 != 1` → `true`, `false`; `false < true`, `true < false`,
`true == true` → `true`, `false`, `true`; the Review Focus 1-3 programs;
`fn f(x: Int): Int = if x < 0 then 0 else x; fn main(): Int = f(-5);` → `0`.

`rejectedAt` rows (exact code and span text):
- `fn main(): Bool = 1 < 2 < 3;` → E_SYNTAX at the second `<`, message
  `Comparisons do not chain`; same for `1 == 2 == 3` at the second `==`.
- `fn main(): Bool = 1 ! 2;` → E_LEX at `!`.
- `fn main(): Bool = 1 == true;` → E_TYPE at `true` (expected Int, actual
  Bool; the message is the existing TypeMismatch rendering).
- `fn main(): Bool = 1 < if true then 1 else 2;` → E_SYNTAX at `if`.
- `fn main(): Int = 1 < 2;` → E_TYPE (body Bool, result Int).

Evaluation order, test `comparison operands evaluate once each, left first`:
`fn l(): Int = 1; fn r(): Int = 2; fn main(): Bool = l() < r();` and the
same with Bool results (`false < true` via `fn l(): Bool`, which uses
`bumpusCmpBool`) and with `==`. The test instruments the emitted Go text:
after each `func bumpusFnK(...) T {\n` it inserts
`bumpusTrace = append(bumpusTrace, "K")\n`; a `goTest` file declares
`var bumpusTrace []string`, calls the main function, and prints the trace,
which must be exactly `[0 1]` (l, then r, once each). Put the instrumenting
helper in test/support.mjs as `traceCalls(goSource) → string` and give
`goTest` an optional transform of the emitted Go.

Also assert `checked(readFileSync('examples/answer.bumpus'))` still equals
bootstrap/answer.go and that a program without Bool ordering contains no
`bumpusCmpBool` while `false < true` contains it exactly once.

- [ ] **Step 2: Run `node --test test/compare.test.mjs`; expect failures
  (E_LEX on `<`).**

- [ ] **Step 3: Lexer.** Two-character tokens `=>`, `==`, `!=`, `<=`, `>=`
  are matched before single characters (generalize `arrow` to any
  two-character token); add `<` and `>` to `punctuation`. Lone `!` stays
  E_LEX.

- [ ] **Step 4: Parser.** `expression` falls through to `comparison`:
  an additive, then optionally one operator token and a second additive;
  if another operator follows, `failAt` with `Comparisons do not chain`.
  Span: left start to right end. Operator text → `Operator` mapping lives
  in Format.Parse.Expression.

- [ ] **Step 5: Resolve and check.** Resolve left then right, threading
  `next`. `checkComparison`: infer left, infer right, `require env (IR.typeOf
  first) second`, node `IR.Compare op first second`, type `TBool`. Coverage
  traverses both operands like `IR.Add`.

- [ ] **Step 6: Lower.** In Format.Go, Int or Bool `Equal`/`NotEqual` and Int
  ordering: `(L op R)`. Bool ordering: `(bumpusCmpBool(L, R) op 0)`. Emit
  `boolHelper` after `bumpusAdd` iff `needsBoolHelper`.
  `bumpusCmpBool` returns -1, 0, 1 with `false < true`.

- [ ] **Step 7: Run `node --test test/compare.test.mjs`; all pass. Run
  `npm run verify`; exit 0, answer.go and shapes.go unchanged.**

- [ ] **Step 8: Commit** `feat: comparison operators on Int and Bool (A003)`
  with a progress evidence line.

### Task 2: Structural order for declared types

**Files:**
- Modify: `src/Format/Go/Compare.purs`, `src/Format/Go/Usage.purs`,
  `src/Format/Go.purs`,
  `scripts/regression.mjs`, `test/regression.mjs`, `bootstrap/shapes.go`
- Create: `test/value-oracle.mjs`, `test/adt-order.test.mjs`

**Interfaces:**
- Consumes: Task 1 IR node and helpers.
- Produces, in Format.Go.Compare: `compareName ∷ TypeId → String`
  (`bumpusCmp<index>`); `compareHelpers ∷ Array TypeInfo → Array CtorInfo →
  String` (one function per type, TypeId order). `needsBoolHelper` is also
  true when any declared constructor has a Bool field.
- Produces, in test/value-oracle.mjs (used again in Task 3):
  `typeSystem(next)` → `{ declarations: string, types: [{ name, ctors:
  [{ name, fields: ['Int'|'Bool'|typeIndex] }] }] }`, two types `T0`,
  `T1`, 1-3 constructors named `K<type>_<ctor>`, 0-2 fields; constructor 0
  of each type has only Int/Bool fields, so bounded values always exist.
  `value(next, system, typeIndex, depth)` → `{ ctor, fields }` (Int as
  number, Bool as boolean); `compare3(system, a, b)` → -1/0/1 per spec
  section 3; `printValue(system, v)` → spec section 4 text;
  `expressionOf(next, system, v)` → a different source expression for the
  same value (Ints written as wrapping sums, subterms wrapped in
  `if true then … else …`); `parseValue(system, text)` → value.
  Reuse `generator`/`choose` from test/coverage-oracle.mjs.

- [ ] **Step 1: Write failing tests in test/adt-order.test.mjs**

With `type L = Nil | Cons(Int, L);`, executed in Go, each must print
`true`: `Nil < Cons(0, Nil)`; `Cons(1, Nil) > Cons(0, Cons(5, Nil))`;
`Cons(0, Nil) < Cons(0, Cons(0, Nil))`; `a() == b()` and
`(a() < b()) == false`, where `fn a(): L` and `fn b(): L`
both build `Cons(1, Nil)` separately. A Bool field type
`type P = P(Bool, Int);` gives `P(false, 9) < P(true, 0)`. Review Focus 4
and 5. Malformed values via `goTest`: `bumpusCmp0(bumpusTy0{tag: 2},
bumpusTy0{tag: 2})` (nil field) and `bumpusCmp0(bumpusTy0{}, bumpusTy0{})`
(unknown tag) each recover `bumpus: malformed value`. Visiting boundary,
same `L`: `bumpusCmp0(bumpusTy0{tag: 2, c1f0: 1}, bumpusTy0{tag: 2, c1f0: 2})`
(both tails nil) returns -1 without panicking, because the first field
decides; with equal heads (`c1f0: 1` on both) the nil tail is visited and
panics `bumpus: malformed value`. Evaluation order for declared types: the
Task 1 `traceCalls` test with `fn l(): L` and `fn r(): L` under `<` and `==`
prints `[0 1]`.

Oracle test `generated pairs agree with the order interpreter` (8 seeds):
per seed, one system and 8 value pairs of T0 (depth ≤ 3), including at
least two equal pairs whose right side comes from `expressionOf`. Each pair
becomes `fn pK(): Int` summing `if L op R then 2^i else 0` over the six
operators in spec order; `fn main(): Int = 0;`. A `goTest` file prints
every `bumpusFnK()`; the output must equal the masks implied by
`compare3`. The same test asserts reflexivity, antisymmetry, transitivity
and totality of `compare3` over the seed's values (a sanity check on the
interpreter; agreement is the acceptance check).

- [ ] **Step 2: Run `node --test test/adt-order.test.mjs`; expect E_INTERNAL
  or Go build failures (no helper).**

- [ ] **Step 3: Implement `compareHelpers`.** Each helper first panics on a
  tag outside 1..count for either argument, returns by tag order when tags
  differ, then compares fields left to right (Int via `<`/`>`, Bool via
  `bumpusCmpBool`, declared via the field type's helper after a nil check
  that panics), returning at the first nonzero result, else 0.

- [ ] **Step 4: Lower declared-type comparisons** to
  `(bumpusCmpN(L, R) op 0)`; emit `compareHelpers` after `declarations`.

- [ ] **Step 5: Regression rows** in scripts/regression.mjs and probes in
  test/regression.mjs: `ctor-order` (needle: the tag comparison in the
  helper, inverted) and `first-field` (fields compared last to first). The
  probe compiles the Step 1 `L` program for its assertion, runs it with
  `go run` in a work directory under .build/regression (not $TMPDIR; see
  F005) with GOCACHE under .build, and fails with `constructor order
  wrong` / `first differing field ignored`. Show each row's mutant failing.

- [ ] **Step 6: Regenerate bootstrap/shapes.go** from the CLI, review that
  the diff only adds `bumpusCmp0`; tests pass; `npm run verify` exits 0.

- [ ] **Step 7: Commit** `feat: structural order for declared types (A003)`.

### Task 3: Printing and unrestricted `main`

**Files:**
- Modify: `src/Domain/Problem.purs` (drop `EntryResult`),
  `src/Features/Resolve.purs`, `src/Format/Diagnostic.purs`,
  `src/Format/Go.purs`, `test/diagnostics.test.mjs`, `test/adt-types.test.mjs`,
  `scripts/regression.mjs`, `test/regression.mjs`, `bootstrap/shapes.go`
- Create: `src/Format/Go/Show.purs`, `test/adt-print.test.mjs`,
  `examples/tree.bumpus`,
  `bootstrap/tree.go`

**Interfaces:**
- Consumes: Task 2 value oracle and helpers.
- Produces, in Format.Go.Show: `showName ∷ TypeId → String` (`bumpusShow<index>`),
  `showHelpers ∷ Array TypeInfo → Array CtorInfo → String`.

- [ ] **Step 1: Write failing tests in test/adt-print.test.mjs**

`runGo` output: `type L = Nil | Cons(Int, L); fn main(): L =
Cons(-3, Cons(2147483647, Nil));` → `Cons(-3, Cons(2147483647, Nil))\n`;
nullary `N`; `type P = P(Bool, Int)` value `P(false, -1)`; Review Focus 4
print. `fn main(): Int = 42;` and Bool mains print as before. Missing
`main` → E_ENTRY `Expected fn main()`; `fn main(x: Int): L = Nil;` →
E_ENTRY `main must have no parameters`. Malformed: `bumpusShow0(nil,
bumpusTy0{tag: 2})` recovers `bumpus: malformed value`.

Round trip `printed values recompile to the same value` (8 seeds):
generate a system and a T0 value; program A is the declarations plus
`fn main(): T0 = <expressionOf value>;`, printing text T. Assert
`parseValue(T)` deep-equals the value, and program B, the declarations plus
`fn main(): T0 = T;`, prints T again.

Update the existing rows listed in Global Constraints; the adt-types
`fn main(): IntList = Nil;` row becomes a `runGo` assertion printing `Nil`.

- [ ] **Step 2: Run the three test files; expect E_ENTRY failures.**

- [ ] **Step 3: Entry.** Remove `EntryResult` and its check and message;
  `MissingEntry` message becomes `Expected fn main()`.

- [ ] **Step 4: Printing.** `showHelpers`: nullary appends the name; else
  name, `(`, fields joined by `, ` (Int/Bool via `fmt.Append`, declared via
  its helper after a nil check), `)`; unknown tag panics. Declared `main`
  lowers to `fmt.Println(string(bumpusShowN(nil, bumpusFnK())))`.

- [ ] **Step 5: Regression row `show-fields`** (printer emits only the first
  field) with probe printing `Cons(1, Cons(2, Nil))` exactly, failing with
  `printed value lost fields`; show its mutant failing.

- [ ] **Step 6: Example and snapshots.** examples/tree.bumpus: a binary search
  tree `type Tree = Leaf | Node(Tree, Int, Tree);`, `insert` using `<` and
  `==` (no duplicates), `main` returns the tree after inserting
  `5, 3, 8, 3, 1` and prints
  `Node(Node(Node(Leaf, 1, Leaf), 3, Leaf), 5, Node(Leaf, 8, Leaf))`.
  Add its snapshot test beside shapes; regenerate shapes.go (adds
  `bumpusShow0` only) and create tree.go from the CLI; two emits equal.

- [ ] **Step 7: `npm run verify` exits 0; commit**
  `feat: print values of any type from main (A003)`.

### Task 3a: Rename the language to Bumpus

Added 2026-10-07 at the user's request. "Sprig" collides with
Masterminds/sprig (the Go template library in Helm) and Hack Club Sprig;
"Bumpus" (the neighbors' hounds in *A Christmas Story*) was vetted clean.

**Rule:** every reference to the language name changes: `Sprig` → `Bumpus`,
`sprig` → `bumpus`, `.sprig` → `.bumpus`, including generated Go identifiers
(`sprigFn0` → `bumpusFn0`, `sprigTy`, `sprigLocal`, `sprigMatch`,
`sprigCtor`, `sprigAdd`, `sprigCmp*`, `sprigShow*`, test-side `sprigTrace`),
panic texts (`bumpus: malformed value`, `bumpus: unmatched value`), the Go
header comment, temp-dir prefixes, package names (`bumpus-bootstrap`,
spago `bumpus` and `bumpus-style`, regenerating spago.lock through Spago),
the npm script (`bumpus`), `scripts/sprig.mjs` → `scripts/bumpus.mjs`, and
`examples/*.sprig`, `negative/*.sprig` → `*.bumpus` (use `git mv`).
Exception: literal historical identifiers inside dated evidence (old module
names such as `Sprig.Check`, old command lines and log paths in
docs/progress.md, findings, completed plans, ledgers and reviews) stay
verbatim, because they name artifacts that existed; the prose language name
in those files still changes. Add one dated line at the top of
docs/progress.md recording the rename and this exception.

**Files:** everything listed by
`grep -rIl -i sprig --exclude-dir={.git,output,.spago,.build,.superpowers,.agents} .`
plus the file renames above. New: `docs/assets/bumpus.svg`.

- [ ] **Step 1: Mechanical rename** per the rule. Regenerate
  bootstrap/answer.go, shapes.go and tree.go with the CLI; each new file
  must equal the old one with `sprig` → `bumpus` and `Sprig` → `Bumpus`
  substituted (check with sed + cmp and record it). Regression needles in
  scripts/regression.mjs are renamed consistently and still match once.
- [ ] **Step 2: Icon.** `docs/assets/bumpus.svg`: a simple, original
  flat-style hound dog head (long droopy ears), 128×128 viewBox, two or
  three fixed colors on a transparent background that read on both light
  and dark GitHub themes, under 4 KB, no external references or fonts.
- [ ] **Step 3: README.** Rename throughout; show the icon at the top
  (`<img src="docs/assets/bumpus.svg" width="96" alt="Bumpus hound">`);
  one sentence on the name (the Bumpus hounds, chosen because "Sprig"
  collided with Masterminds/sprig in the Go ecosystem). Commands use
  `npm run bumpus` / `scripts/bumpus.mjs` and `.bumpus` files.
- [ ] **Step 4: Check.** `grep -rIn -i sprig` over the same scope lists only
  the permitted historical identifiers; record the remaining list in the
  report. BACKLOG gets a Done row R002 "Rename to Bumpus". `npm run verify`
  exits 0. Commit `chore: rename the language to Bumpus`.

### Task 3b: Stack-safe lexing and declaration parsing (E002 part)

Added 2026-10-07 with user approval: owning the pre-existing RangeError found
in Task 2 (sources over roughly 2.5-3.5k characters crash `compile`).

**Files:**
- Modify: `spago.yaml` (add `tailrec` as a direct dependency; already in the
  lock as a transitive one), `spago.lock` (as Spago rewrites it),
  `scripts/structure.mjs` (allow `Control.Monad.Rec.Class` in pure layers),
  `test/structure.test.mjs`, `src/Format/Lex.purs`, `src/Format/Parse.purs`,
  `test/coverage-oracle.mjs`, `docs/engineering.md`, `BACKLOG.md`
- Create: `test/large-source.test.mjs`

**Interfaces:** unchanged public signatures (`lex`, `parse`/`compile`); every
token, span and diagnostic is identical for existing inputs.

- [ ] **Step 1: Failing tests in test/large-source.test.mjs.**
  (a) `fn main(): Int = 42;` followed by 1,000,000 spaces compiles; its Go
  equals the Go of the program without the spaces. (b) 20,000 declarations
  `fn f<i>(): Int = <i>;` plus `fn main(): Int = f19999();` compile and
  `runGo` prints `19999`. (c) The same 1 MB padding followed by `@` is E_LEX
  at offset 1,000,020 (the program is 20 characters), line 1, column
  1,000,021, span length 1. (d) Lexing (a) finishes within 5 seconds (guards against the
  quadratic `Array.uncons` copying). Each must fail on the current code
  (RangeError or timeout); record the RED output.
- [ ] **Step 2: Structure gate.** A structure test case: a pure module
  importing `Control.Monad.Rec.Class` produces no finding, while
  `Control.Monad.ST` still does. Seen failing first.
- [ ] **Step 3: Lexer.** Index-based scan over the character array with
  `tailRecM` (state: index, position, tokens); each step returns `Loop`
  or `Done` through `maybe'`/`either` helpers. Linear time: no
  `Array.uncons` or `Array.drop` per character. Two-character tokens,
  words, punctuation and E_LEX behave exactly as before.
- [ ] **Step 4: Declarations.** `Format.Parse.declarations` becomes a
  `tailRecM` loop accumulating type and function declarations in order.
- [ ] **Step 5: Coverage-oracle generator.** `choose` in
  test/coverage-oracle.mjs alternates bit 0 (raw LCG mod 2^32), so
  `choose(next, 2)` is deterministic alternation. First add a test that
  80 consecutive `choose(next, 2)` draws are not a strict alternation (fails
  now); then draw from high bits (e.g. `(next() >>> 16) % count`). Existing
  coverage assertions are unchanged; if a seed-dependent assertion changes
  outcome, record it and, if it is a real compiler defect, own it.
- [ ] **Step 6:** docs/engineering.md records the allowlist change; BACKLOG
  E002 narrows to deep nesting (structured diagnostic instead of a crash),
  with corrected stack figures. `npm run verify` exits 0. Commit
  `fix: stack-safe lexing and declaration parsing (E002)`.

### Task 4: Documentation and closure

**Files:** docs/language.md, docs/adr/005-structural-order.md,
docs/architecture.md, docs/engineering.md (new regression rows, test
counts), README.md (if it states the `main` restriction), BACKLOG.md
(A003 In review), docs/progress.md, docs/findings.md, docs/next-session.md,
this plan's status line.

- [ ] **Step 1:** language.md grammar and semantics per spec sections 1-4;
  remove "ADT values cannot be printed, compared or returned from `main`".
- [ ] **Step 2:** ADR 005: structural declaration order, witness-format
  printing, helpers for every type, Bool helper on demand, malformed rule.
- [ ] **Step 3:** `rm -rf output && npm run verify` exits 0; record counts and
  the four CLI emits (answer, shapes, tree twice) compared with `cmp`.
- [ ] **Step 4: Commit** `docs: close A003` with A003 still In review.
- [ ] **Step 5:** fresh whole-branch review; fix every finding (each fix with
  a test seen failing first where behavioral), record them in
  docs/plans/adt-printing-review.md, rerun `npm run verify`, and only then
  mark A003 Done in BACKLOG.md and this plan's status.
