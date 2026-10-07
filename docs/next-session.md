# Continue G001 (applicative parser and nesting limit)

Workspace: /Users/ethan/Desktop/gofuncyourself. G001 work is on branch
g001 in the worktree .worktrees/g001 (main is at the A003 merge plus the
G001 spec and plan). Read AGENTS.md, README.md, docs/plans/bootstrap.md,
docs/progress.md, docs/findings.md, docs/engineering.md, ADRs 001-006 and
BACKLOG.md. Nothing has been pushed. The uncommitted .vscode/settings.json
change in the main checkout predates this work.

State: G001 Tasks 1-5 (with the inserted Task 4b) are committed on g001;
BACKLOG G001 is In review, not Done. Spec
docs/plans/2026-10-07-applicative-parser-design.md, plan
docs/plans/2026-10-07-applicative-parser-plan.md, evidence docs/progress.md
`G001 execution`, SDD ledger
.worktrees/g001/.superpowers/sdd/2026-10-07-applicative-parser-plan/.

Next steps, in order:
1. The controller's final whole-branch review of g001 (pending). Fix its
   findings on g001; G001 becomes Done only after it passes.
2. Merging g001 into main needs explicit user approval.
3. E005 (`go build` exponential in nested `match` closures) needs a user
   decision on priority and approach: lower each match to a named Go
   function, fold it into A002, or build with `-gcflags=-l`. BACKLOG E005
   lists the three options and the evidence; nothing is decided.
4. Then pick the next main item with the user (P001, A002, I001, S001).

Open items: E002 remainder (per-reference name lookups, quadratic coverage
in arms; depth beyond 128 is H001), E005, O001, H001, F006 (stale output of
deleted modules), T001, F001, F002, F003, F005, E001, E003, E004, A002,
A004, A005.
