# Continue after A003 (comparison and printing)

Workspace: /Users/ethan/Desktop/gofuncyourself/.worktrees/a003, branch a003
(main checkout untouched). Read AGENTS.md, README.md, docs/plans/bootstrap.md,
docs/progress.md, docs/findings.md, docs/engineering.md, ADRs 001-005 and
BACKLOG.md. The language is now named Bumpus (R002).

State: A003 Tasks 1, 2, 3, 3a (rename), 3b (stack-safe lexing), 4
(documentation) and the final whole-branch review fixes are committed on
a003. A003 is Done (docs/plans/adt-printing-review.md); `rm -rf output && npm
run verify` exits 0 (evidence in docs/progress.md `A003 execution`). Nothing
has been pushed. The uncommitted .vscode/settings.json change in the main
checkout predates this work.

Next steps, in order:
1. Merging a003 into main needs explicit user approval.
2. After the merge, G001 is next, before P001 and the rest (user decision
   2026-10-07): applicative parser combinators with committing LL(1) choice,
   `tailRecM`-based `many`/`sepBy` (fixes E002 breadth), one `spanned`
   combinator, Format.Parse.Pattern ported first, and resolver LocalId
   numbering threaded through an applicative state. It needs its own spec and
   plan; acceptance is in BACKLOG G001.
3. Then pick the next main item with the user (P001, A002, I001, S001).

Open items: E002 (deep nesting and long lists inside one declaration
overflow the stack; the CLI dies with a raw stack trace), T001 (build Go once
per test file), F001, F002, F003, F005, E001, E003, E004, A002, A004, A005.
