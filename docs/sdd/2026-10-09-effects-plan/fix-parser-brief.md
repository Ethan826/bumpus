# Fix brief: `with` row dropped inside `Handler(...)` (FX001 Task 5 defect)

## Defect (reproduced 2026-10-09)
The type parser silently discards a `with` row written inside a handler type:
`fn t(h: Handler(Clock with pure)): Int = 0;` parses the parameter type as
`NamedRef "Handler" [TypeArgument (NamedRef "Clock" [])]` — the `with pure`
is gone, so Resolve gives the handler the signature's ambient row instead of
the closed row. Same for `Handler(Tick with Log)`. Spec
(docs/plans/2026-10-09-effects-design.md §1): "`Handler(Clock with Log)` is a
Clock handler whose clauses perform Log; bare `Handler(Clock)` uses the
ambient row in a signature and is `pure` in a field or operation type."

Cause (src/Format/Parse/HandlerType.purs, src/Format/Parse/Type.purs):
HandlerType.operand parses each argument with `nested inner`, where `inner`
is `typeRef = typeOf <$> typeAndRow`. typeAndRow's `segment` consumes an
optional `with` row after ANY operand (`optionalOn "with" (rowRef inner)`),
and `combined` keeps that row only as the chain's row; `typeRef` then drops
it (`typeOf found = found.ty`). So HandlerType's own
`optionalOn "with" (rowRef parser)` never sees the `with`.

Check also whether the same silent drop affects any other position where a
non-arrow type is followed by `with` and parsed via `typeRef` (e.g. a
parameter `x: Int with Log`, a type argument `List(Int with Log)`, a field).
A written row must never be silently discarded: it is either attached where
the spec gives it meaning or rejected with an E_SYNTAX diagnostic. If you
find other silent drops, decide per the spec; if the spec gives no meaning,
reject with a clear E_SYNTAX message at the `with` (or the row) and report
the exact text you chose.

## Requirements
- `Handler(L with R)` in signatures, fields and operation types parses to
  `THandlerRef` with its row; `Handler(L)` unchanged.
- No change to any existing diagnostic text/span or accepted program
  (bootstrap/*.go snapshots byte-identical).
- TDD: first add failing tests (a new file test/fx-handler-type.test.mjs, or
  extend test/fx-handler-check.test.mjs if it stays under 250 lines), see
  them fail, then fix. Cover at least: `Handler(Clock with pure)` parameter
  accepts a pure handler argument and rejects passing it where a clause
  result needs pure-vs-ambient (use the repro below); `Handler(Clock with
  Log)` keeps Log (a handler whose clauses perform Log is accepted, one
  given a `with pure` handler type as parameter performing Log rejected);
  parse shape (THandlerRef) via Format.Parse directly.
  Repro that must CHECK OK after the fix:
  `effect Clock { fn now(): Int; }; effect Tick { fn tick(): Handler(Clock); };
   fn t(h: Handler(Clock with pure)): Handler(Tick with pure) =
   handler Tick { tick() => h }; fn main(): Int = 0;`
- Engineering rules: read AGENTS.md (where not let-in, no anonymous lambdas,
  named helpers, 80 cols, purs-tidy, 250-line files, per-declaration budgets).
