# BK001 re-review (fix round 1)

Reviewer: read-only re-review, 2026-10-10. Proposal line numbers are for the
revised docs/plans/2026-10-10-backend-syntax-proposal.md (519 lines). Checked
against src/Format/Go.purs and Go/*.purs (Entry, Stage, Context, Value,
Lambda, Apply, Handle, Expression, Data), bootstrap/functions.go:178-230,
test/go-batch.mjs:36-48, scripts/regression.mjs:174-181, CF001 design §10,
effects-plan.md Task 12 Step 3, BACKLOG.md.

### Finding Verdicts

| Finding | Verdict | Evidence |
|---|---|---|
| I1 malformed-syntax overclaim | ADDRESSED | 120-127 export-list rules (no constructors, no `Semigroup`/`Monoid`/`Newtype`, `Name` arguments, counted `raw`/`fromLowered`); 141 cell narrowed, header ambiguity named |
| I2 precedence | ADDRESSED (see N6) | 128-131 `primary` tag, postfix builders; 142 |
| I3 `iife` bridge | ADDRESSED | 132-134 `funcLiteral` only bridge, `iife` counted; 44 literal sites; 143 |
| I4 sketch keeps fallback | ADDRESSED for Entry (see N7 for Stage) | 253-292: `place` opens kinds by `Map.size`, no `lookupOr`, no node map; 85 D2 fix text |
| I5 D2 classification | ADDRESSED | 85 cites Stage.purs:194 / Entry.purs:106-107; 86 D2′ loud; 500 BACKLOG row |
| I6 representations without demonstrated mistake | ADDRESSED in form; one row mis-based (N2) | 196-210 "Basis"/"Tier" columns; 201 claims "demonstrated: D8" |
| I7 ordering and D8 | ADDRESSED for ordering; D8 mechanism incomplete (N1) | 418-422, 489-493; 107-111, 316, 334-337 |
| I8 smaller abstraction | ADDRESSED | 467-487 Tier 1 (A+) / optional Tier 2 |
| I9 layouts | ADDRESSED (see N4, N5) | 347-360 `Lines`/`Inline`, step 1 pins both |
| M1 | ADDRESSED | 30 |
| M2 | ADDRESSED | 66-67, 91 |
| M3 | ADDRESSED | 174-175; sketch 306-329 (`caseOf`, `varDecl`, `switchOn`) |
| M4 | ADDRESSED | 320 `Go.int32Type` |
| M5 | ADDRESSED | 298-299, 337 |
| M6 | ADDRESSED (rule itself imprecise, N3) | 384-387 |
| M7 | ADDRESSED | 253 "no Go syntax" |
| M8 | ADDRESSED | 491-492 |
| M9 | ADDRESSED | 176-183 |

Entry sketch byte identity: holds. Kinds by `Map.size seen` equal today's
`Array.nub` index; slots and array sizes equal `placed.accum` counts; arrays
sorted by kind equal `mapWithIndex distinct`; node numbers are first
appearance over name-deduplicated wrappers (Stage.purs:55-63) in both; the
`Lines` rendering reproduces functions.go:182-198 and 207-230 exactly
(`\nvar …\n`, `\nfunc …Entry(e any) int32 {\n`, `}\n}\nreturn …\n}\n`); in
ctx mode the entry signature and `Go.call plan.wrapper` reproduce
`parameterList context ["e any"]` and `passed context`. Totality holds for
Entry: `place` uses `maybe'` with a fresh kind, no lookup can miss.

### New Problems

**N1 (Important) - the `Callee` rule does not fit every ctx-mode call site;
§6 overstates it.** Line 335 "`Go.call` inserts `ctx` from the callee's own
flag" and line 374 "ctx first in every ctx-mode signature and call (from
`Signature.context`)" conflict with:
- `main` passes `nil`, not `ctx` (Go.purs:94-97 `entered`), and go-batch.mjs:40
  pins `waxwingFn\d+\((nil)?\)`; a call that inserts `ctx` emits an undefined
  name there.
- Later stages are `func XStageK(e any) T` with no ctx in ctx mode
  (Stage.purs:155-158); only the closure they return takes ctx, and only the
  last stage passes ctx (to the entry: `passed (staging.context && last)`,
  Stage.purs:169). `firstStage` calls Stage2 without ctx (Stage.purs:147-151).
  So "every ctx-mode signature" is false; stage Signatures need
  `context: false` while the returned `funcLiteral` has `true`.
- Calls through function values (Apply.purs:113, 141 `waxwingValue(ctx, …)`;
  partial lambdas via `applied`, Lambda.purs:30) have no declaration
  `Signature`; their ctx comes from the function type (`typeList`,
  Context.purs:83-85, Data.purs:52-54).
- Runtime-template calls (`waxwingFind(ctx, …)` Effect.purs:51,
  `waxwingInstall(ctx, …)` Handle.purs:64, `waxwingFail[T](ctx, …)`
  Handle.purs:169, the frame fold over `"ctx"` Handle.purs:137) and handler
  clauses invoked by the runtime cross `raw`, outside any `Callee`.
- To be "from the declaration", the `Signature` built where a function,
  constructor (Data.purs:120-122) or lifted helper is declared must reach its
  callers (Value.purs:30-32 sees only `Lowered.Wrapper {name, parameters,
  result}`, Lowered.purs:73). If both ends rebuild it from `shape.context`,
  agreement is still by convention. Carrying it changes `Wrapper`/`Shape`,
  contradicting "no interface churn" (478-479).
Fix: in §3.1 replace "(`callee ∷ Signature → Callee`, `call ∷ Callee →
Array String → String`)" with "(`callee ∷ Signature → Callee` for declared
functions, constructors, lifted helpers and stages; `valueCallee ∷ String →
Callee` for a function value, ctx from the program's function-type mode;
`call ∷ Context → Callee → Array String → String`, where `Context` is
`Threaded` (passes `ctx`) or `Root` (passes `nil`, for `main`); a callee
whose `Signature.context` is false (later stages, runtime helpers) gets
none)". Replace §6 line 374-375 with "Runtime contracts: ctx first in every
signature whose `Signature.context` is true (functions, constructors,
lifted helpers, first stages, stage closures, entries; not later stages
`(e any)`) and in every call of such a callee; `main` passes `nil`; calls
into and out of `raw` runtime templates stay spelled in the template". In
§9 replace "`Lowered` keeps `String`, so there is no interface churn" with
"`Lowered.code` keeps `String`; `Wrapper` (or `Shape`) gains each callee's
`Signature`, the only interface change".

**N2 (Important, text-only) - Tier 1 `Signature`/`Callee` is not backed by a
demonstrated defect.** §4 line 201 says "demonstrated: D8" citing helper
counts; D8 (line 92) cites the `effect-free-ctx` row, but that row mutates
mode *selection* (`usesContext`, regression.mjs:174-181; Context.purs:29-31),
which §6 (376-377) keeps as planning and `Callee` cannot prevent. None of the
18 Format.Go commits fixes a signature/call ctx mismatch (Task 7 review line 5
records uniform ctx as correct). Replace row 201's basis with "risk: no
recorded signature/call mismatch (`effect-free-ctx` is mode selection, not
agreement); justified by the ctx changes FX005 and FX002 will make (CF001
§10 items 4, 6; changes 5-6)"; in D8's row replace "`effect-free-ctx`
regression row (scripts/regression.mjs:177)" with "no mismatch recorded;
the `effect-free-ctx` row (scripts/regression.mjs:177) guards mode
selection, a different check". Keep it in Tier 1 if the user accepts
forward risk as the basis; say so in §9 ("D8 (`Callee`; forward risk)").

**N3 (Minor) - quoting rule is wrong for non-ASCII.** Line 385-386 allows
"`\xNN` … for … non-ASCII code points"; in Go `\xNN` is one byte, so `é`
(U+00E9) as `\xe9` yields invalid UTF-8. `\u` covers only four hex digits.
Replace 384-387 with: "Quoting: `quoted` implements Go's interpreted-string
escaping: `\"`, `\\`, `\n`, `\r`, `\t`; other code points below U+0020 and
U+007F as `\xNN` (a single byte, equal to the code point only below
U+0080); every other code point emitted as itself (Go source is UTF-8) or
as `\uXXXX` / `\UXXXXXXXX` (eight digits above U+FFFF), never `\xNN`; `'`
is not escaped (`\'` is invalid in Go strings). It decodes UTF-16 surrogate
pairs first; a lone surrogate has no Go escape and cannot arise from
Lex-restricted names (Lex.purs:202-211). It must not use PureScript `show`,
whose decimal escapes (`\127`, prelude `showStringImpl`) Go rejects."

**N4 (Minor) - the `Lines` separator rule is not general.** Line 355 says "a
top-level declaration adds `\n` before and after"; true for Entry/Stage, but
top-level functions are joined by `"\n"` (Go.purs:52), lifted functions get a
leading `"\n"` from their owner (Go.purs:125 `separated`), and Lambda/Match/
Block helpers render none (Lambda.purs:64-73). Replace that clause with "the
separator around a top-level declaration is a parameter of `declarations`
(Entry and Stage: `\n` before and after; functions and lifted helpers: `\n`
between, as Go.purs:52 and :125 do today), pinned per call site in step 1".

**N5 (Minor) - sketch omits the layout argument §5.3 requires.** 349-351 say
`switchOn`/`caseOf`/`countDown` take a layout; 312-323 pass none. Replace
`Go.countDown names.position` with `Go.countDown Go.Lines names.position`,
`Go.switchOn (` with `Go.switchOn Go.Lines (`, `Go.caseOf (Go.int` with
`Go.caseOf Go.Lines (Go.int`. Add after line 320: "`arrayLiteral` renders a
sized `[n]T{…}`, n the element count."

**N6 (Minor) - `primary` must be set for literals.** Append to line 131:
"Function literals, composite literals, conversions, calls, selectors and
parenthesized binaries are primary (Go `Operand`/`PrimaryExpr`), so
`func() T { … }()` (Expression.purs:92-96) gains no parentheses;
`&T{…}`, `*p` and unary `-` are not."

**N7 (Minor) - Stage's half of totality is asserted, not shown.** Stage
still reaches parameters by position (`Array.index`, Stage.purs:184-194;
stages over `Array.range 2 n`, :111-113), so handing it `Array Parameter`
keeps a `Maybe` per lookup. Replace step 2 (405) with "2. Entry and Stage's
node numbering (§5): total plans; stages generated by iterating the
`Parameter` array (`mapWithIndex`, with the next element zipped), not
`Array.index`, so `numberOf`, `parameter` and `node` lose their defaults;
functions.go. Afterwards decide Tier 2 (§9)." and drop "removes `maybe ""`
(D2′)" from step 3 (or keep it there and say step 2 removes only
`numberOf`).

**N8 (Minor) - priority names CF001 where FX002 is meant.** CF001 is a
design; its implementation is FX002 (effects-plan.md:847-849), and FX005 is
"before FX002" (CF001 design:631-632). Otherwise consistent: Tasks 9-12
touch no Format.Go file, CF001 is "pending user review" (CF001:3-5).
Replace 418-419 "steps 0, 1 and 6 are the prerequisite for CF001 and FX005
lowering implementation" with "steps 0, 1 and 6 are the prerequisite for
FX005 and FX002 lowering (FX002 implements CF001; FX005 precedes FX002,
CF001 design:631-632)"; 490-491 "must precede CF001 and FX005 lowering
implementation (CF001 is a proposed design pending review; …" with "must
precede FX005 and FX002 (CF001's implementation) lowering (CF001 is a
design pending user review; …"; in the BACKLOG row "Steps 0, 1, 6 before
CF001/FX005 lowering" with "Steps 0, 1, 6 before FX005/FX002 lowering".

### Verdict

**Accept with fixes.** All of I1-I9 and M1-M9 are addressed; the Entry
sketch is byte-identical and total. Fix N1 (`Callee` sources, `main`'s
`nil`, ctx-free later stages, function values, the §6 contract sentence and
the `Wrapper` interface note) and N2 (relabel D8's basis as forward risk)
before user review; N3-N8 are Minor with the replacement text above.
