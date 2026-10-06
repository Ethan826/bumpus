# ADR 004: five layers named for what changes

Accepted and implemented 2026-10-07 (A001 Tasks 5-7). Binding spec:
docs/plans/2026-10-07-five-layers-design.md. Conceptual source: MileAhead
AGENTS.md (see docs/provenance.md); no code or prose copied.

## The layer rule

Domain, Features, Format, Runtime, Program. A module may import its own layer
and the layers before it in that list. Each layer is named for what would make
it change: Domain (the language definition), Features (compiler decisions),
Format (a foreign text format), Runtime (Node, the OS, the Go toolchain),
Program (wiring). Domain, Features and Format are pure and may import only the
core library allowlist. Only `Features.Check*` and `Format.Go*` import
`Domain.IR.Internal`. `Shell` was dropped as a name: it named a position, not
a reason to change. Automated by scripts/structure.mjs and the layer-gate test in
test/structure.test.mjs (ten rejected import pairs, including
`Program.Command` importing Effect or Runtime, and accepted cases).

## Four-change evaluation

1. Syntax changes: only Format changes, which requires structured diagnostics.
2. Target language changes: Format (printer) and Runtime (toolchain).
3. Test doubles: ports as records over an abstract `m`, fakes in tests.
4. Hosting changes (native Stage 1, browser, LSP): Runtime and Program.

## Decisions

- **Ports over abstract `m`.** `Domain.Host` declares readSource, writeText,
  buildExecutable and runProgram as records, so Domain needs no `Effect`.
  `Program.Command` runs over any such record; test/program.test.mjs drives it
  with fakes (nine cases, no process, no PATH tricks).
- **Structured diagnostics.** Features return `Domain.Problem` data
  (`TypeMismatch TypeName TypeName`, `NonExhaustive Witness`, ...); Format
  renders text, `E_*` names and wire records. Characterized by
  test/diagnostics.test.mjs (every family keeps code, span and text).
  Impossible states (an invalid TypeId) are E_INTERNAL, never a silent default.
- **Go decisions live in Format.Go.** Tag layout, pointer fields, nil guards,
  depth naming and the IIFE wrapping are Go-specific. A target-neutral
  `Features.Lower` is deferred until decision-tree compilation (A002) gives it
  a target-neutral job; adding it now would be a pass-through stage.
- **Known leak: UTF-16 offsets.** Diagnostic positions are UTF-16 code units,
  a JS-string artifact in the language contract (docs/language.md). A
  Go-hosted Stage 1 must reproduce them or a later ADR changes the contract.
- **Proposed, not verified:** the Format layer "changes only for text format"
  claim is a design argument; no second syntax or target exists to test it.
- **Known gap:** `E_USAGE`, `E_IO` and `E_TOOL` are string literals in
  `Format.Wire`, not an ADT (BACKLOG A005).
