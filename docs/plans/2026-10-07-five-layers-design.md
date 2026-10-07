# Five layers: design

Status: approved by the user in conversation, 2026-10-07. Nothing here is
implemented yet. It is executed as Tasks 5–7 of
`docs/plans/2026-10-07-closed-adts-plan.md`.

The source is MileAhead's `AGENTS.md`, "Layers, and where PureScript stops"
and "Dependencies are values, not type classes" (~/Desktop/trailmapper,
read-only). Ideas are adopted; no code or prose is copied. The bootstrap
imported only MileAhead's enforcement mechanics, the import allowlist and
the private-constructor subtree. It did not import the layer model itself.

## The rule

**Every layer is named for what would make it change.** Imports run one way
down this list: a module may import its own layer and the layers above it.

| Layer | Changes when… | Holds |
|---|---|---|
| Domain | the language definition changes | syntax trees, spans, `Ty`, resolved syntax, checked IR, the structured `Diagnostic`, capability-port types |
| Features | compiler decisions change | resolution, checking, coverage; emits structured diagnostics, never text |
| Format | a foreign text format changes | source text in (lexer, parser, tokens, reserved words, uppercase rule); Go out (`Format.Go`: Go representation and text); diagnostic text, witnesses, `E_*` names, wire records |
| Runtime | Node, the OS or the Go toolchain changes | port implementations: filesystem and child processes; the only FFI |
| Program | the wiring changes | the pure `compile` pipeline, commands over ports, `Main` |

Domain, Features and Format are pure. They may not import `Effect`, any FFI,
or libraries outside the core allowlist. Runtime and Program hold the
effects. Two existing private-subtree rules continue:

- Only `Features.Check*` and `Format.Go*` import `Domain.IR.Internal`.
- Only the checker produces `CheckedProgram`.

`Shell` disappears as a name; it names a position, not a reason to change.

## Evaluation against four changes (why the layers look like this)

1. **Bumpus syntax changes.** Only Format changes. This requires structured
   diagnostics: Features reports `TypeMismatch { expected, found }` with
   type names as data, and `NonExhaustive witness` with the witness as a
   value. Format renders the text (`Expected Int, found Bool`,
   `Cons(_, Nil)`) and the `E_*` names. This is MileAhead's #147 lesson:
   the core returns a reading, and renderers write text. Tokens, reserved
   words and `isUpper` are lexical, so they live in Format.
2. **Target language changes.** Only Format (a new printer) and Runtime
   (the toolchain) change. Go representation decisions (tag layout, pointer
   fields, nil guards, depth naming, the wrap-in-a-function trick for
   `if`/`match`, `_ = binder`) are Go-specific, so they belong to
   `Format.Go`, as SVG label offsets belong to `Format.Svg`. A
   target-neutral `Features.Lower` is deferred until decision-tree match
   compilation gives it a target-neutral job.
3. **Test doubles.** Domain declares capability ports as plain records
   over an abstract monad `m`, so Domain needs no `Effect`. Runtime
   implements them. `Program.Command` runs emit/build/run against any port
   record. Tests pass fake records and assert the exit status and wire
   output with no processes and no PATH tricks. Ports live in Domain
   because of import order: commands combine Format and Features, so they
   cannot live in Features, and Runtime must see the port types.
4. **Compiler hosting changes** (native Stage 1, browser, LSP). Only
   Runtime and Program change. One leak is recorded rather than fixed:
   diagnostic positions are UTF-16 code units, a JS-string artifact in the
   language contract. A Go-hosted Stage 1 must reproduce them, or an ADR
   must change the contract.

## Invariants of the refactor

- Behavior is unchanged: `bootstrap/answer.go` and `bootstrap/shapes.go`
  stay byte-identical; every diagnostic code, span and message stays the
  same; CLI exit statuses and wire fields stay the same.
- Tests change only their import paths and the module names inside
  structure-gate fixtures. Existing assertions keep their meaning and count.
- JSON serialization stays in Runtime (`JSON.stringify`), because it is the
  host's technology. Format builds the plain wire records it serializes, so
  no PureScript-shaped value crosses the boundary.
