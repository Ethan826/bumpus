# Finish P001 and prepare FN001

Workspace: /Users/ethan/Desktop/gofuncyourself, branch main (T001 merged
2026-10-08 at 4230eb9, after E005 at 09f3071 and G001 at 44a735b; history
was rewritten by the user to shift commit times and is the history to
keep; origin/main is the remote). Read AGENTS.md, README.md,
docs/plans/bootstrap.md, docs/progress.md, docs/findings.md,
docs/engineering.md, ADRs 001-007 and BACKLOG.md. The uncommitted
.vscode/settings.json change predates this work.

State: A003, G001, E005 and T001 are Done and merged. P001 (rank-1
polymorphism) is implemented on branch p001 in .worktrees/p001, Tasks 1-9
complete with per-task reviews, and the final whole-branch review's
findings are fixed; it is not merged. On p001,
`rm -rf output && npm run verify` exits 0 with 318 tests and twelve
regression proofs (docs/progress.md, `P001 final review fixes`;
.build/p001-final-fix-verify.log).
Decisions: docs/adr/007-specialization.md; execution ledger with rulings
R1-R20: .worktrees/p001/.superpowers/sdd/2026-10-08-polymorphism-plan/
progress.md.

Next steps, in order:
1. Ask the user for approval to merge p001 into main (final review
   fixes done). Do not merge or push without it.
2. FN001 (first-class functions, lambdas, closures). Before any design
   decision, discuss the proposed currying direction with the user (its
   BACKLOG entry records it as not settled). FN001 precedes C001, R001 and
   FX001; review C001/R001 jointly and decide whether instances are
   ordinary records.

Long-term discussion is recorded in plans/2026-10-08-language-direction.md:
row/service architecture, explicit effects design (FX001), inspectable
lowered IR (L001), and future target evaluation (J001). These do not
authorize new implementation.

Open items: E002 remainder, E006-E011 (P001 follow-ups: stack margin,
exponential type size, Expand keys, lowercase-type hint, mismatch `_`,
near-limit elision), F001-F003, F005-F007, E001, E003, E004, O001, H001,
A002, A004, A005; design follow-ups FN001, FX001, L001, J001 and D001.
