# Continue after A003 implementation (comparison and printing)

Workspace: /Users/ethan/Desktop/gofuncyourself/.worktrees/a003, branch a003
(main checkout untouched). Read AGENTS.md, README.md, docs/plans/bootstrap.md,
docs/progress.md, docs/findings.md, docs/engineering.md, ADRs 001-005 and
BACKLOG.md. The language is now named Bumpus (R002).

State: A003 Tasks 1, 2, 3, 3a (rename), 3b (stack-safe lexing) and 4
(documentation) are implemented and committed on a003. `rm -rf output && npm
run verify` exits 0 (17 files, 96 tests, 0 skips, six regression proofs).
A003 is In review, not Done. Nothing has been pushed. The uncommitted
.vscode/settings.json change in the main checkout predates this work.

Next steps, in order:
1. Final whole-branch review of a003 (plan Task 4 Step 5): fix every finding,
   each behavioral fix with a test seen failing first, record them in
   docs/plans/adt-printing-review.md, rerun `npm run verify`, then mark A003
   Done in BACKLOG.md and the plan status.
2. Merging a003 into main needs explicit user approval.
3. Then pick the next main item with the user (P001, A002, I001, S001).

Open items: E002 (deep nesting overflows the stack; `uniqueTypes` and
`uniqueCtors` are quadratic), T001 (build Go once per test file), F001,
F002, F003, F005, E001, E003, E004, A002, A004, A005.
