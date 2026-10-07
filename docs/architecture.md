# Compiler architecture

Five layers, each named for what would make it change (ADR 004, design in
docs/plans/2026-10-07-five-layers-design.md). Imports run only to the same or
an earlier layer; scripts/structure.mjs enforces it from `purs graph`.

| Layer | Modules (src/) | Role |
|---|---|---|
| Domain | Syntax, Resolved, Problem, Host, IR.Internal | syntax trees, spans, `Ty`, resolved syntax, checked IR, `Problem` data, capability-port types |
| Features | Resolve, Resolve.{Expression,Types,Pattern,Repeated}, Check, Check.{Match,Signature,Usefulness,Coverage} | resolution, checking, coverage; report `Problem` data, never text |
| Format | Lex, Parse, Parse.*, Stack, Go, Go.{Data,Match,Compare,Show,Usage}, Diagnostic, Wire, Arguments | text in (tokens, parser, reserved words, uppercase rule); Go out; diagnostic text, `E_*` names, wire records, usage text |
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

- **Resolve** has two type passes (register names, assign TypeId/CtorId in
  declaration order; then resolve field and signature types) so mutual
  recursion works. Functions and constructors share one global table. LocalIds
  number parameters, then binders in source pre-order.
- **Type table.** `TypeInfo {name, ctors, span}` and `CtorInfo {name, owner,
  fields, span}` travel with the program. Names appear only in messages, never
  in Go.
- **Check** produces checked IR (`Construct CtorId`, `Match`, `Pattern`) and is
  the only producer of `CheckedProgram`. It reports E_INTERNAL for invalid
  local/function/type indices; its resolved-syntax input is a trusted phase
  interface, not a hostile-IR validator.
- **Coverage** (Features.Check.Coverage, Usefulness, Signature) runs after the
  whole program type-checks: inhabitedness least fixed point, Maranget
  usefulness, canonical witness. Type errors in later functions take
  precedence over coverage errors.
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
`bootstrap/shapes.go`, `bootstrap/tree.go` snapshots). Int is int32 with wrapping addition.
Generated code never dereferences nil unguarded (ADR 003). Generated Go is
canonical emitter output; gofmt copies are presentation only.

Lexing and declaration parsing are index-based `tailRecM` loops
(Control.Monad.Rec.Class is allowlisted), so source length alone does not
overflow the stack; deep nesting still does (BACKLOG E002).

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
