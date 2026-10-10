# BK001 review: docs/plans/2026-10-10-backend-syntax-proposal.md

Reviewer: adversarial design review, read-only (2026-10-10). Checked against
backend-requirements.md (verbatim user text), src/Format/Go.purs and
src/Format/Go/*.purs (HEAD 4dcf647; no src change since 2fc7a02),
scripts/structure.mjs, spago.yaml/spago.lock, scripts/regression*.mjs,
bootstrap/*.go, the Task 7/8 review ledgers, and `git log` for Format.Go.
`gofmt -l` / `gofmt -d` / `gofmt -e` were run read-only on bootstrap/*.go.

## Verification of factual claims

| Claim (proposal line) | Result |
|---|---|
| 22 modules, 2,814 lines (28) | Modules correct (Go.purs + 21). `wc -l` gives **2,766**, not 2,814. Largest-four counts correct. |
| 607 ` <> `, 28 `joinWith ", "`, 28 `joinWith ""`, 26 `"func ` (35-38) | Correct (607 occurrences on 458 lines). |
| IIFE sites, Expression.purs:90-96 (41) | Correct. |
| All five snapshots fail gofmt; all parse; diff 11-673 lines (50-52) | Correct: `gofmt -l` lists all five; changed lines 11 (answer) to 673 (lists); `gofmt -e` clean on all. |
| 18 commits, none fixing malformed syntax (76-77) | Correct (18 commits touch src/Format/Go*; fixes are planning, fallback, capture, stack, build-cost). |
| D1 review-task7-result.md:23-27, fixed 4b80bd1 (83) | Correct. |
| D2 key-0 fallbacks, Task 7 Minor (84) | Correct (review-task7-result.md:34). But see I5: Stage's `maybe ""` is not a *silent* fallback. |
| D3 3a3d197 removed `type …Arrow1` from functions.go (85) | Correct (diff removes `bumpusFn6Lambda0Arrow1`). |
| D5 payloadName, 5,000 arrows, d5bfa8d (87) | Correct (review-task8-result.md:176-188). |
| D7 unescaped names, Report.purs:48-51, Effect.purs:51-55 (89) | Lines correct. Effect.purs splices the **effect** name (`info.name`), not "operation names" (66). Latent only: Lex.purs:202-211 restricts names to ASCII letters/digits; Task 8 review already said "safe today" and asked for a one-line comment, which was never added. |
| D8 regression row scripts/regression.mjs:177 (90) | Correct. |
| dodo-printer 2.2.3 at spago.lock:145, prettier-printer 3.0.0 at :430, only in the package-set listing (160-162) | Correct; spago.yaml lists 11 core packages, `pedanticPackages: true`. |
| Allowlist at structure.mjs:18; `Dodo`/`Text.Pretty` fail the gate (163-166) | Correct (structure.mjs:42-43 rejects any non-allowlisted import in Domain/Features/Format). Also Data.List, which both libraries use in their APIs, is not allowlisted. |
| 12 Format.Go regression needles, 6 + 6 (378-381) | Correct (`file: 'src/Format/Go` count 6 in each script). |
| test/go-batch.mjs:37-48 regexes on one-line `main` (69, 368) | Correct. |
| Compare.purs:58-72 full parenthesization (96) | Correct for comparisons; see I2 for other operators. |
| FX005 (452) | Not a BACKLOG row; it lives only in effects-design.md:695 and CF001 design:631. Cite that. |

## Coverage (requirements, bullet by bullet)

| Requirement | | Where |
|---|---|---|
| Bounded, not implemented, no milestone expansion | ✅ | 3, 18-22, 449 |
| Review string assembly mixing layout with punctuation/signatures/loops/switches/calls | ✅ | 24-72 |
| Assess readability, correctness, future backend work | ✅ | 74-96, 392-430 |
| Separate planning from syntax construction and rendering | ✅ | 235-324, 441 |
| Compare helpers, pretty-printing documents, target AST | ✅ | 98-178 (plus A′) |
| Libraries only where compatible; no new runtime/tool boundary without benefit | ✅ | 160-178 |
| Before/after sketch on wrapper entry | ✅ with defects | 195-324 (I4, M3, M4) |
| What each prevents (formatting, malformed syntax, precedence, placement) | ✅ but overclaimed for A′ | 114-124 (I1-I3) |
| Distinguish from type correctness and semantic preservation | ✅ | 126-134 |
| Separate representations only where they prevent demonstrated mistakes | partial ❌ | 180-193: `Stmt`/`Expr`, `Decl`, `Name` are justified by counts and a performance defect (D6), not by a demonstrated mistake (I6) |
| Preserve evaluation order, determinism, naming, runtime contracts | ✅ | 326-341 |
| Fixed runtime as readable templates | ✅ | 342-347 |
| Incremental migration with existing tests/snapshots; document intentional output changes | ✅ | 349-390 (I7 on ordering) |
| Future: shared IR feeding separate backends | ✅ | 394-398 |
| Language-specific target ASTs, no universal tree | ✅ | 399-403 |
| Reusable pieces: document rendering, naming, source locations | ✅ | 404-419 |
| Where a lowered IR helps, without designing it | ✅ | 420-430 |
| Smallest useful abstraction from repeated patterns and actual risks | ✅ (questioned, I8) | 432-447 |
| Priority vs concurrency foundations and other work | ✅ (clarify, I7) | 449-458 |

## Critical

None. The proposal is accurate on almost every checked fact, the
recommendation is implementable, and no claim would cause emitted-Go
semantics to change.

## Important

**I1. Lines 119, 442-443: "malformed syntax: yes" and "D2, D7, D8 by type"
for (A′) are overclaimed.** Newtypes over rendered text prevent malformed
syntax only if (a) every builder that accepts a `String` validates or quotes
it, and (b) no `String → Expr/Type/Name` escape exists besides `raw`. The
sketch itself breaks (a): `Go.select (Go.ref names.node) "value"` (306-307)
takes an unchecked field `String`. And §7 step 7 (372-374) concedes that
unconverted producers keep `Lowered.code ∷ String` until the end, so during
steps 2-6 typed modules must wrap foreign `String` code as `Expr`, a second
escape the proposal never names (contradicting "the only raw escape", 345).
Go's composite-literal-in-header ambiguity (`if v == T{} {`, `switch T{}.f {`)
is a malformed-syntax class that opaque text cannot detect either.
Fix: in the table, change (A′)'s cell to "yes for builder-only values;
not through `raw`, `fromLowered` (transitional) or `String` field/identifier
arguments; not Go's composite-literal-in-header ambiguity". In §9 add:
"`Format.Go.Syntax` exports no constructor, no `Semigroup`/`Monoid`
instance (so `<>` cannot splice two `Expr`s) and no `Newtype` instance;
field and identifier arguments are `Name`; the transitional
`fromLowered ∷ String → Expr` is counted by a test and must reach zero at
step 7."

**I2. Line 120: "precedence mistakes: yes: `binary` always parenthesizes".**
Only binary operators are covered. Postfix builders (`select`, `index`,
`assert`, `call`) applied to a non-primary operand misparse silently: with
the proposed `pointer`/address builder, `Go.select (Go.address x) "f"`
renders `&x.f`, i.e. `&(x.f)`; a unary minus or `*p` operand of `index`
does the same. Opaque text cannot know whether its operand is primary, so
either the claim is wrong or byte identity breaks (parenthesizing every
operand changes output). Fix: make `Expr` carry its class, e.g.
`newtype Expr = Expr { text ∷ String, primary ∷ Boolean }`, with postfix
builders parenthesizing only non-primary operands (today's output never
has a non-primary postfix operand, so byte identity holds), and pin one
unit test per postfix builder. Or downgrade the cell to "binary operators
only".

**I3. Lines 121 and 186: "`iife` is the only bridge" from `Stmt` to `Expr`
is false as stated, so the rule is not enforceable as written.** Function
literals are `Expr`s containing statements: Stage's
`return func(x int32) int32 { return … }` (functions.go:180), Lambda,
Block.purs:84's cleanup closure `func() { _ = … }`, Report.purs:40-45,
Show.purs:22. Fix: "`funcLiteral ∷ Signature → Array Stmt → Expr` is the
only `Stmt → Expr` bridge; `iife` is `call (funcLiteral …) []` and is
counted separately (D6)". That rule is enforceable by the export list of
Format.Go.Syntax plus a test counting `iife` call sites, not by the type
system alone.

**I4. Lines 84, 266-267: the sketch keeps the D2 fallback it claims to
remove.** `storage kind ty = stored kind ty (lookupOr kind placed.accum)
(lookupOr ty nodes)` still returns 0 for a missing key and emits
plausible, compiling, wrong Go. A `Type`/`Expr` with no empty value does
not "force the caller to choose a guard explicitly" (84): `maybe 0`,
`maybe Go.anyType` or `lookupOr` remain available and are exactly the
pattern D2 named. The real guard is plan totality. Fix (84): "Partly:
a `Type` with no empty value removes only the empty-text case; silent
defaults are removed by building plans totally (zip over the
parameters instead of `Array.index`; `kinds` and `counts` computed by one
`mapAccumL` so every looked-up key is present by construction)". Fix in
§5.2: compute `node` per distinct type in the same pass that numbers
nodes, or document `lookupOr` as a retained compiler-bug path and say why.

**I5. Lines 63-64, 84: Stage's `maybe ""` is not the silent class.**
`parameter` yielding `x ` (empty type) and `node` yielding `&{x, e}` are
both Go syntax errors, so `go build` rejects them loudly. The silent ones
(plausible, compiling, wrong Go) are Stage.purs:194 `numberOf` → 0 and
Entry.purs:106-107 `lookupOr` → 0, which pick a real but wrong node type
or kind. Re-rank D2 accordingly (and in the BACKLOG row, 462, cite
Stage.purs:194 and Entry.purs:106 rather than "`maybe ""` fallbacks").

**I6. Lines 180-193: three representations are not justified by a
demonstrated mistake, as the requirement asks.** `Stmt`≠`Expr` cites
"5 IIFE sites" and D6, which is a `go build` cost defect, not a placement
mistake; `Decl` cites per-site separators (no defect); `Name` is "cheap"
(no defect). Either mark them "justified by risk, not by a demonstrated
mistake" in the table's first column, or move them to "later" and keep
the demonstrated set (plans, `Signature`/callee, quoted literals, `Type`
without empty value). This also feeds I8.

**I7. Lines 449-458 and 360-374: priority and ordering are ambiguous.**
Step 6 is said to land before CF001/FX005/G003 lowering, but numbered
steps 2-5 precede it, which would put the whole migration in front of
concurrency implementation. Step 6 depends only on steps 0-1. Fix: "Steps
0, 1 and 6 (effect mode) are the prerequisite for CF001/FX005 lowering
implementation; steps 2-5 and 7 are unordered and may follow." Also D8's
fix as sketched does not actually tie calls to signatures: `Go.callIn
plan.context (Go.ref names.wrapper)` (295) passes a separate Boolean, the
same convention as today's `passed context`. To earn "D8 by type" (442),
calls must be built from the callee's declaration: e.g. `Go.callee ∷
Signature → Callee` and `Go.call ∷ Callee → Array Expr → Expr`, so the
ctx argument is inserted from the callee's own flag.

**I8. Lines 105-108, 434-447: the smallest useful abstraction may be
smaller.** Every demonstrated defect class the proposal ranks highest
(D1, D3 by plans; D2 by total plans; D7 by one quoting function; D8 by a
shared `Signature`/`Callee` record) is addressed without newtype-wrapped
`Expr`/`Stmt`/`Decl`; the newtypes add ~250 lines, change `Lowered`'s
interface, and need I1-I3 to deliver their stated guarantees. Fix: state
the recommendation as two tiers: tier 1 (required) = plan records,
`Signature`/`Callee`, `quoted`, total plans, applied with (A)-style
helpers; tier 2 (optional, judged after step 2) = the (A′) newtypes, kept
only if the Entry step shows a readability gain worth the interface
churn. This keeps the recommendation honest to "smallest useful".

**I9. Lines 317-322: byte identity relies on layout variants the renderer
rules do not define.** The rules given describe only the multi-line form.
Today's output also has one-line bodies (`func X(e any) T { return … }`,
functions.go:180, 201; the `if` IIFE `{ if c { return a }; return b }`;
`func main() { … }` pinned by go-batch.mjs) and runtime blocks with tab
indentation. Fix: add to §5.2/§9 "each block-taking builder has an
explicit layout: `Lines` (statement per line, no indentation, `}\n`) or
`Inline` (`{ s1; s2 }`); step 1 pins both forms per builder", so (A′) is
not quietly a layout engine.

## Minor

- **M1 (28):** "2,814 lines" → "2,766 lines".
- **M2 (66):** "operation names are spliced" → "the effect name
  (`info.name`) is spliced".
- **M3 (302, 439):** `case`, `if` and `type` are PureScript keywords;
  `Go.case`, `Go.if` and a `type` declaration builder cannot be defined.
  Rename (e.g. `Go.caseOf`, `Go.ifThen`, `Go.typeDecl`) in the sketch and
  the builder list.
- **M4 (299 vs 187, 438):** `Go.int32` is used as a Type in the sketch and
  listed as the `int32(n)` literal builder in §9. Use `Go.int32Type` (or
  `Go.int32T`) and `Go.int32` for the literal.
- **M5 (273, 306-307):** "the only literals are Go's own" — `"value"` and
  `"previous"` are the node struct's field names, a runtime contract
  declared in Stage. Take them from the same `Name`s Stage uses to declare
  the node struct.
- **M6 (§9, D7):** say that `Go.string` must implement Go's escaping and
  must not use PureScript `show`, which emits decimal escapes such as
  `\127` (prelude Show.js `showStringImpl`) that Go rejects.
- **M7 (240):** the plan record carries Go identifiers (`wrapper`); say
  "no Go syntax" rather than "no Go text", or carry the IR id and derive
  the name in `entryNames`.
- **M8 (452):** FX005 is not a BACKLOG row; cite effects-design.md:695 /
  CF001 design:631.
- **M9 (153-159):** stack-safety section is correct (eager rendering adds
  no recursion; plans keep `mapAccumL`, which Lowered.purs:179 notes is
  balanced). Add one sentence: "builders take `Array`s, Syntax defines no
  `List`, and multi-element output uses `joinWith`; step 2 adds a
  20,000-parameter Entry test through the builders."

## Should any finding be fixed sooner than BK001?

No as defects; one cheap action now.
- D7 is unreachable: Lex.purs:202-211 limits names to ASCII letters and
  digits, and the Task 8 review classed it "safe today". Its requested
  one-line comment at Report.purs `described` (and Effect.purs:51-55) was
  never added; add it in the next commit touching either file. No code fix
  before BK001.
- Stage's `maybe ""` fails `go build` loudly (I5); not urgent.
- The silent ones, `numberOf` → 0 (Stage.purs:194) and `lookupOr` → 0
  (Entry.purs:106-107), are compiler-bug-only paths of the same class the
  Task 7 review fixed in Handle/Lowered. They are unreachable from valid
  input today, so they need not pre-empt FX001; but any change to Stage or
  Entry before BK001 (e.g. FX005 or CF001 lowering) should make them total
  then, not wait for step 3.

## Verdict

**Accept with fixes** (I1-I9; Minors at the controller's discretion). The
survey, defect evidence, library and gofmt findings, future-target section
and preservation rules are accurate; the before/after sketch would produce
byte-identical Entry output given the stated renderer rules. The
guarantees claimed for (A′) (malformed syntax, precedence, statement
placement, D2/D8 "by type") are stronger than newtypes over rendered text
deliver, and the priority needs the 0/1/6 ordering stated explicitly.
