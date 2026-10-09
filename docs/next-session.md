# Continue FN001 (Tasks 1-9 done on branch fn001)

Workspace: branch fn001 in /Users/ethan/Desktop/gofuncyourself/.worktrees/fn001
(main at 2a61a2b holds the approved plan; P001 merged at dcb40fb). Read
AGENTS.md, README.md, docs/adr/008-functions.md (the FN001 decision
record), docs/plans/2026-10-08-functions-design.md (§13: the lowering
convention, scale rule and clarifications),
docs/plans/2026-10-08-functions-plan.md (all tasks ticked), the FN001
entries in docs/progress.md, docs/findings.md and BACKLOG.md. The
uncommitted .vscode/settings.json change on main predates this work.
Nothing is pushed.

State (2026-10-09): FN001 is complete on fn001. Task 9 added ten
regression rows (twenty-two proofs; scripts/regression-fn.mjs,
test/regression-fn.mjs), ADR 008, and the language, architecture,
engineering, README and BACKLOG updates; its verify result is in
docs/progress.md "FN001 Task 9". Tools: scripts/stage-probe.mjs (Task 1),
scripts/ladder-profile.mjs (T003), scripts/differential.mjs (compare two
compiler builds), scripts/fn-milestone.mjs (20,000-parameter tier, not in
verify), `node scripts/regression.mjs name…` (prove chosen rows only).

Next steps, in order:
1. Whole-branch review of fn001 against main (design, plan, ADR 008,
   every task's evidence), fixing findings in fn001.
2. Ask the user whether to merge fn001 into main.

Open items to keep in view: BACKLOG T003 (timing headroom), T002
(concurrent test runs share .build/go-batches), G002 (recover ~24
nesting levels lost in Task 3's parser), G003 (long operator chains
become one Go expression; 20,000-term bodies exhaust Go's memory), an
unidentified failing test in one differential harvest run (progress,
"Differential harvest failure"), and FN001 before C001, R001 and FX001
(review C001/R001 jointly; decide whether instances are ordinary
records), and FN001's follow-ups FN002-FN005 (let binding, placeholder
application, saturation optimization, I001 wrapper arity).

Long-term discussion is recorded in plans/2026-10-08-language-direction.md:
row/service architecture, explicit effects design (FX001), inspectable
lowered IR (L001), and future target evaluation (J001). These do not
authorize new implementation.

Open items: E002 remainder, E006-E011 (P001 follow-ups: stack margin,
exponential type size, Expand keys, lowercase-type hint, mismatch `_`,
near-limit elision), F001-F003, F005-F007, E001, E003, E004, O001, H001,
A002, A004, A005; design follow-ups FN001, FX001, L001, J001 and D001.
