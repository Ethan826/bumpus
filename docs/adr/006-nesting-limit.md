# ADR 006: nesting limit (E_NESTING)

Accepted and implemented 2026-10-07 (milestone G001, Task 3). Binding spec:
docs/plans/2026-10-07-applicative-parser-design.md sections 4 and 7.

## Context

Every compiler phase (parse, resolve, check, coverage, Go emission) recurses
over the syntax tree, so deep nesting exhausted the JavaScript stack and the
CLI died with a raw `RangeError` (BACKLOG E002). G001 made the parser's
lists and operator chains loops, and its final review made coverage
stack-safe in pattern columns and inhabitation in chained types (BACKLOG
E002 lists the breadth figures and the cliffs that remain); depth remains
bounded by the stack.

## Options considered

1. **A nesting limit (chosen).** The parser counts nesting and reports
   `E_NESTING`, `Nesting exceeds <limit> levels`, at the token that would
   exceed the limit. Cheap, deterministic, and a structured diagnostic
   instead of a crash; it rejects programs that a larger stack would
   accept.
2. **A larger Node stack** (`--stack-size`). Raises every depth by the
   same factor but is not a guarantee: V8 can crash outright (segfault)
   when the requested size exceeds the thread's real stack, the result
   still ends in a raw overflow past the new bound, and it depends on how
   the compiler is launched.
3. **Heap-based phases** (explicit work stacks or trampolined traversal in
   every phase). Removes the bound entirely; a large rewrite of resolve,
   check, coverage and Go emission. Planned as follow-up work (spec
   section 4): BACKLOG H001, if a real program needs nesting beyond the
   limit. The narrower stack-safe operator chains of spec section 7 are
   BACKLOG O001.

## Decision

`nestingLimit = 128`, a named constant in Format.Parse.Grammar.

What counts as one level (Format.Parse.Grammar `nested`, `infixed`,
`chainLeft1`; bookkeeping in Format.Parse.Cursor): a parenthesized
expression, an `if` condition and each branch, a `match` scrutinee and each
arm body, each call or constructor argument, each constructor-pattern
field, and each `+` or comparison operand. Function bodies start at depth 0.
Only one root-to-leaf path counts; siblings do not add up.

Operators count the depth of the tree they build, not their position in the
source. `a + b + c` is `(a + b) + c`: each operator pushes everything parsed
since the enclosing nested position (its left operand) one level deeper,
and each right operand is nested. So a deep *left* operand counts in full:
`(if … 120 deep …) + 1 + … + 1` is rejected at the `+` that pushes it past
the limit. Counting only "the k-th `+` raises depth for the rest of the
chain" would accept it, and repeated parenthesized left operands would
then grow the tree without bound while every counted depth stayed small.
The state carries `depth` (the level being parsed) and `peak` (the deepest
level since the enclosing nested position), and the operator check is
`peak + 1 ≤ limit`. A flat chain of n operands counts n − 1, as before:
at the CLI a flat sum of 129 operands compiles and 130 is E_NESTING
(re-measured in Task 5). Lifting that for flat chains needs resolve, check
and Go emission to walk chains iteratively first (BACKLOG O001).

## Measurement

`node scripts/depth-probe.mjs` (cold `node scripts/bumpus.mjs emit` per run,
Node 26.6, default stack, macOS arm64) binary-searches the smallest
overflowing depth per form, with the limit disabled (constant temporarily
10⁹, not committed).

The probe cannot be re-run without editing source, by design: the limit is
a compile-time constant and no override is reachable from the CLI or from
user programs (G001 final review M4). To re-measure, in a scratch checkout:
set `nestingLimit = 1000000000` in src/Format/Parse/Grammar.purs (the line
`nestingLimit = 128`), run `npm run build`, then
`node scripts/depth-probe.mjs [form…]` (forms from scripts/depth-forms.mjs;
default all), then restore the line and rebuild. Never commit the edit;
test/depth.test.mjs fails while it is in place, since depth 129 no longer
reports E_NESTING. Every run is classified `overflow`, `diagnostic`,
`timeout` or `ok`; only `overflow` drives the search. Depth d is the
counted depth defined above (scripts/depth-forms.mjs).

| Form | Before Task 3 (13a70d6) | After Task 3, limit disabled |
|---|---|---|
| parens | 621 | 648 |
| if-condition | 759 | 679 |
| if-branch | 1,273 | 1,058 |
| match-scrutinee | 911 | 801 |
| match-arm | 783 | 783 |
| call-argument | 333 | 369 |
| constructor-argument (`Cons(1, `) | 314 | **304** |
| constructor-pattern | 436 | 373 |
| plus-chain | 2,949 | 2,928 |
| mixed: parenthesized `if` as left operand of a sum | 1,952 | 1,952 |
| mixed: parens in call arguments in constructor arguments | 411 | 432 |
| mixed: comparison of two deep matches | 765 | 765 |

No anomalies in the final run (every non-overflow outcome below the
overflow point was `ok`). One anomaly class was found and resolved: near
the boundary V8 may exhaust the stack while compiling a regular expression
(Data.Int.fromString) and print `SyntaxError: Invalid regular expression:
…: Stack overflow` instead of `RangeError`; the probe classifies it as an
overflow and test/depth.test.mjs rejects it too. Outcomes within a few
levels of the boundary vary between runs (depth 1,058 `if-branch` once
compiled, then overflowed), which the factor-of-two margin absorbs.

Frames per nesting level after G001 Task 2 (measured by the Task 2
review): parentheses 13, call or `Cons(` 24, `1 < (` 20, `if` 5. By
construction Task 3 adds one call per nested position (`nestedAt`; not
re-measured in frames) and saves the list loop's
frames for a first item (Grammar `foldAt` runs it directly and enters
`tailRecM` only after a separator), which is why parentheses and calls
gained capacity while `if` and `Cons(` (whose deep argument is the second)
lost some.

**Rule:** the largest power of two at most half the minimum overflow over
single and mixed forms: min 304, half 152, limit 128.

## Verification

test/depth.test.mjs, through the CLI, per form and mixed form: depth 128
compiles, builds and runs with the expected output; depth 129 exits 1 with
`E_NESTING`, the message and the exact span; no output contains
`RangeError`, `Stack overflow` or stack frames. A syntax error at depth 127
is still `E_SYNTAX`; siblings and later declarations do not add depth.
test/diagnostics.test.mjs gains the `E_NESTING` family row.

Every form, including match-arm and compare-matches, builds and runs at the
limit since E005 lowered each match to a named Go function (ADR 003 item
6); before that, nested match closures made `go build` exponential and
those two forms ran only at depth 16.

## Functions (FN001 Task 3, 2026-10-08)

Function syntax extends what counts, with the measure of the FN001 design
(docs/plans/2026-10-08-functions-design.md section 1); the limit is
unchanged. Tests: test/fn-syntax.test.mjs and test/fn-depth.test.mjs,
through Parse and Resolve.

- Types: an arrow's parameter side is one level deeper than the arrow, its
  result side is not, so `Int -> … -> Int` of any length is one level and
  `(Int -> Int) -> Int` two. An arrow chain is read by a loop (Grammar
  `chainRight`, Cursor `rightAt`): each item is measured from the chain's
  depth, and when `->` follows one, its peak plus one must be within the
  limit, else E_NESTING at that `->`. 128 nested parameter positions
  resolve; 129 are E_NESTING.
- A parenthesized type raises its contents' depth by one while they are
  parsed (Cursor `groupedAt`) and adds nothing to the measure passed
  outward, so parsing never recurses past the limit. One redundant pair
  at the limit is therefore E_NESTING: `L^127((Int -> Int))` and
  `L^128((Int))` are, while `L^127(Int -> Int)` and `L^128(Int)` are not
  (`L^k` is k nested type arguments; test/fn-depth.test.mjs). This is the
  only departure from the design's measure.
- Expressions: a lambda body is a nested position; `|>` operands count as
  `+` operands do (`chainLeft1`).
- Postfix application chains are flattened: `g(1)(2)(3)` is one
  `Apply (Call g [1]) [2, 3]` and `(h)(1)(2)` is `Apply h [1, 2]`, exact
  under design section 5 (`e(a1, …, aj)` is `e(a1)…(aj)`, with the same
  order and stage boundaries). The callee is one level deeper once for the
  whole chain (`infixed`) and each argument is nested as a call argument
  is; a name call `g(1)` counts as before. A chain of one level per group
  would make plan Task 8's chain of 1,000 partial applications E_NESTING,
  and lifting the limit would not help: every later phase would recurse
  once per group (the Task 3 review measured Resolve overflowing between
  3,500 and 3,546 nested Applys with the limit lifted). A 1,000-group chain
  resolves to one Apply (test/fn-syntax.test.mjs).

Task 3 measurements (the Task 3 review, limit lifted, before the chains
were flattened; smallest overflowing depth per form, cold CLI): 419,
1,682, 613, 613 and 613 for the review's five forms, in that order:
parenthesized nested lambdas, bare nested lambdas, nested parameter
types, type parentheses and annotation types, each above twice the limit.
scripts/depth-forms.mjs now has a form of each kind (`functionForms`,
whose exact shapes may differ from the review's). The forms emit Go only
from Task 6, which re-measures them with scripts/depth-probe.mjs (they
are measured only when named) and moves them into `forms` and
test/depth.test.mjs; until then test/fn-depth.test.mjs checks each at the
limit and one past it through Resolve.

## Functions emitted (FN001 Task 6, 2026-10-08)

Go now emits the five `functionForms`, so they joined `forms`
(scripts/depth-forms.mjs) and test/depth.test.mjs runs each through the
CLI at depth 128 (compiles, builds, runs) and 129 (E_NESTING);
test/fn-depth.test.mjs keeps its Resolve-level rows. Re-measured with
scripts/depth-probe.mjs in an isolated copy with the limit lifted (the
procedure above), after lowering, all forms; the old forms also on an
isolated build of 97740c6 (before Task 6), same machine and minute:

| Form | 97740c6 | Task 6 |
|---|---|---|
| lambda-bare | — | 1,507 |
| lambda-parens | — | 812 |
| parameter-types | — | 607 |
| type-parentheses | — | 607 |
| annotation-types | — | 343 |
| parens | 522 | 522 |
| if-condition | 674 | 679 |
| if-branch | 1,067 | 1,067 |
| match-scrutinee | 799 | 798 |
| match-arm | 775 | 775 |
| call-argument | 315 | 315 |
| constructor-argument | **274** | **276** |
| constructor-pattern | 371 | 372 |
| plus-chain | 1,564 | 1,564 |
| if-left-of-sum | 1,396 | 1,396 |
| parens-in-call-in-constructor | 363 | 363 |
| compare-matches | 759 | 759 |

No anomalies. The lowering changes no old form's capacity (differences
of up to 5 are run-to-run variation near the boundary); the decreases
since the G001 Task 3 table above (parens 648 → 522, call-argument
369 → 315, constructor-argument 304 → 274, plus-chain 2,928 → 1,564)
predate FN001 Task 6 (present at 97740c6; not attributed further here).
The margin over twice the limit (256) is now 18 levels. The smallest FN001
form is annotation-types, 343. Rule: min 276, half 138, limit 128,
unchanged.
