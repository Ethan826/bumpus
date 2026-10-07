# Applicative Parser and Depth Limit Implementation Plan (G001)

Status: approved 2026-10-07 for subagent-driven execution in
.worktrees/g001 (branch g001), with two user corrections folded in (Task 1's
long-arm test; Task 3's comparison accounting, mixed-nesting tests and probe
outcome classification). In review: Tasks 1-5 (with inserted Task 4b)
are implemented on g001 (evidence in docs/progress.md `G001 execution`);
the controller's final whole-branch review is pending, and merging into
main needs user approval.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace hand-threaded parser state with an applicative `Parser`,
make every grammar list stack-safe, reject over-deep nesting with
`E_NESTING`, and replace the resolver's hand-threaded LocalId counter.

**Architecture:** A new `Format.Parse.Grammar` module owns the `Parser`
newtype (Functor/Apply/Applicative only), its primitives and combinators;
it is the only parser code that touches `State`. Modules are ported one at a
time behind temporary adapters, which Task 2 deletes. The depth limit lives
in the parser state. The resolver gets `Features.Resolve.Fresh`, a
state-and-error type with Bind.

**Tech Stack:** PureScript 0.15.16, Spago 1.0.4, purs-tidy 0.11.1, Node test
runner, Go 1.26.4.

**Spec:** docs/plans/2026-10-07-applicative-parser-design.md (approved
2026-10-07 with the section 7 clarifications).

## Global Constraints

- AGENTS.md governs: `where` not `let … in`; no anonymous lambdas;
  `maybe`/`maybe'`/`either` with named helpers; 250-line files (~100
  target); ≤30-line declarations; 80 columns; purs-tidy; pure layers import
  only the allowlisted core libraries (Control.Monad.Rec.Class allowed;
  Data.Tuple is not — use records).
- `Parser` has Functor, Apply and Applicative instances only: no Bind,
  Monad, Alt, Plus or MonadRec instance.
- Every existing diagnostic keeps its exact code, span and message; every
  accepted program emits byte-identical Go. Check with the existing suite and
  with cmp of `node scripts/bumpus.mjs emit` for examples/{answer,shapes,tree}
  against bootstrap/*.go.
- Existing test assertions are unchanged. New behavior gets tests seen
  failing first; time-bounded tests record RED timings.
- Each task: `npm run verify` exits 0, an evidence line in docs/progress.md
  under `## G001 execution`, a commit. Never push.

## Review Focus

1. A malformed program inside a deep but legal nesting reports the same
   first error as today (order of failure vs. depth check). Task 3.
2. `match x { A => 1, }` (trailing comma) and `match x { A => 1,, }` keep
   today's acceptance and error. Task 1.
3. Error at end of input (`fn main(): Int = (1`) keeps its end-of-input span.
   Task 2.
4. A program at exactly the depth limit compiles, emits and its Go builds
   through the CLI for every nesting form. Task 3.
5. The CLI never prints a raw stack trace for any input in the new depth
   and breadth tests (it prints the JSON/plain diagnostic and exits 1).
   Task 3.

---

### Task 1: Grammar core; port Literal and Pattern

**Files:**
- Create: `src/Format/Parse/Grammar.purs`, `test/grammar.test.mjs`
- Modify: `src/Format/Parse/Literal.purs`, `src/Format/Parse/Pattern.purs`,
  `src/Format/Parse/Expression.purs` (call sites only, via adapters)

**Interfaces (produced, in Format.Parse.Grammar):**
- `newtype Parser a = Parser (State → Either Diagnostic { value ∷ a, rest ∷ State })`
  with Functor/Apply/Applicative. `State` moves into Grammar
  as today's fields (tokens, index, eof) plus `lastEnd ∷ Position` (end of
  the last consumed token, for `spanned`); Task 3 adds `depth`.
- Primitives: `token ∷ Parser Token`, `expect ∷ String → Parser Token`,
  `name`, `upperName ∷ Parser Token`, `failWith ∷ ∀ a. String → Parser a`
  (E_SYNTAX at the current token or end of input, same as `failAt`),
  `refine ∷ ∀ a b. (a → Either Diagnostic b) → Parser a → Parser b`
  (fallible map, consumes nothing extra), `defer ∷ ∀ a. (Unit → Parser a) → Parser a`.
- Choice: `type Case a = { accepts ∷ String → Boolean, parser ∷ Parser a }`,
  `on ∷ String → Parser a → Case a`, `onWhen ∷ (String → Boolean) → Parser a → Case a` (not `when`, which
  Prelude already exports),
  `dispatch ∷ Array (Case a) → Parser a → Parser a` (first case whose
  predicate accepts the next token text, else the fallback; `"<end>"` at end),
  `optionalOn ∷ String → Parser a → Parser (Maybe a)`.
- Lists (tailRecM over Either, accumulating in Format.Stack):
  `sepBy1 ∷ String → Parser a → Parser (Array a)`,
  `sepByTrailing1 ∷ String → String → Parser a → Parser (Array a)` (separator,
  closing token: a separator directly followed by the closing token ends the
  list, closing token not consumed), `commaList ∷ Parser a → Parser (Array a)`
  (empty iff next token is `)`), `chainLeft1 ∷ String → (a → a → a) → Parser a → Parser a`.
- Spans: `spanned ∷ ∀ a b. (Span → a → b) → Parser a → Parser b` (first to
  last consumed token).
- Interop until Task 2: `fromLegacy ∷ Core.Parser a → Parser a`,
  `toLegacy ∷ Parser a → Core.Parser a`.

- [ ] **Step 1: Failing tests.** test/grammar.test.mjs, through `compile`
  (`rejectedAt`/`checked` from test/support.mjs): (a) a `match` with 1,473
  valid arms — `fn f(n: Int): Int = match n { 0 => 0, 1 => 1, …, 1471 =>
  1471, _ => -1 };` (1,472 distinct integer-literal arms plus a final
  wildcard, so no arm is redundant and no constructor-list parsing is
  involved) — must compile within 5 s (RED: RangeError); (b) `match b { T => 1, }` accepted;
  `match b { T => 1,, }` keeps today's E_SYNTAX code, span and message
  (record them from the current compiler first and assert them); (c) the
  pattern/literal rows already in test/diagnostics.test.mjs stay as they are.
- [ ] **Step 2:** run; record RED.
- [ ] **Step 3:** implement Grammar; port Literal (`integerLiteral` via
  `dispatch` on `-`, `refine` for the range check — spans and messages
  "Expected digits after minus", "Expected an integer" at today's tokens)
  and Pattern (`pattern` via `dispatch`, `ctorPattern` via `optionalOn "("`,
  `arms` via `sepByTrailing1 "," "}"`). Expression keeps working through
  `fromLegacy`/`toLegacy`.
- [ ] **Step 4:** focused tests pass; `npm run verify` exits 0; cmp of the
  three emits; commit `refactor: applicative grammar core, patterns (G001)`.

### Task 2: Port Expression, Declaration and the declaration loop

**Files:**
- Modify: `src/Format/Parse/Expression.purs`, `src/Format/Parse/Declaration.purs`,
  `src/Format/Parse.purs`, `src/Format/Parse/Core.purs` (reduced to `State`
  and anything Grammar still needs, or merged into Grammar),
  `tools/style/src/Style/Check.purs` (+ `test/style.test.mjs`),
  `test/grammar.test.mjs`
- Delete: the legacy adapters.

- [ ] **Step 1: Failing tests** (time-bounded, 5 s each, RED RangeError):
  a type with 1,536 constructors; a constructor with 1,536 fields; a call
  with 1,793 arguments. (Long `+` chains are not a breadth case: they
  become E_NESTING in Task 3.) Review Focus 3:
  `fn main(): Int = (1` keeps its exact end-of-input diagnostic (record first).
- [ ] **Step 2: Style gate.** A CST rule: modules Format.Parse,
  Format.Parse.{Literal,Pattern,Expression,Declaration} contain no `do`
  block and no `>>=`/`=<<` (Grammar is exempt). Positive and negative
  fixtures in test/style.test.mjs, failing first.
- [ ] **Step 3:** port. `expression` = `dispatch [on "if" …, on "match" …] comparison`;
  comparison: additive, then `optionalOn`-style operator and second
  additive, then a `dispatch` that fails with "Comparisons do not chain" if
  another operator follows; `additive` = `chainLeft1 "+"` building
  `Add (spanBetween l r) l r`; `parenthesized` returns the inner value
  (child span rule); calls via `commaList`; `typeDeclaration` via
  `sepBy1 "|"` and `sepBy1 ","` fields; the top-level loop keeps its
  tailRecM shape over Grammar steps. Delete adapters and dead Core code.
- [ ] **Step 4:** all tests pass; no parser module grew versus HEAD~ (record
  line counts); verify; cmp; commit `refactor: applicative expressions and
  declarations (G001)`.

### Task 3: Depth limit (E_NESTING)

**Files:**
- Modify: `src/Format/Parse/Grammar.purs` (State `depth`, `nested`),
  ported productions, `src/Domain/Problem.purs` (`NestingTooDeep Int`),
  `src/Domain/Syntax.purs` (ErrorCode `NestingLimit`),
  `src/Format/Diagnostic.purs` (`E_NESTING`, `Nesting exceeds <n> levels`),
  `test/diagnostics.test.mjs` (one new family row)
- Create: `scripts/depth-probe.mjs`, `test/depth.test.mjs`,
  `docs/adr/006-nesting-limit.md`

**Interfaces:** `nested ∷ Parser a → Parser a` increments `depth` on entry,
fails with `NestingTooDeep limit` at the current token when it would exceed
`nestingLimit ∷ Int` (named constant in Grammar), restores depth on exit.
Wrapped around: parenthesized inner expression, `if` condition and both
branches, `match` scrutinee and each arm body, each call/constructor
argument, each constructor-pattern field, and each comparison operand (a
comparison raises depth by one for its right operand, as the spec counts
comparison operands). `chainLeft1` counts each additional operand as one
level (the k-th `+` raises depth by one for the rest of the chain); the
failure span is that `+` (or comparison operator) token.

- [ ] **Step 1: Probe.** scripts/depth-probe.mjs (≤100 lines): for each form
  {parens, if-condition, if-branch, match-scrutinee, match-arm,
  call-argument, constructor-argument, constructor-pattern, plus-chain},
  generate well-typed, exhaustive programs of depth d and binary-search,
  in a fresh `node scripts/bumpus.mjs emit` process per run (emit runs every
  compiler phase including Go generation, and never invokes the Go tool),
  the smallest d that overflows. Classify every run's outcome: `overflow`
  (stderr contains `RangeError` / `Maximum call stack size exceeded`),
  `diagnostic` (a structured Bumpus diagnostic: semantic rejection),
  `timeout`, or `ok`. Only `overflow` drives the search; any `diagnostic` or
  `timeout` at a depth below the overflow point is printed as an anomaly and
  investigated (a generator bug or a real defect to own), never counted as
  the limit. Also probe mixed forms (below). Print a table per form. Run it with the limit disabled (temporarily huge constant, not
  committed) and record the table in ADR 006.
- [ ] **Step 2:** choose `nestingLimit`: the largest power of two ≤ half the
  minimum measured depth (spec: 256 provisional). Record the decision.
- [ ] **Step 3: Failing tests** in test/depth.test.mjs, through the CLI
  (`node scripts/bumpus.mjs emit|run`), per form: depth = limit compiles
  and its Go builds (runs, where `main` can return it); depth = limit + 1
  exits 1 with E_NESTING, message `Nesting exceeds <limit> levels`, exact
  span; stdout/stderr never contain `RangeError` or `at ` stack frames.
  Mixed nesting (combined trees, since per-form measurements do not
  establish that combinations are safe): an `if` nested limit − k deep used
  as the left operand of a k-term sum; parentheses inside call arguments
  inside constructor arguments; a comparison whose operands are deep
  matches; each at total depth = limit compiles and builds, and at
  limit + 1 is E_NESTING. The probe measures these mixes too, and the limit
  is ≤ half the minimum over single and mixed forms.
  Review Focus 1: a syntax error at depth limit − 1 still reports its
  E_SYNTAX. RED: raw RangeError / no E_NESTING.
- [ ] **Step 4:** implement; diagnostics characterization gains the
  E_NESTING family; E003's arm counts in BACKLOG updated if they change.
- [ ] **Step 5:** verify; cmp; commit `feat: E_NESTING depth limit (G001)`.

### Task 4: Resolver numbering with Fresh

**Files:**
- Create: `src/Features/Resolve/Fresh.purs`
- Modify: `src/Features/Resolve/Expression.purs`,
  `src/Features/Resolve/Pattern.purs`, `src/Features/Resolve.purs`,
  `src/Domain/Resolved.purs` (drop `Numbered` if unused)

**Interfaces:** `newtype Fresh a = Fresh (Int → Either Diagnostic { value ∷ a, next ∷ Int })`
with Functor/Apply/Applicative/Bind/Monad; `fresh ∷ Fresh LocalId`;
`failure ∷ ∀ a. Diagnostic → Fresh a`; `liftEither ∷ ∀ a. Either Diagnostic a → Fresh a`;
`runFresh ∷ ∀ a. Int → Fresh a → Either Diagnostic a`.

- [ ] **Step 1:** characterization first: add to test/adt-match.test.mjs a
  test asserting the LocalIds in emitted Go for a program with nested
  matches, binders in several arms and shadowing (record from the current
  compiler), so numbering drift fails it.
- [ ] **Step 2:** port: no `next` threading by hand; arms and arguments via
  `traverse`; binders numbered in source pre-order; diagnostics order
  unchanged.
- [ ] **Step 3:** verify; cmp (byte-identical Go); commit
  `refactor: resolver numbering with Fresh (G001)`.

### Task 4b: Coverage breadth and parameter duplicates (inserted)

Added 2026-10-07 (controller ruling, owning defects found in Task 4): a
match of about 1,930 arms overflows the stack in Features.Check.Usefulness
(cold full compile), and the duplicate-parameter check in
Features.Resolve.Types (`uniqueParameter`) is quadratic (20,000 parameters
2.7 s).

- [ ] **Step 1: Failing tests.** A 5,000-arm integer match (4,999 distinct
  literals plus `_`) compiles within 5 s through `compile` (RED: RangeError
  in Usefulness); 20,000 parameters compile within 1 s (RED: time); the
  10,000-argument test asserts the first binder is `bumpusLocal0` and the
  last `bumpusLocal9999` in order (or is renamed to what it checks).
- [ ] **Step 2:** make Usefulness's row/arm iteration stack-safe (tailRecM or
  balanced traversal; witnesses, E_REDUNDANT and E_NON_EXHAUSTIVE choices
  unchanged — the coverage oracle and diagnostics rows are the net);
  `uniqueParameter` via Features.Resolve.Repeated, first-occurrence
  semantics unchanged.
- [ ] **Step 3:** correct the thresholds in BACKLOG E002, the test comments
  and the Task 4 report notes; verify; cmp; commit
  `fix: stack-safe coverage breadth and linear parameter duplicates (G001)`.

### Task 5: Regression row, documentation and closure

**Files:** `scripts/regression.mjs`, `test/regression.mjs`,
docs/language.md, docs/architecture.md, docs/engineering.md,
docs/adr/006-nesting-limit.md, BACKLOG.md, README.md (if it mentions
limits), docs/progress.md, docs/findings.md, docs/next-session.md, this plan.

- [ ] **Step 1:** regression row `state-thread`: mutate Grammar's `apply` so
  the second parser runs from the original state instead of the first
  parser's rest; probe compiles `examples/answer.bumpus`-equivalent source
  and must fail with `parser state not threaded`. Show the mutant failing.
- [ ] **Step 2:** docs: language.md states the nesting rule and E_NESTING;
  ADR 006 (limit, measurement table, the three options considered);
  architecture.md (Grammar, Fresh); engineering.md (the no-`do` parser gate,
  automated); BACKLOG: G001 In review, E002 narrowed to the per-reference
  name lookups, new Planned rows O001 (iterative operator-chain traversal in
  resolve/check/emit; acceptance: a 10,000-term flat sum compiles and runs
  through the CLI; comparisons still do not chain) and H001 (heap-based
  phases, if a real program needs nesting beyond the limit).
- [ ] **Step 3:** `rm -rf output && npm run verify` exits 0; cmp; commit
  `docs: close G001`. Then the controller's whole-branch review.
