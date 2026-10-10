# Go backend syntax: a bounded maintainability proposal (BK001)

Status: Proposed (BK001); not authorized; pending user review. Revised
2026-10-10 after an adversarial review (.superpowers/sdd/2026-10-09-
effects-plan/review-bk001-result.md; responses at the end).

Requirements (binding): .superpowers/sdd/2026-10-09-effects-plan/
backend-requirements.md. Ground truth: src/Format/Go*.purs at 2fc7a02
(unchanged at 4dcf647), git history, docs/progress.md, SDD review ledgers,
BACKLOG.md, scripts/structure.mjs, spago files and the tests named below.

## 1. Scope and non-goals

In scope: how Format.Go builds Go text, a representation that makes it
more readable and harder to get wrong, a byte-identical migration, and
what carries over to future targets. Non-goals: no implementation now;
FX001 (Tasks 9-12) unchanged; no change to emitted Go semantics, naming,
runtime contracts or modes; no new runtime, tool boundary or build-time Go
tool; no design of L001 or of any other target.

## 2. Survey of Format.Go

### 2.1 Size and shape

22 modules, 2,766 lines (largest Lowered 206, Stage 197, Handle 178,
Context 175). Every module builds `String`s directly; `Lowered.code ∷
String` and `lifted ∷ Array String` (Lowered.purs) carry Go text between
modules. Counts over Go.purs and Go/*.purs (grep, 2fc7a02):

| Shape | Occurrences (files) | Notes |
|---|---|---|
| ` <> ` concatenation | 607 (20) | densest: Handle 82, Compare 70, Effect 53, Stage 50, Match 49, Data 49, Entry 46 |
| `joinWith ", "` comma lists | 28 (13) | parameters, arguments, composite literals |
| `joinWith ""` statement/decl concatenation | 28 (12) | |
| `"func ` signatures | 26 (13) | each spells `(`, params, `) `, result, ` {\n` |
| ctx threading helpers | `parameterList` 11, `passed` 10, `contextParameter` 7 | plus 6 literal `"ctx"` in Handle and Effect |
| `{\n` / `\n}` block delimiters | 21 / 15 | open and close in different expressions |
| IIFE `func() T { … }()` | 5 sites (4) | `if` (Expression.purs:90-96), print, Show Unit, malformed key, Cleanup template |
| other function literals | Stage, Lambda, Block.purs:84, Report.purs:40-45, Show.purs:22 | statements inside an expression |
| `panic(` | 8 (4) | unmatched, malformed, runtime templates |
| `switch` / `case` | 4 / 3 | Entry, Handle, Show, Compare |
| `_ = name` (Go's unused-variable rule) | 3 modules | Match.purs:106-107, Block.purs:82-92, Handle.purs:149-158 |

Layouts in use: multi-line bodies with no indentation (`{\n` stmt `\n`
… `}\n`), one-line bodies (`func main() { … }`, `{ return x }`, `{ if c
{ return a }; return b }`), and tab-indented runtime templates. None of the
five snapshots is gofmt-clean (`gofmt -l bootstrap/*.go` lists all five;
`gofmt -d` differs on 11-673 lines each); all parse (`gofmt -e`).

### 2.2 Where planning and punctuation interleave

- Entry.purs:34-61: kind/slot layout (`mapAccumL place`, `Array.nub`,
  maps) is computed in the same `where` that spells the loop, switch and
  call; the loop bound `show (length - 1)` is inline punctuation.
- Handle.purs:105-158: the frame nesting order (`frames`, a `foldl` that
  builds `waxwingFrame(…)` text) is the semantic decision of which clause
  is innermost, made inside string assembly.
- Stage.purs:53-90, 129-194: node numbering and which stage types are
  interned, own or spelled inline are decided while emitting declarations;
  lookups fall back to `""` (`parameter`, `node`) or `0` (`numberOf`).
- Effect.purs:45-63: `parameterList true` hard-codes ctx mode; the body
  reads the literal `ctx`; the effect name (`info.name`) is spliced into a
  Go string literal unescaped.
- Go.purs:72-88 (`entryMain`) fixes a one-line `func main() { … }` that
  test/go-batch.mjs:37-48 matches by regular expression.

Pure modules with no Go text (Usage, Layout, Capture) already plan
while others print.

### 2.3 Demonstrated defects and latent risks

None of the 18 commits touching src/Format/Go* fixes malformed Go syntax:
`go build` in the tests catches syntax errors before review. The recorded
defects are planning errors, silent fallbacks, unescaped text and stack
depth:

| # | Defect (evidence) | Class | What would have prevented it |
|---|---|---|---|
| D1 | Clauses of one `handle` installed in reverse; a well-typed program panicked (Task 7 review Critical, review-task7-result.md:23-27; fixed 4b80bd1, Handle.purs:136-147) | planning interleaved with text | A separate frame plan (innermost-first array), unit-tested without Go. No syntax type helps |
| D2 | Silent key-0 fallbacks emitted compiling, wrong Go (`handlerKey _ → EffectKey 0`, `effectShape` default; Task 7 review Minor, review-task7-result.md:34; fixed 4b80bd1). Same class still present: Stage.purs:194 `numberOf` → 0 and Entry.purs:106-107 `lookupOr` → 0 pick a real but wrong node type or kind (compiler-bug paths, unreachable from valid input today) | silent default in a lookup | Total plans: numbering and lookup in one pass, so every key is present by construction (§5.2). A `Type` with no empty value does not help: `maybe 0` stays available |
| D2′ | Stage.purs:184-194 `maybe ""` would emit `x ` (empty type) or `&{x, e}` | loud fallback | Already caught by `go build`; lowest rank. Total plans remove it too |
| D3 | Stage declared an unused own arrow type (FN001 Task 6 review; fixed 3a3d197, bootstrap/functions.go lost `type …Arrow1`) | name planning inside declaration emission | A stage-type plan that lists uses makes an unused declaration a testable fact |
| D4 | Capture loss: mutants give Go `undefined: bumpusLocal3` (E005, progress.md:540-568; 09f3071, c928d93) | scope planning | The free-set computation (Capture) and its tests. A Go AST could add a test-only bound-name check; builders cannot |
| D5 | `payloadName` recursed along arrow spines; 5,000 arrows overflowed the JS stack (Task 8 review Important 2; fixed d5bfa8d) | stack depth in emission | Nothing representational; any new traversal must obey the same rule (§3.4) |
| D6 | Nested IIFEs made `go build` exponential (E005); one long expression builds superlinearly (G003, findings.md:310-326) | build cost of emitted shape | Not prevented; an `iife` builder makes the sites countable |
| D7 | Type names (Report.purs:48-51) and the effect name (Effect.purs:51-55) spliced into Go string literals unescaped (Task 8 review Minor) | literal quoting | One Go-correct quoting function. Latent: Lex.purs:202-211 limits names to ASCII letters, digits and `_`, so unreachable today; the comment the review asked for was never added |
| D8 | ctx threading by convention: signatures (`declared`, `parameterList`, `contextParameter`, literal `ctx`) and calls (`passed`, `"ctx"`) agree only by review; no mismatch recorded; the `effect-free-ctx` row (scripts/regression.mjs:177) guards mode selection, a different check | declaration/call agreement (forward risk) | Calls built from the callee's own `Signature` (§3.1), by call kind |

Risk ranking (likelihood × cost of a silent miss): D2 highest (every new
lowering adds lookups), D8 next as forward risk (no mismatch recorded,
but the planned FX005 and FX002 change ctx threading), then D1/D3-style planning errors in
Handle and Stage, then D7 (latent), then D2′, syntax and precedence (none
observed; comparisons are fully parenthesized, Compare.purs:58-72).

## 3. Options

### 3.1 The options

- (A) Rendering helpers over `String`: `call`, `commaList`, `block`,
  `funcDecl`, `switchOn`, `quoted`. Removes repeated punctuation; types
  remain `String`.
- (A+) Tier 1 of the recommendation: (A) plus the three things the
  defects ask for: Go-free plan records built totally; a `Signature`
  record and a `Callee` derived from it, so calls get ctx from the
  callee's declaration (`callee ∷ Signature → Callee` for declared
  functions, constructors, lifted helpers and stages; `valueCallee ∷
  String → Callee` for a function value, ctx from the program's
  function-type mode; `call ∷ Context → Callee → Array String → String`,
  where `Context` is `Threaded` (passes `ctx`) or `Root` (passes `nil`,
  for `main`); a callee whose `Signature.context` is false (later stages,
  runtime helpers) gets none); and one Go-correct `quoted`. Calls into
  and out of `raw` runtime templates (`waxwingFind`, `waxwingInstall`,
  `waxwingFail`, the frame fold, runtime-invoked handler clauses) stay
  spelled in the template or at their one call site. For agreement to come
  from the declaration, the `Signature` built where a function,
  constructor or lifted helper is declared must reach its callers, so
  `Wrapper` (Lowered.purs:73) or `Shape` gains it.
- (A′) Tier 2: the (A+) helpers over opaque newtypes `Name`, `Type`,
  `Expr`, `Stmt`, `Decl` holding already-rendered text. Text is still
  produced eagerly, so no second traversal exists.
- (B) A Wadler/Leijen document (`Doc` with `text`, `line`, `nest`,
  `group`) rendered at a width; from a library or in-repo.
- (C) A small Go AST for the generated subset (`Expr`, `Stmt`, `Decl`,
  `Type` as ADTs) and one renderer.

What (A′) can guarantee depends on its export list, which this proposal
fixes: Format.Go.Syntax exports no data constructor, no `Semigroup`/
`Monoid` instance (so `<>` cannot splice two `Expr`s) and no `Newtype`
instance; identifier and field arguments are `Name`s, never `String`s.
Its escapes are named and counted: `raw ∷ String → Decl` for fixed
runtime templates, and the transitional `fromLowered ∷ String → Expr`
for code from modules not yet migrated (`Lowered.code`), which a test
counts and which must reach zero at migration step 7. `Expr` carries its
class, `newtype Expr = Expr { text ∷ String, primary ∷ Boolean }`:
postfix builders (`call`, `select`, `index`, `assert`) parenthesize a
non-primary operand (today's output has none, so byte identity holds),
and `binary` always parenthesizes, as Compare does today. Function
literals, composite literals, conversions, calls, selectors and
parenthesized binaries are primary (Go `Operand`/`PrimaryExpr`), so
`func() T { … }()` (Expression.purs:92-96) gains no parentheses;
`&T{…}`, `*p` and unary `-` are not.
`funcLiteral ∷ Signature → Layout → Array Stmt → Expr` is the only
`Stmt → Expr` bridge; `iife` is `call` of a `funcLiteral` with no
arguments, and its call sites are counted separately (D6).

### 3.2 What each prevents

| Prevents | (A)/(A+) | (A′) | (B) | (C) |
|---|---|---|---|---|
| Formatting errors (separators, newlines, spacing) | at helper sites | yes, at builder sites | yes (its purpose) | yes |
| Malformed syntax (unbalanced braces, empty type, missing parentheses) | partly | yes for builder-only values; not through `raw`, `fromLowered` or text inside a `Name`; not Go's composite-literal-in-header ambiguity (`if v == T{} {`) | no: a Doc is text | yes, if the renderer handles the header ambiguity |
| Precedence mistakes | no | yes with the `primary` tag (binary and postfix) | no | yes (rule or table) |
| Invalid statement placement | no | yes, by the export list: `Stmt` reaches an `Expr` only through `funcLiteral` | no | yes |
| Unquoted literals (D7) | (A+) yes, if used | yes | no | yes |
| ctx mismatch (D8) | (A+) yes, through `Callee` | yes, through `Callee` | no | yes, with a `Callee` |
| Silent defaults (D2) | (A+) total plans | total plans, not the types | no | no |
| Planning errors (D1, D3, D4) | (A+) plans make them testable | same | no | same |

None of them establishes Go type correctness (int vs int32, interface
assertions: D1 was well-typed Go that failed an assertion at run time),
Go's unused-variable and undefined-name rules, or semantic preservation
(evaluation order, frame order, cleanup order). Those need `go build`
(test/go-batch.mjs), executable tests with exact stdout (fx-run 24
programs, fn-run 22, adt-*), the reference interpreter and differential
(scripts/differential.mjs; FX001 Task 10), and regression mutants. (C)
alone could add Go-level checks (bound names, unused locals) as test
oracles; that duplicates `go build`.

### 3.3 Cost and migration risk

| | (A+) | (A′) on top | (B) | (C) |
|---|---|---|---|---|
| New code | ~120 lines | +~200 lines in 2 modules | library: none; in-repo ~200 | ~200 types + ~250 renderer |
| Byte-identical migration | easy | easy: renders the same strings | hard: layout decided by the renderer; every one-line form needs explicit `group`/`flatten` | moderate: both layouts reproduced |
| Stack profile | unchanged | unchanged | new: deep `Cat` chains | one more bounded-depth traversal |
| Interface churn | `Wrapper`/`Shape` gains `Signature` | `Lowered.code`, `lifted` change type | low | `Lowered` changes type |

### 3.4 Fit with project constraints

- Purity and layers: all live in Format (pure). Syntax modules import
  nothing from Domain.IR.Internal; `goType` stays in Format.Go.Data.
- 250-line files, 30-line declarations, `where`, no lambdas: builders are
  one-line functions; (C)'s renderer would be an E003-style flat dispatch.
  Builder names avoid PureScript keywords (`caseOf`, `ifThen`,
  `typeDecl`, `varDecl`).
- Stack safety (20,000-arrow spines, 20,000 `let`s or parameters):
  builders take `Array`s (no `List`), join with `joinWith`, and plans keep
  `mapAccumL` (balanced, Lowered.purs:179); nesting is bounded by
  E_NESTING. (A+)/(A′) render eagerly and add no recursion; step 2 adds a
  20,000-parameter Entry test. (B) risks 20,000-deep `Cat` chains unless
  its renderer runs an explicit stack.
- Libraries: dodo-printer 2.2.3 (spago.lock:145) and prettier-printer
  3.0.0 (:430) are only in the registry 81.0.0 package-set listing, not
  resolved. The pure-layer allowlist (scripts/structure.mjs:18, enforced
  at 42-43) rejects `Dodo`, `Text.Pretty` and the `Data.List` their APIs
  use, so adoption widens an enforced rule and adds unchecked transitive
  dependencies, for no width-based layout we need. Verdict: no library;
  an in-repo (B) only if gofmt-like layout is ever wanted.
- gofmt: at compile time it adds a Go-toolchain boundary for nothing
  `go build` does not check; rejected. Test-only `gofmt -l` fails on all
  five snapshots today and helps only after an intentional gofmt-clean
  output change (not proposed); `gofmt -e` duplicates `go build`.

## 4. Which separate representations are justified

| Representation | Basis | Tier |
|---|---|---|
| Go-free plan records per generator, built totally | demonstrated: D1, D2, D3 | 1 |
| `Signature { name, context, parameters, result }` and `Callee` from it | risk: no recorded signature/call mismatch (`effect-free-ctx` is mode selection, not agreement); justified by the ctx changes FX005 and FX002 will make (CF001 §10 items 4, 6; changes 5-6) | 1 (if forward risk is accepted) |
| Go-correct `quoted` string literal | demonstrated (latent): D7 | 1 |
| Named layouts `Lines` / `Inline` for block-taking helpers | needed for byte identity (§5.3) | 1 |
| `Type` with no empty value | loud failure only (D2′); risk, not a silent mistake | 2 |
| `Stmt` distinct from `Expr`, `funcLiteral` the only bridge | risk: no placement mistake recorded; D6 is a build-cost defect | 2 |
| `Expr` with `primary` tag | risk: no precedence mistake recorded | 2 |
| `Name` newtype from Format.Go.Data's naming functions | risk: keeps generated naming in one module | 2 |
| `Decl` with fixed separators | convenience: separators are spelled per site | 2 |
| Inspectable Go AST (C) | no consumer; revisit if L001 or a Go-level pass must read Go back | later |
| Doc layout engine (B) | no width-based layout | no |

## 5. Representative example: the wrapper entry

### 5.1 Before (src/Format/Go/Entry.purs:34-61, at 2fc7a02)

```purescript
entry context nodes wrapper =
  table wrapper.name "Kinds" (map kindOf placed.value)
    <> table wrapper.name "Slots" (map slotOf placed.value)
    <> "\nfunc "
    <> wrapper.name
    <> "Entry("
    <> parameterList context [ "e any" ]
    <> ") "
    <> goType wrapper.result
    <> " {\n"
    <> joinWith "" (Array.mapWithIndex (array placed.accum) distinct)
    <> "for p := "
    <> show (Array.length wrapper.parameters - 1)
    <> "; p >= 0; p-- {\nswitch "
    <> wrapper.name
    <> "Kinds[p] {\n"
    <> joinWith "" (Array.mapWithIndex (unpack nodes wrapper.name) distinct)
    <> "}\n}\nreturn "
    <> wrapper.name
    <> "("
    <> joinWith ", " (passed context (map argument placed.value))
    <> ")\n}\n"
  where
  distinct = Array.nub wrapper.parameters
  kinds = Map.fromFoldable (Array.mapWithIndex numbered distinct)
  numbered index ty = Tuple ty index
  placed = mapAccumL (place kinds) Map.empty wrapper.parameters
```

Layout (which arrays, kinds and slots), names (`a<k>`, `p`, `e`, `v`),
ctx threading and punctuation are one expression; `unpack` (lines 92-99)
spells a whole `case` with four embedded newlines, and both `array` and
`unpack` read maps through `lookupOr`, which defaults to 0 (D2).

### 5.2 After (sketch; proposed, not compiled)

Planning: no Go syntax (the record carries identifiers, not code), total,
unit-testable. Stage numbers node types in one `mapAccumL` over all
wrappers' parameters, where an unseen type gets the next number (so no
lookup can miss), and hands each wrapper its parameters as `{ ty, node }`;
Entry then needs no node map. Kinds, slots and counts come from one pass:

```purescript
type Parameter = { ty ∷ Ty, node ∷ Int } -- node numbered by Stage
type Storage = { kind ∷ Int, count ∷ Int, ty ∷ Ty, node ∷ Int }
type Placed = { kind ∷ Int, slot ∷ Int }
type Kinds = Map Ty Storage -- per distinct type, so far

type EntryPlan =
  { wrapper ∷ Callee -- the wrapped function, from its own Signature
  , result ∷ Ty
  , placed ∷ Array Placed -- per position
  , arrays ∷ Array Storage -- per distinct type, in kind order
  }

entryPlan ∷ Callee → Ty → Array Parameter → EntryPlan
entryPlan wrapper result parameters =
  { wrapper, result, placed: walked.value, arrays }
  where
  walked = mapAccumL place Map.empty parameters
  arrays = Array.sortWith kindOf (Map.values' walked.accum)
  kindOf storage = storage.kind

-- Total: a type not yet seen opens the next kind; no default value.
place ∷ Kinds → Parameter → { accum ∷ Kinds, value ∷ Placed }
place seen parameter = maybe' opened extended (Map.lookup parameter.ty seen)
  where
  opened _ = stored (fresh (Map.size seen))
  fresh kind = { kind, count: 0, ty: parameter.ty, node: parameter.node }
  extended storage = stored storage
  stored storage =
    { accum: Map.insert parameter.ty (storage { count = storage.count + 1 })
        seen
    , value: { kind: storage.kind, slot: storage.count }
    }
```

(`Map.values'` stands for `Map.toUnfoldable` to an `Array` and `snd`;
`Data.List` stays out of the pure layers.)

Syntax construction (shown in Tier 2 form; under Tier 1 the same helpers
take and return `String`). Names, including the node struct's fields
`value` and `previous`, come from the functions Stage declares them with:

```purescript
entryDeclarations ∷ EntryPlan → Array Decl
entryDeclarations plan =
  [ table names.kinds (map placedKind plan.placed)
  , table names.slots (map placedSlot plan.placed)
  , Go.function Go.Lines signature
      (map (storageVar names) plan.arrays <> [ walk, Go.return final ])
  ]
  where
  names = entryNames (Go.calleeName plan.wrapper)
  signature = entrySignature plan names
  walk = Go.countDown Go.Lines names.position (Array.length plan.placed - 1)
    [ Go.switchOn Go.Lines (Go.index (Go.ref names.kinds) (Go.ref names.position))
        (map (unpack names) plan.arrays)
    ]
  final = Go.call Go.Threaded plan.wrapper (map (argument names) plan.placed)

table ∷ Name → Array Int → Decl
table name values =
  Go.varDecl name (Go.arrayLiteral Go.int32Type (map Go.int values))

unpack ∷ EntryNames → Storage → Go.Case
unpack names storage = Go.caseOf Go.Lines (Go.int storage.kind)
  [ Go.define names.node
      (Go.assert (Go.ref names.chain) (Go.pointer (nodeType storage.node)))
  , Go.assign (Go.index (Go.ref (slotArray storage.kind)) slot)
      (Go.select (Go.ref names.node) nodeValue)
  , Go.assign (Go.ref names.chain) (Go.select (Go.ref names.node) nodePrevious)
  ]
  where
  slot = Go.index (Go.ref names.slots) (Go.ref names.position)
```

`entrySignature` builds `{ name: names.entry, context: <the wrapper
callee's context>, parameters: [ chain any ], result }`; `Go.call
Go.Threaded` passes `ctx` exactly when the callee's own `Signature` has
it, so the entry and the wrapped function cannot disagree (D8).
`arrayLiteral` renders a sized `[n]T{…}`, n the element count. `nodeValue`/`nodePrevious` are the `Name`s Stage's
`nodeType` declares. `storageVar`, `argument`, `placedKind`, `placedSlot`,
`entryNames` and `slotArray` are one-line helpers.

Rendering: `entry wrapper result parameters = Go.declarations
(entryDeclarations (entryPlan wrapper result parameters))`. Expected
difference in emitted Go: none (bootstrap/functions.go holds three entries
and must stay byte-identical; node numbers are first-appearance order in
both versions).

### 5.3 Layouts

Every block-taking helper (`function`, `funcLiteral`, `ifThen`,
`switchOn`/`caseOf`, `countDown`) takes an explicit layout, so the
helpers do not become a layout engine:

| Layout | Rendering | Current uses |
|---|---|---|
| `Lines` | header ` {\n`, each statement then `\n`, no indentation, `}`; the separator around a top-level declaration is a parameter of `declarations` (Entry and Stage: `\n` before and after; functions and lifted helpers: `\n` between, as Go.purs:52 and :125 do today), pinned per call site in step 1 | function bodies, Entry, Handle, Match, Block |
| `Inline` | header `{ `, statements joined by `; `, ` }` | `func X(e any) T { return … }` (functions.go:180, 201), the `if` IIFE `{ if c { return a }; return b }`, `func main() { … }` (pinned by go-batch.mjs:37-48), one-line arms `if c { return x }` |

`case k:` is followed by its statements in `Lines` form. Tab-indented
runtime text is not produced by helpers; it stays in `raw` templates
(§6). Step 1 pins both layouts for every block-taking helper.

## 6. Preservation

- Evaluation order: helpers never reorder; order-encoding constructs stay
  explicit (Apply's argument blocks, the pipe temporary, the lifted match
  scrutinee, the `if` IIFE, `defer` registration). Determinism: no map is
  iterated while rendering. Naming: spellings stay in Format.Go.Data and
  the pre-order counter in Lowered.
- Runtime contracts: ctx first in every signature whose
  `Signature.context` is true (functions, constructors, lifted helpers,
  first stages, stage closures, entries; not later stages `(e any)`) and
  in every call of such a callee; `main` passes `nil`; calls into and out
  of `raw` runtime templates stay spelled in the template. Handler/marker/
  frame layout, cleanup LIFO and the defect report text are unchanged; ctx mode selection
  (Context.usesContext) is planning and does not move.
- Fixed runtime support stays readable templates: Context.runtime
  (Context.purs:108-175), Cleanup.cleanupRuntime, the fixed parts of the
  Compare/Show helpers, `waxwingAdd`, the import block. Each becomes one
  `raw` declaration, reviewed like data. Parameterized generators (per-type
  Compare/Show helpers, Effect structs and perform functions, Handle,
  Stage, Entry, Match, Block) migrate.
- Quoting: `quoted` implements Go's interpreted-string escaping: `\"`,
  `\\`, `\n`, `\r`, `\t`; other code points below U+0020 and U+007F as
  `\xNN` (a single byte, equal to the code point only below U+0080);
  every other code point emitted as itself (Go source is UTF-8) or as
  `\uXXXX` / `\UXXXXXXXX` (eight digits above U+FFFF), never `\xNN`;
  `'` is not escaped (`\'` is invalid in Go strings). It decodes UTF-16
  surrogate pairs first; a lone surrogate has no Go escape and cannot
  arise from Lex-restricted names (Lex.purs:202-211). It must not use
  PureScript `show`, whose decimal escapes (`\127`, prelude
  `showStringImpl`) Go rejects. Until step 6, the comment
  the Task 8 review asked for goes on Report `described` and Effect
  `perform` in the next commit that touches either file.

## 7. Incremental migration

Each step: one or two modules, no file over 250 lines, `npm run verify`
green, emitted Go byte-identical, regression proofs 100%.

0. Baseline for effect-mode output, which no byte snapshot covers
   (bootstrap/ holds answer, functions, lists, shapes, tree): a scratch
   corpus comparison (emit before/after over examples/ and the fx-run,
   fx-cleanup, fn-run and adt programs, `cmp`), as E005 did on 21
   programs (progress.md:563); or, with user approval, a new snapshot of
   one effect example (an intentional addition, not an output change).
1. Tier 1 helpers: `Signature`/`Callee`, `quoted`, the comma/call/block
   helpers with both layouts, and unit tests pinning each helper's text,
   quoting included.
2. Entry and Stage's node numbering (§5): total plans; stages generated
   by iterating the `Parameter` array (`mapWithIndex`, with the next
   element zipped), not `Array.index`, so `numberOf`, `parameter` and
   `node` lose their defaults (D2, D2′); functions.go. Afterwards decide
   Tier 2 (§9).
3. Stage's remaining parts, Lambda, Value, Apply, Pipe: functions.go;
   `Wrapper` gains each callee's `Signature`.
4. Match, Data, Compare, Show: shapes.go, tree.go, lists.go.
5. Go.purs (`function`, `entryMain`, `imports`), keeping the one-line
   `main` go-batch.mjs matches.
6. Effect mode: Context's signature helpers become `Signature`/`Callee`;
   Handle (frame plan first, D1), Effect (quoted effect name, D7), Block,
   Report, Cleanup's generated parts.
7. Tier 2 only: `Lowered.code`/`lifted` become `Expr`/`Array Decl`;
   `fromLowered` count reaches zero.

Ordering: steps 0, 1 and 6 are the prerequisite for FX005 and FX002
lowering (FX002 implements CF001; FX005 precedes FX002, CF001
design:631-632); 6 depends only on 0-1. Steps 2-5 and 7 are
unordered and may follow. Independently of BK001, any earlier change to
Stage or Entry (for example FX005 or FX002 lowering) should make
`numberOf`/`lookupOr` total then rather than wait.

Costs to plan for:

- Regression rows needling Format.Go text: 12 (scripts/regression.mjs:
  nil-guard, ctor-order, first-field, show-fields, capture,
  effect-free-ctx; scripts/regression-fn.mjs: stage-value, stage-lambda,
  partial-strict, pipe-order, lambda-capture, block-order). Six quote or
  inject Go text (nil-guard, ctor-order, block-order, and the three
  `eta`-built replacements) and must be rewritten against the helpers;
  each re-targeted row is shown failing with its defect restored, per
  AGENTS.md. The others move only if their line moves.
- Tests pinning emitted text (12 files, e.g. test/match-lift) stay valid
  while output is byte-identical; an intentional output change (none
  proposed) is its own commit with snapshots, a progress entry and reason.

## 8. Future targets

- Shape: one shared compiler IR feeding separate backends: today the
  monomorphic IR (Domain.IR.Internal, visible to Format.Go* only,
  scripts/structure.mjs:23-26), later the L001 lowered IR after
  specialization and above target layouts (language-direction.md
  "Intermediate representations and future targets"). Each backend owns a
  language-specific syntax: Go (this proposal), JavaScript (J001), C,
  LLVM, WASM. No universal syntax tree: statement/expression splits,
  typing, control flow and memory models differ too much (WASM's
  structured stack machine, LLVM's SSA, JS's lack of int32 arithmetic).
- Reusable, target-free pieces: naming (deterministic numbering such as
  per-function pre-order counters and first-appearance type numbers, plus
  a per-target mangling table for keywords and reserved words); source
  locations (IR expressions carry `span`, Domain/IR/Internal.purs:114, so
  a neutral emitted-position-to-span map can drive Go `//line` and inline
  `/*line …*/` directives, JS source maps, C `#line`, LLVM debug
  locations; not proposed now); a document renderer only if a target
  needs width-based layout; and the plan → syntax → render discipline.
- Where a target-neutral lowered IR (L001) would help, without designing
  it: closure conversion and lifting (Lambda/Match/Pipe/Apply with
  Capture), staging of function values (Stage, Entry), match compilation
  (A002's `Features.Lower`), effect evidence passing (ctx, frames,
  markers), and cleanup registration and defect selection, all computed
  inside Format.Go today. The Go-free plan records (EntryPlan, frame
  plan, stage-type plan) are what would move into it; keeping them free
  of Go syntax makes that a relocation. Effect metadata that must survive
  checking is listed in CF001 §8.

## 9. Recommendation

Two tiers; only Tier 1 is recommended now.

Tier 1 (smallest useful abstraction, (A+)): Go-free plan records built
totally (no default-on-miss lookups), a `Signature` with a `Callee`
derived from it so each call takes ctx by call kind from its callee's
declaration (§3.1),
one Go-correct `quoted`, and `String` helpers for the repeated shapes of
§2.1 with explicit `Lines`/`Inline` layouts; a `raw` path for fixed
runtime templates. Basis: recorded defects D1 and D3 (plans), D2 (total
plans) and D7 (quoting, latent); D8 (`Callee`; forward risk, kept in Tier
1 only if the user accepts that basis); and the 607 concatenations.
`Lowered.code` keeps `String`; `Wrapper` (or `Shape`) gains each callee's
`Signature`, the only interface change (cost: every `Wrapper` producer in
Lowered and its readers in Value, Stage, Apply and Lambda, in step 3 and
step 6). No new traversal and no dependency or gate change.

Tier 2 (optional, decided after migration step 2): the (A′) opaque
newtypes with the export-list rules of §3.1 (`primary` tag, `funcLiteral`
the only `Stmt → Expr` bridge, counted `raw`/`fromLowered`). Adopt each
newtype only if the Entry and Stage steps show a readability gain or a
mistake it would have caught worth the `Lowered` interface change; none
is justified by a recorded defect today (§4). A full AST (C) waits for a
consumer that must read Go back; a Doc (B) waits for width-based layout.

Priority: after FX001 (Tasks 9-12 and merge; not added to that
milestone). Steps 0, 1 and 6 must precede FX005 and FX002 (CF001's
implementation) lowering (CF001 is a design pending user review; FX005 is
planned in effects-design.md:695 and CF001 design:631, not a BACKLOG
row); steps 2-5 and 7 can wait, though G003's statement splitting and
A002's implementation are easier after step 4. It does not block CF001's
design review, FX007 (checker-only) or A002's design. Below correctness
work (E007, E008, T002) and timing environment work (T003, T007).

Proposed BACKLOG row (for the controller):

| BK001 | Proposed | Go backend maintainability, docs/plans/2026-10-10-backend-syntax-proposal.md (not authorized; pending user review). Tier 1: Go-free plan records built totally, `Signature`/`Callee` so calls take ctx from the callee's declaration, Go-correct string quoting, `String` helpers with explicit `Lines`/`Inline` layouts, `raw` only for fixed runtime templates. Tier 2 (opaque `Expr`/`Stmt`/`Type`/`Name`/`Decl` newtypes) optional, decided after step 2. Evidence: 607 concatenations in 20 modules; D1 frame order (4b80bd1); D2 key-0 defaults (4b80bd1; still Stage.purs:194 `numberOf`, Entry.purs:106-107 `lookupOr`); D3 unused arrow type (3a3d197); D7 unescaped names (Task 8 review; latent); D8 ctx agreement by convention (forward risk; no mismatch recorded). No library (structure gate allowlist); no gofmt at build time. Steps 0, 1, 6 before FX005/FX002 lowering; 2-5, 7 later; each byte-identical against bootstrap/*.go and an effect-mode emit corpus; 12 Format.Go regression needles re-targeted and re-proven. Accept: verify green, regression proofs 100%, no Format.Go module over 250 lines. |

## Review response (2026-10-10)

| Finding | Change |
|---|---|
| I1 malformed-syntax overclaim | §3.1 export-list rules (no constructors, no `Semigroup`/`Monoid`/`Newtype`; `Name` arguments); escapes `raw` and transitional `fromLowered` named and counted; §3.2 cell narrowed, header ambiguity listed |
| I2 precedence | `Expr` carries `primary`; postfix builders parenthesize non-primary operands; cell says "with the `primary` tag" |
| I3 `iife` bridge | `funcLiteral` is the only `Stmt → Expr` bridge; `iife` = call of a `funcLiteral`, counted; function-literal sites added to §2.1 |
| I4 sketch keeps fallback | §5.2 plan is total: one `mapAccumL` opens kinds; Stage hands node numbers per parameter; no `lookupOr` |
| I5 D2 classification | D2 cites Stage.purs:194 and Entry.purs:106-107; `maybe ""` is D2′ (loud); BACKLOG row updated |
| I6 representations without a demonstrated mistake | §4 "Basis" column; Tier 2 entries marked risk/convenience |
| I7 ordering and D8 | §7 "Ordering" and §9: steps 0, 1, 6 first; `Callee` from `Signature` in §3.1 and §5.2 |
| I8 smaller abstraction | §9 restructured into Tier 1 (A+) and optional Tier 2 (A′) |
| I9 layouts | §5.3 `Lines`/`Inline` defined; step 1 pins both |
| M1-M9 | 2,766 lines; effect name (§2.2, D7); keyword-free names `caseOf`/`ifThen`/`typeDecl`/`varDecl`/`switchOn`; `Go.int32Type`; `nodeValue`/`nodePrevious` from Stage; §6 quoting without `show`; "no Go syntax" plans carrying a `Callee`; FX005 cited as planned; §3.4 stack sentence |
| Early-action note | D7 comment and `numberOf`/`lookupOr` totality recorded in §6 and §7 |

| N1 `Callee` coverage | §3.1 call kinds (`callee`, `valueCallee`, `Threaded`/`Root`, ctx-free later stages, `raw` calls); §6 contract sentence; §9 and §3.3 `Wrapper` interface change with cost |
| N2 D8 basis | D8 row, §4 row and §9 relabel `Signature`/`Callee` as forward risk (FX005/FX002); risk ranking reordered |
| N3-N8 | replacement texts applied: quoting rule (§6), declaration separators (§5.3), layout arguments and `arrayLiteral` (§5.2), primary literals (§3.1), step 2 Stage totality (§7), FX002 in ordering, priority and BACKLOG row |

Declined: none.
