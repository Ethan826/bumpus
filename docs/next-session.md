# Continue P001 and preserve the language direction

Workspace: /Users/ethan/Desktop/gofuncyourself, branch main (T001 merged
2026-10-08 at 4230eb9, after E005 at 09f3071 and G001 at 44a735b; history was rewritten by the user to shift commit
times and is the history to keep; origin/main is the remote). Read
AGENTS.md, README.md, docs/plans/bootstrap.md, docs/progress.md,
docs/findings.md, docs/engineering.md, ADRs 001-006 and BACKLOG.md. The
uncommitted .vscode/settings.json change predates this work.

State: A003, G001, E005 and T001 are Done and merged. `rm -rf output && npm run verify`
exits 0 on main (162 tests, eight regression proofs; docs/progress.md).
Review records: docs/plans/adt-printing-review.md and
docs/plans/applicative-parser-review.md.

Next steps, in order:
1. P001: spec and corrected plan approved 2026-10-08; execution is
   subagent-driven on p001 in .worktrees/p001 (BACKLOG.md). Preserve that
   active work and read its current ledger before continuing.

Long-term discussion is recorded in
plans/2026-10-08-language-direction.md: row/service architecture, explicit
effects design (FX001), inspectable lowered IR (L001), and future target
evaluation (J001). These do not expand P001 or authorize new implementation.

Open items: E002 remainder (per-reference name lookups, quadratic coverage
in arms, quadratic inhabitation in chain length, quadratic binder
duplicates), F001-F003, F005-F007, E001, E003, E004, O001, H001,
A002, A004, A005; design follow-ups FX001, L001 and J001.
