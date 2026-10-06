# Working in Sprig

Read README.md, docs/plans/bootstrap.md, docs/progress.md, and docs/findings.md
before changing code. The language name is provisional. Finish the current
vertical slice before adding language features. Task tracking is local.

- Own every observed failure. Fix it or add a specific local BACKLOG.md item
  with evidence and a next action. Never hide a failure behind a rerun.
- Never disable checks, suppress warnings, skip tests, or weaken assertions
  to obtain green results. Demonstrate regression tests failing with the
  corresponding defect restored, in an isolated copy.
- Run `npm run verify` before reporting completion. Report what actually ran
  and distinguish verified behavior from proposed behavior.
- Keep Domain.*, Features.* and Format.* pure. Effects and foreign imports
  belong in Runtime.* and Program.*. Imports run only to the same or an
  earlier layer (Domain, Features, Format, Runtime, Program). Expected
  semantic failures are `Either Diagnostic`; error codes are an ADT.
- Parsing, resolved syntax, checked IR, and Go generation are distinct.
  Only checking and lowering (Features.Check*, Format.Go*) may import
  Domain.IR.Internal. Keep its
  constructors behind that enforced module boundary.
- Prefer `where`, never `let … in`. A `let` inside `do` may depend on an
  earlier bound value. Name transformations passed to map/traverse/eliminators
  in `where`; no anonymous lambdas. Use `maybe`/`maybe'`/`either` for their
  respective types, with named helpers even when an arm builds a record.
  Computed Maybe fallbacks use `maybe'` to preserve conditional evaluation.
- Branch work belongs in named helpers. Public semantic formulas deserve
  their own tests; private parsing plumbing need not become a public API.
- Maintained source, tests, and tooling: 250 physical lines maximum, roughly
  100-line target. Comments and blank lines count. Generated output, locks,
  data fixtures, and generated-Go snapshots are excluded; maintained code
  disguised as a fixture is not exempt.
- PureScript: pinned purs-tidy, Unicode punctuation, 80 columns, final newline.
  Types/instances, constants, public functions, then private functions.
  Use explicit names; conventional compiler names Expr, IR, Ty are allowed.
  Name numeric constants except 0, 1, 2 and test data. Aim for at most
  30 lines, 3 nested decisions, 8 active branches, and 8 where bindings per
  declaration; split responsibilities rather than enlarge budgets.
- Comments explain reasoning. Update docs/engineering.md when a rule changes
  and distinguish automated enforcement from review conventions.
- Keep plan status, evidence, findings, ADRs, and backlog current in the same
  change. A chat message is not a durable handoff. No external publication,
  remote issues, or pushing unless explicitly requested.
- Reference projects are read-only except the specifically requested
  MileAhead guidance update. No reference code has been licensed for reuse;
  implement independently and record conceptual influence in provenance.
