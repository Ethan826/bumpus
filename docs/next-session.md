# Continue after T001 (batched Go builds in tests)

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
1. P001 (rank-1 polymorphism; order approved by the user 2026-10-07):
   design first, then plan, then implementation on its own branch.

Open items: E002 remainder (per-reference name lookups, quadratic coverage
in arms, quadratic inhabitation in chain length, quadratic binder
duplicates), F001-F003, F005-F007, E001, E003, E004, O001, H001,
A002, A004, A005.
