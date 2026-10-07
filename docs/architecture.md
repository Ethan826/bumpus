# Compiler architecture

Five layers, each named for what would make it change (ADR 004, design in
docs/plans/2026-10-07-five-layers-design.md). Imports run only to the same or
an earlier layer; scripts/structure.mjs enforces it from `purs graph`.

| Layer | Modules (src/) | Role |
|---|---|---|
| Domain | Syntax, Resolved, Problem, Host, IR.Internal | syntax trees, spans, `Ty`, resolved syntax, checked IR, `Problem` data, capability-port types |
| Features | Resolve, Resolve.{Expression,Types,Pattern,Repeated,Fresh}, Check, Check.{Match,Tables,Inhabited,Signature,Matrix,Usefulness,Missing,Coverage,Search} | resolution, checking, coverage; report `Problem` data, never text |
| Format | Lex, Parse, Parse.*, Stack, Go, Go.{Layout,Data,Match,Compare,Show,Usage}, Diagnostic, Wire, Arguments | text in (tokens, parser, reserved words, uppercase rule); Go out; diagnostic text, `E_*` names, wire records, usage text |
| Runtime | Node (+ Node.js) | port implementations, argv/stdout/stderr/exit, JSON; the only FFI |
| Program | Compile, Command, Main | pure `compile`, commands over any `Host`, entry point |

Domain, Features and Format are pure (core library allowlist, no Effect).

## Pipeline

```text
String -> Lex/Parse -> Syntax -> Resolve -> Resolved -> Check -> IR
       -> Coverage (Either Diagnostic) -> Go text
```

Program.Compile composes the phases; Program.Command runs emit/build/run over
the `Domain.Host` ports (records over an abstract monad), so
test/program.test.mjs substitutes fakes. Expected source errors are
`Either Diagnostic`; the first error in phase/traversal order wins. Host
failures (`IoFailure`, `ToolFailure`) are separate values rendered by
Format.Wire.

## Phases

- **Parse** (G001, ADR 006). Format.Parse.Grammar owns `Parser`, a newtype
  whose constructor is not exported, with Functor, Apply and Applicative
  instances only (no Bind, Monad or Alt). Choice is LL(1): `dispatch` picks
  a case by the next token's text without consuming, so error locations
  and messages are those of the hand-written parser it replaced. Grammar's
  `apply` is the only place the remaining input is threaded (the
  `state-thread` regression row restores the defect); Format.Parse.Cursor
  holds the token state and its primitive steps. Every list (`sepBy1`,
  `sepByTrailing1`, `commaList`, `chainLeft1`) is a `tailRecM` loop, so
  breadth costs no stack. `nested`, `infixed` and `rooted` count nesting,
  and depth past `nestingLimit` (128) is E_NESTING. Productions
  (Format.Parse and Format.Parse.{Literal, Pattern, Expression,
  Declaration}) may not use `do`, `bind` or the Kleisli operators, and only
  Format.Parse imports `run` and `initialState` (CST gate,
  docs/engineering.md).
- **Resolve** has two type passes (register names, assign TypeId/CtorId in
  declaration order; then resolve field and signature types) so mutual
  recursion works. Functions and constructors share one global table. LocalIds
  number parameters, then binders in source pre-order. The counter is
  threaded by Features.Resolve.Fresh, a state-and-error type with Bind (a
  pattern's binders scope its arm body); arms, arguments and pattern fields
  go through Array `traverse`, which is balanced, so resolution depth is
  logarithmic in list length (G001 Task 4).
- **Type table.** `TypeInfo {name, ctors, span}` and `CtorInfo {name, owner,
  fields, span}` travel with the program. Names appear only in messages, never
  in Go.
- **Check** produces checked IR (`Construct CtorId`, `Match`, `Pattern`) and is
  the only producer of `CheckedProgram`. It reports E_INTERNAL for invalid
  local/function/type indices; its resolved-syntax input is a trusted phase
  interface, not a hostile-IR validator.
- **Coverage** (Features.Check.Coverage, Usefulness, Missing, Matrix,
  Signature, Inhabited) runs after the whole program type-checks:
  inhabitedness least fixed point (Inhabited, a worklist), Maranget
  usefulness (Usefulness), canonical witness by algorithm I (Missing), over
  the shared pattern-matrix operations in Matrix. Type errors in later
  functions take precedence over coverage errors. Its three linear searches
  (redundancy over arms; exhaustiveness and wildcard usefulness over
  constructors) use Features.Check.Search `firstJust`, a `tailRecM` loop
  (G001 Task 4b); usefulness and algorithm I keep their pending heads and
  witness continuations on an explicit Search `Stack` in a `tailRecM` loop,
  so pattern columns cost no JavaScript stack (G001 final review).
- **Compare** is one expression form, `Compare Operator Expr Expr`, through
  every phase (Operator is a closed Domain ADT); the checker requires equal
  operand types and yields Bool. No target detail enters IR.
- **Go** (Format.Go*) emits one tagged struct per type, constructors, and
  sequential first-match lowering with nil guards. Format.Go.Compare emits a
  `bumpusCmpN` per declared type (and `bumpusCmpBool`, decided by
  Format.Go.Usage), Format.Go.Show a `bumpusShowN` per type; `main` prints
  through the latter for declared results (ADR 005). Go representation decisions
  live here, not in Features.

Only `Features.Check*` and `Format.Go*` import `Domain.IR.Internal`. This is an
enforced project boundary, not PureScript privacy.

## Verified Go properties

Names are mangled from IDs; no source spelling, timestamp or absolute path
enters output. Emission is byte-deterministic (`bootstrap/answer.go`,
`bootstrap/shapes.go`, `bootstrap/tree.go` snapshots). Int is int32 with
wrapping addition.
Generated code never dereferences nil unguarded (ADR 003). Generated Go is
canonical emitter output; gofmt copies are presentation only.

Lexing and declaration parsing are index-based `tailRecM` loops
(Control.Monad.Rec.Class is allowlisted), so long declaration sequences and
whitespace do not overflow the stack. Since G001, long comma, constructor
and match-arm lists inside one declaration do not either, and nesting
deeper than 128 levels is E_NESTING (ADR 006). Every later phase still
recurses over the tree, which is why the limit exists (heap-based phases
are BACKLOG H001; iterative operator chains O001). Format.Go computes a constructor layout (Format.Go.Layout) once, so
Go emission never searches the type tables per constructor.

## Future stages (proposed, not implemented)

Syntax -> Resolved -> Kinded -> Checked constraints -> coverage/instances ->
Elaborated IR -> lowered Go IR -> emitted Go. A target-neutral
`Features.Lower` is deferred until decision-tree match compilation gives it a
target-neutral job (BACKLOG A002). Foreign values (FFI) need full-value
validation of tag and payload consistency before they become closed sums
(I001). No fake stages for absent features. See ADR 002 for the planned
polymorphism strategy.

## Known leak

Diagnostic offsets are UTF-16 code units, a hosting artifact of JavaScript
strings (ADR 004).
