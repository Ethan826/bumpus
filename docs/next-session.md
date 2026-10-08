# Continue after G001 (applicative parser and nesting limit)

Workspace: /Users/ethan/Desktop/gofuncyourself, branch main (G001 merged
2026-10-07 at 44a735b; history was rewritten by the user to shift commit
times and is the history to keep; origin/main is the remote). Read
AGENTS.md, README.md, docs/plans/bootstrap.md, docs/progress.md,
docs/findings.md, docs/engineering.md, ADRs 001-006 and BACKLOG.md. The
uncommitted .vscode/settings.json change predates this work.

State: A003 and G001 are Done and merged. `rm -rf output && npm run verify`
exits 0 on main (151 tests, seven regression proofs; docs/progress.md).
Review records: docs/plans/adt-printing-review.md and
docs/plans/applicative-parser-review.md.

Next steps, in order:
1. E005 (`go build` exponential in nested `match` closures) needs a user
   decision: lower each match to a named Go function (recommended), fold it
   into A002, or build with `-gcflags=-l`. BACKLOG E005 has the evidence.
2. Then pick the next main item with the user (P001, A002, I001, S001).

Open items: E002 remainder (per-reference name lookups, quadratic coverage
in arms, quadratic inhabitation in chain length, quadratic binder
duplicates), E005, F001-F003, F005-F007, E001, E003, E004, O001, H001,
T001, A002, A004, A005.
