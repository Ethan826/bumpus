# Go backend syntax: a bounded maintainability proposal (BK001)

Status: Proposed (BK001); not authorized; pending user review.

Requirements (binding): .superpowers/sdd/2026-10-09-effects-plan/
backend-requirements.md (user, 2026-10-10). Ground truth: src/Format/Go.purs
and src/Format/Go/*.purs at 2fc7a02, their git history, docs/progress.md,
the SDD review ledgers under .superpowers/sdd/2026-10-09-effects-plan/,
BACKLOG.md, scripts/structure.mjs, spago.yaml/spago.lock and the tests
named below. Everything under "proposed" is design only.

## 1. Scope and non-goals

In scope: how Format.Go builds Go text; which representation would make
it more readable and harder to get wrong; an incremental migration that
keeps output byte-identical; what carries over to future targets.

Non-goals: no implementation now; FX001's milestone (Tasks 9-12) is
unchanged and no FX001 task depends on this; no change to emitted Go
semantics, naming, runtime contracts or the ctx/defect modes; no new
runtime, tool boundary or build-time Go tool; no design of the lowered IR
(L001) or of any other target.

## 2. Survey of Format.Go

### 2.1 Size and shape

22 modules, 2,814 lines (largest Lowered 206, Stage 197, Handle 178,
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
| `panic(` | 8 (4) | unmatched, malformed, runtime templates |
| nil comparisons | 12 (6) | Match nil guards, runtime templates |
| `switch` / `case` | 4 / 3 | Entry, Handle, Show, Compare |
| `return ` | 51 (17) | |
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
- Stage.purs:68-90, 129-194: which stage types are interned, own or
  spelled inline is decided while emitting declarations; missing lookups
  fall back to `""` (`parameter`, `node`) or `0` (`numberOf`).
- Effect.purs:45-63: `parameterList true` hard-codes ctx mode; the body
  reads the literal `ctx`; operation names are spliced into a Go string
  literal unescaped.
- Go.purs:72-88 (`entryMain`) fixes a one-line `func main() { … }` that
  test/go-batch.mjs:37-48 matches by regular expression.

Pure modules with no Go text (Usage, Layout, Capture, Lowered's shape
tables) already show the intended split: they plan, others print.

### 2.3 Demonstrated defects and latent risks

No commit in the 18-commit history of src/Format/Go* fixes malformed Go
syntax: `go build` in the tests catches syntax errors before review. The
recorded defects are planning errors, silent fallbacks, unescaped text
and stack depth:

| # | Defect (evidence) | Class | Would a representation have prevented it? |
|---|---|---|---|
| D1 | Clauses of one `handle` installed in reverse; a well-typed program panicked (Task 7 review Critical, review-task7-result.md:23-27; fixed 4b80bd1, Handle.purs:136-147) | planning interleaved with text | Not by syntax types. A separate frame plan (innermost-first array) is unit-testable without Go; the fold over text was not |
| D2 | Silent key-0 fallbacks emitted plausible wrong Go (`handlerKey _ → EffectKey 0`, `effectShape` default; Task 7 review Minor; fixed 4b80bd1) | fallback to valid-looking text | Partly. Still present: Stage.purs:184-194 `maybe ""` emits an empty type (`x ` → syntax error) or `&{x, e}`; Entry `lookupOr` 0; Lowered `missing`. A `Type`/`Expr` with no empty constructor forces the caller to choose a guard explicitly |
| D3 | Stage declared an unused own arrow type (FN001 Task 6 review; fixed 3a3d197, bootstrap/functions.go lost `type …Arrow1`) | name planning inside declaration emission | By separation: a stage-type plan that lists uses makes an unused declaration a testable fact |
| D4 | Capture loss: mutants give Go `undefined: bumpusLocal3` (E005, progress.md:540-568; 09f3071, c928d93) | scope planning | Not by builders. A target AST could add a test-only "every referenced local is bound" check; the free-set computation (Capture) is the real guard |
| D5 | `payloadName` recursed along arrow spines; 5,000 arrows overflowed the JS stack (Task 8 review Important 2; fixed d5bfa8d) | stack depth in emission | No; a new tree adds traversals that must obey the same rule (§3.4) |
| D6 | Nested IIFEs made `go build` exponential (E005); one long expression builds superlinearly (G003, findings.md:310-326) | shape of emitted Go | No, but an explicit `iife` builder makes the remaining sites visible and countable |
| D7 | Type names spliced into Go string literals unescaped (Task 8 review Minor; Report.purs:48-51; same at Effect.purs:51-55) | literal quoting | Yes: a string-literal builder quotes once |
| D8 | ctx threading by convention: signatures (`declared`, `parameterList`, `contextParameter`, literal `ctx`) and calls (`passed`, `"ctx"`) agree only by review; `effect-free-ctx` regression row (scripts/regression.mjs:177) | declaration/call agreement | Yes: one `Signature` with a `context` flag, and calls built from the same flag |

Risk ranking for the current code (likelihood × cost of a silent miss):
D8 and D2 highest (every new lowering adds signatures and lookups; CF001
and FX005 will change ctx threading), then D1/D3-style planning errors in
Handle and Stage, then D7 (latent), then syntax and precedence (none
observed; every binary operator is fully parenthesized, Compare.purs:58-72).

## 3. Options

### 3.1 The options

- (A) Rendering helpers over `String`: `call`, `commaList`, `block`,
  `funcDecl`, `switchOn`, `quoted`. Each removes repeated punctuation;
  types remain `String`.
- (A′) Typed builders: the helpers of (A) over newtypes `Name`, `Type`,
  `Expr`, `Stmt`, `Decl`, each holding already-rendered text with its
  constructor private. Text is produced eagerly, as today, so no second
  traversal exists. This is the intermediate point the evidence favors.
- (B) A Wadler/Leijen document (`Doc` with `text`, `line`, `nest`,
  `group`) rendered at a width; from a library or in-repo.
- (C) A small Go AST for the generated subset (`Expr`, `Stmt`, `Decl`,
  `Type` as ADTs) and one renderer.

### 3.2 What each prevents

| Prevents | (A) | (A′) | (B) | (C) |
|---|---|---|---|---|
| Formatting errors (separators, newlines, spacing) | at helper sites | yes | yes (its purpose) | yes |
| Malformed syntax (unbalanced braces, empty type, missing parentheses) | partly | yes, except through an explicit `raw` escape | no: a Doc is text | yes |
| Precedence mistakes | no | yes: `binary` always parenthesizes, as today | no | yes (rule or table) |
| Invalid statement placement (`return`, `:=`, `defer` in an expression) | no | yes: `Stmt` is not an `Expr`; `iife` is the only bridge | no | yes |
| Unquoted literals (D7) | if used | yes | no | yes |
| ctx mismatch (D8) | if used | yes (`Signature`) | no | yes |
| Planning errors (D1, D3, D4) | no | no | no | no; only plan/syntax separation and tests |

None of them establishes Go type correctness (int vs int32, interface
assertions: D1 was well-typed Go that failed an assertion at run time),
Go's unused-variable and undefined-name rules, or semantic preservation
(evaluation order, frame order, cleanup order). Those need `go build`
(test/go-batch.mjs), executable tests with exact stdout (fx-run 24
programs, fn-run 22, adt-*), the reference interpreter and differential
(scripts/differential.mjs; FX001 Task 10), and regression mutants. (C)
alone could add cheap Go-level checks (bound names, unused locals) as test
oracles; that is its main extra, and it duplicates `go build`.

### 3.3 Cost and migration risk

| | (A) | (A′) | (B) | (C) |
|---|---|---|---|---|
| New code | ~80 lines | ~250 lines in 2 modules | library: none; in-repo ~200 | ~200 types + ~250 renderer |
| Byte-identical migration | easy | easy: renders the same strings | hard: layout is decided by the renderer, so every one-line form needs explicit `group`/`flatten` | moderate: renderer must reproduce both one-line and multi-line forms |
| Stack profile | unchanged | unchanged | new: deep `Cat` chains | new: one more tree traversal |
| Interface churn | low | `Lowered.code`, `lifted` change type | low | `Lowered` changes type; mutants re-targeted |

### 3.4 Fit with project constraints

- Purity and layers: all four live in Format (pure). (A′)/(C) syntax
  modules import nothing from Domain.IR.Internal; `goType` stays in
  Format.Go.Data, mapping IR types to `Type`.
- 250-line files, 30-line declarations, `where`, no lambdas: builders are
  one-line functions; (C)'s renderer is a dispatch over ~20 constructors,
  an E003-style flat table mapping.
- Stack safety (spines of 20,000 arrows, 20,000-`let` blocks, 20,000
  parameters): lists are `Array`s rendered with `joinWith` (no recursion);
  nesting is bounded by E_NESTING (128) times a small lowering factor.
  (A′) renders eagerly, so it adds no recursion. (C) adds one traversal of
  that bounded depth, acceptable if every list is an `Array`. (B) is the
  risk: a 20,000-statement body as right-nested `Cat` nodes is 20,000
  deep unless the renderer runs an explicit stack (`tailRec`).
- Libraries: spago.yaml uses 11 core packages. dodo-printer 2.2.3
  (spago.lock:145) and prettier-printer 3.0.0 (spago.lock:430) appear only
  in the registry 81.0.0 package-set listing, not among the resolved
  packages. The pure-layer allowlist (scripts/structure.mjs:18) admits
  only Prelude, Control.Monad.Rec.Class and Data.{Map, Set, Tuple, Array,
  Either, Maybe, Int, String, Foldable, Traversable}; `Dodo` or
  `Text.Pretty` imports would fail the structure gate, so adoption means
  widening an enforced rule (and docs/engineering.md) and adding
  transitive dependencies I could not check offline. With no width-based
  layout in today's output, a library buys nothing concrete. Verdict: no
  library; (B) in-repo only if gofmt-like layout is ever wanted.
- gofmt: running gofmt or go/printer at compile time adds a Go-toolchain
  boundary to Program and buys nothing `go build` does not already check;
  rejected. As a test-only check, `gofmt -l` fails on all five snapshots
  today; it becomes useful only after an intentional "gofmt-clean output"
  change (every snapshot, go-batch.mjs's `main` regexes and every
  text-pinning test change). (A′)/(C) make that a change to one block
  renderer; it is not proposed now. `gofmt -e` is redundant with
  `go build`.

## 4. Which separate representations are justified

| Representation | Justified now? | Evidence |
|---|---|---|
| Plan records per generator (no Go text) | yes | D1, D3; Entry and Stage interleave layout with text |
| `Signature { name, context, parameters, result }` and context-aware calls | yes | D8; 26 `func` sites, 34 ctx-helper and literal uses |
| `Stmt` distinct from `Expr`; `iife` the only bridge | yes | 5 IIFE sites; D6 shows their cost; statement-only forms (`:=`, `defer`, `_ =`, `switch`, `for`) in Match, Block, Handle, Entry, Effect |
| Quoted string literals; `int32(n)` literals | yes | D7; `integer` (Data.purs:83) is already the single site for Int |
| `Type` distinct from `Expr`, no empty value | yes | D2 (Stage `maybe ""`) |
| `Name` newtype from Format.Go.Data's naming functions | yes, cheap | keeps generated naming in one module; declarations and references use one value |
| `Decl` (func, var, type) with fixed separators | yes | decl separators are spelled per site (`"\nfunc "`, `"\nvar "`, `"}\n"`) |
| Precedence-aware binary expressions | no | no defect; full parenthesization stays the rule |
| Inspectable Go AST (C) | not yet | only use would be test oracles (D4) already covered by `go build` and Capture tests; revisit if L001 or a Go-level optimization needs to read Go back |
| Doc layout engine (B) | no | no width-based layout; one-line forms are fixed |

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
spells a whole `case` with four embedded newlines.

### 5.2 After (sketch; proposed, not compiled)

Planning, in Format.Go.Entry: no Go text, unit-testable (kinds, slots and
counts for a wrapper of mixed parameter types).

```purescript
type EntryPlan =
  { wrapper ∷ String
  , context ∷ Boolean
  , result ∷ Ty
  , kinds ∷ Array Int -- per position
  , slots ∷ Array Int -- per position
  , arrays ∷ Array Storage -- per distinct argument type, by kind
  , arguments ∷ Array Placed -- per position, for the final call
  }

type Storage = { kind ∷ Int, count ∷ Int, ty ∷ Ty, node ∷ Int }

entryPlan ∷ Boolean → Map Ty Int → Wrapper → EntryPlan
entryPlan context nodes wrapper =
  { wrapper: wrapper.name
  , context
  , result: wrapper.result
  , kinds: map kindOf placed.value
  , slots: map slotOf placed.value
  , arrays: Array.mapWithIndex storage distinct
  , arguments: placed.value
  }
  where
  distinct = Array.nub wrapper.parameters
  kinds = Map.fromFoldable (Array.mapWithIndex numbered distinct)
  numbered index ty = Tuple ty index
  placed = mapAccumL (place kinds) Map.empty wrapper.parameters
  storage kind ty = stored kind ty (lookupOr kind placed.accum)
    (lookupOr ty nodes)
  kindOf found = found.kind
  slotOf found = found.slot
```

Syntax construction, using a proposed `Format.Go.Syntax as Go`; names come
from one place (`entryNames`), the only literals are Go's own:

```purescript
entryDeclarations ∷ EntryPlan → Array Decl
entryDeclarations plan =
  [ table names.kinds plan.kinds
  , table names.slots plan.slots
  , Go.function signature
      (map (storageVar names) plan.arrays <> [ walk, Go.return final ])
  ]
  where
  names = entryNames plan.wrapper
  signature =
    { name: names.entry
    , context: plan.context
    , parameters: [ Go.parameter names.chain Go.anyType ]
    , result: goType plan.result
    }
  walk = Go.countDown names.position (Array.length plan.kinds - 1)
    [ Go.switch (Go.index (Go.ref names.kinds) (Go.ref names.position))
        (map (unpack names) plan.arrays)
    ]
  final = Go.callIn plan.context (Go.ref names.wrapper)
    (map (argument names) plan.arguments)

table ∷ Name → Array Int → Decl
table name values = Go.var name (Go.arrayLiteral Go.int32 (map Go.int values))

unpack ∷ EntryNames → Storage → Go.Case
unpack names storage = Go.case (Go.int storage.kind)
  [ Go.define names.node
      (Go.assert (Go.ref names.chain) (Go.pointer (nodeType storage.node)))
  , Go.assign (Go.index (Go.ref (slotArray storage.kind)) slot)
      (Go.select (Go.ref names.node) "value")
  , Go.assign (Go.ref names.chain) (Go.select (Go.ref names.node) "previous")
  ]
  where
  slot = Go.index (Go.ref names.slots) (Go.ref names.position)
```

(`storageVar`, `argument`, `stored`, `entryNames` and `slotArray` are
one-line helpers; `EntryNames` holds `wrapper`, `entry`, `kinds`, `slots`,
`chain` (`e`), `node` (`v`) and `position` (`p`).)

Rendering, in Format.Go.Syntax: `entry context nodes wrapper =
Go.declarations (entryDeclarations (entryPlan context nodes wrapper))`,
where `declarations` prefixes each declaration with `"\n"`, a multi-line
body puts each statement on its own line and closes with `"}\n"`, `switch`
and `for` open with `" {\n"`, `case k:` is followed by its statements, and
`arrayLiteral` spells `[n]int32{a, b}`. Expected difference in emitted Go:
none (bootstrap/functions.go holds three entries and must stay
byte-identical).

## 6. Preservation

- Evaluation order: builders never reorder; the order of `Array Expr`
  arguments and `Array Stmt` statements is the order given. Constructs
  that encode order stay as they are and stay explicit: Apply's
  argument blocks (block-order row), the pipe temporary, the lifted match
  scrutinee, the IIFE for `if`, `defer` registration.
- Determinism: no maps are iterated while rendering; plans keep today's
  `Array.nub`, `mapAccumL` and first-request orders.
- Generated naming: unchanged. Name spellings stay in Format.Go.Data
  (`functionName`, `localName`, …) and the per-function pre-order counter
  in Lowered; `Name` only wraps them.
- Runtime contracts: ctx first in every ctx-mode signature and call
  (`Signature.context`), handler/marker/frame layout, cleanup LIFO and
  the defect report text are unchanged; ctx mode selection
  (Context.usesContext) is planning and does not move.
- Fixed runtime support stays readable templates: Context.runtime
  (Context.purs:108-175), Cleanup.cleanupRuntime, the Compare/Show helper
  bodies' fixed parts, `waxwingAdd`, and the import block. They become one
  `Go.raw ∷ String → Decl` each, the only raw escape, reviewed like data.
  Parameterized generators (per-type Compare/Show helpers, Effect structs
  and perform functions, Handle, Stage, Entry, Match, Block) migrate.

## 7. Incremental migration

Each step: one or two modules, no file over 250 lines, `npm run verify`
green, emitted Go byte-identical, regression proofs 100%.

0. Baseline for effect-mode output, which no byte snapshot covers today
   (bootstrap/ holds answer, functions, lists, shapes, tree): a scratch
   corpus comparison (emit before/after over examples/, the fx-run,
   fx-cleanup, fn-run and adt programs, `cmp`), as E005 did on 21
   programs (progress.md:563); or, with user approval, a new snapshot of
   one effect example (an intentional addition, not an output change).
1. Format.Go.Syntax (+ .Syntax.Statement): types, builders, renderer, and
   unit tests that pin each builder's text, including quoting.
2. Entry (§5): the representative step; bootstrap/functions.go.
3. Stage, Lambda, Value, Apply, Pipe: functions.go. Removes Stage's
   `maybe ""` fallbacks (D2) as a planned guard, byte-identical for every
   program that compiles today.
4. Match, Data, Compare, Show: shapes.go, tree.go, lists.go.
5. Go.purs (`function`, `entryMain`, `imports`): keeps the one-line
   `main` that test/go-batch.mjs:37-48 matches.
6. Effect mode: Context's signature helpers become `Signature`; Handle
   (frame plan first, D1), Effect (quoted names, D7), Block, Report,
   Cleanup's generated parts.
7. Change `Lowered.code`/`lifted` from `String` to `Expr`/`Array Decl`
   once all producers are typed (can be folded into steps 3-6 if each
   module converts at its boundary with one `Go.render`).

Costs to plan for:

- Regression rows needling Format.Go text: 12 (scripts/regression.mjs:
  nil-guard, ctor-order, first-field, show-fields, capture,
  effect-free-ctx; scripts/regression-fn.mjs: stage-value, stage-lambda,
  partial-strict, pipe-order, lambda-capture, block-order). Six quote or
  inject Go text (nil-guard, ctor-order, block-order, and the three
  `eta`-built replacements) and must be rewritten in builder form; each
  re-targeted row is shown failing with its defect restored, per
  AGENTS.md. The others move only if their line moves.
- Tests that pin emitted text (12 test files grep generated names or Go
  fragments, e.g. test/match-lift.test.mjs, test/adt-match.test.mjs) stay
  valid while output is byte-identical.
- Any intentional output change (none proposed) is its own commit with
  regenerated snapshots, a progress entry and the reason.

## 8. Future targets

- Shape: one shared compiler IR feeding separate backends. Today that is
  the monomorphic IR (Domain.IR.Internal, visible to Format.Go* only by
  scripts/structure.mjs:23-26); later the L001 lowered IR, placed after
  specialization and above target layouts (language-direction.md
  "Intermediate representations and future targets"). Each backend owns a
  language-specific syntax: Go (this proposal), JavaScript (J001), C,
  LLVM (textual IR or a builder), WASM (WAT or binary). No universal
  syntax tree: statement/expression splits, typing, control flow and
  memory models differ too much (WASM's structured stack machine, LLVM's
  SSA, JS's lack of int32 arithmetic).
- Reusable pieces, small and target-free:
  - Naming: deterministic numbering (per-function pre-order counters,
    first-appearance numbering of node and arrow types), and a mangling
    table per target (Go identifiers and keywords vs JS reserved words vs
    C), kept apart from what is named.
  - Source locations: IR expressions already carry `span`
    (Domain/IR/Internal.purs:114). A backend-neutral map from emitted
    position to source span can drive Go `//line file:line:col` and inline
    `/*line …*/` directives (our bodies put many source expressions on one
    Go line, so the inline form matters), JS source maps, C `#line`, LLVM
    debug locations. Not proposed now; Report and diagnostics are the
    first consumers.
  - A document renderer, only if a target needs width-based layout
    (likely JS for readability); it stays target-free text.
  - Builder discipline (plan → syntax → render) and the byte-identical
    migration method, rather than shared code.
- Where a target-neutral lowered IR (L001) would help, without designing
  it: closure conversion and lifting (today Lambda/Match/Pipe/Apply each
  lift in Go terms with Capture), staging of function values (Stage,
  Entry), match compilation (A002's `Features.Lower`), effect evidence
  passing (ctx threading, frames, markers), and cleanup registration and
  defect selection. Each is computed today inside Format.Go and would
  otherwise be re-derived by every target. The plan records of §5
  (EntryPlan, frame plan, stage-type plan) are the parts most likely to
  move into such an IR later; keeping them free of Go text now makes that
  move a relocation, not a rewrite. What effect metadata must survive
  checking for later targets is already listed in CF001 §8.

## 9. Recommendation

Smallest useful abstraction: (A′) typed builders plus plan records.
`Format.Go.Syntax` provides `Name`, `Type`, `Expr`, `Stmt`, `Decl` as
newtypes over rendered text, a `Signature` carrying the ctx flag, builders
for the shapes counted in §2.1 (call, callIn, index, select, assert,
pointer, int, int32, string, binary-parenthesized, arrayLiteral, iife,
define, assign, var, discard, return, if, switch/case, countDown, defer,
function, var/type declarations) and one `raw` escape for fixed runtime
templates. Generators split into plan (no text) and syntax (no layout
decisions). Reasons: it addresses the recorded risks (D2, D7, D8 by type;
D1, D3 by separation) and the 607-concatenation density; it renders the
same strings eagerly, so byte identity is mechanical and no new traversal
threatens stack safety; it needs no dependency or gate change. A full AST
(C) waits for a consumer that must read Go back; a Doc (B) waits for
width-based layout.

Priority: after FX001 (Tasks 9-12 and merge; not added to that
milestone). Steps 1-2 are a small standalone slice. Step 6 (effect mode)
should land before implementation work that changes Go lowering of ctx,
frames or cleanup: CF001 (`par`, discard polls, ctx-mode change; still a
proposed design pending review) and FX005 (ctx elimination, cached
lookup), and before G003 (splitting long chains into statement sequences
needs `Stmt`). It does not block CF001's design review, FX007
(checker-only) or A002's design; A002's implementation should print
through the builders. Below correctness work (E007, E008, T002) and
timing environment work (T003, T007).

Proposed BACKLOG row (for the controller):

| BK001 | Proposed | Go backend syntax: typed builders and plan records for Format.Go, docs/plans/2026-10-10-backend-syntax-proposal.md (not authorized; pending user review). Format.Go.Syntax (`Name`, `Type`, `Expr`, `Stmt`, `Decl` newtypes over rendered text, `Signature` with the ctx flag, quoted literals, `raw` only for fixed runtime templates); generators split into Go-free plans and syntax. Evidence: 607 concatenations in 20 modules; D1 frame order (4b80bd1), D2 key-0 and `maybe ""` fallbacks (4b80bd1, Stage.purs:184-194), D3 unused arrow type (3a3d197), D7 unescaped literals (Task 8 review), D8 ctx threading by convention. No library (structure gate allowlist); no gofmt at build time. Migration in 8 steps, each byte-identical against bootstrap/*.go and an effect-mode emit corpus, 12 Format.Go regression needles re-targeted and re-proven. After FX001; effect-mode step before CF001/FX005/G003 lowering work. Accept: all steps byte-identical, verify green, regression proofs 100%, no Format.Go module over 250 lines. |
