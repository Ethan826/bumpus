# Continue FN001 (Tasks 1-6 and 8 done on branch fn001)

Workspace: branch fn001 in /Users/ethan/Desktop/gofuncyourself/.worktrees/fn001
(main at 2a61a2b holds the approved plan; P001 merged at dcb40fb). Read
AGENTS.md, README.md, docs/plans/2026-10-08-functions-design.md (§13 is
the adopted lowering convention, the scale rule and Task 1-6
clarifications), docs/plans/2026-10-08-functions-plan.md (status line and
ticked steps), the FN001 entries in docs/progress.md, docs/findings.md,
ADRs 006-007 and BACKLOG.md. The uncommitted .vscode/settings.json change
on main predates this work. Nothing is pushed.

State (2026-10-09, fn001 at 9563aa6): FN001 Tasks 1-6 and 8 are done,
each implemented by a fresh subagent and reviewed by another (Task 8 was
checked by the controller only, to save usage), plus T003 (ladder 1.37×
faster; accepted). `rm -rf output && npm run verify` exits 0: 533
parallel tests, 12 serial tests (`test/*.serial.test.mjs`, run after the
parallel phase), twelve regression proofs
(.build/fn001-task8-verify.log). The 20,000-parameter milestone
(`node scripts/fn-milestone.mjs`, not in verify) passed all 11 programs,
largest go build 13.7 s against 100 s (.build/fn001-task8-milestone.log).
Tools: scripts/stage-probe.mjs (Task 1), scripts/ladder-profile.mjs
(T003), scripts/differential.mjs (compare two compiler builds; use for
behavior-preserving changes).

Next steps, in order:
1. FN001 Task 7: extend the independent reference interpreter
   (test/poly-oracle.mjs, poly-parse.mjs) with closures, staged
   application by declared arity, constructor values and left-first
   pipes; generated higher-order programs compared against Go.
2. FN001 Task 9: regression rows (six planned plus four promoted
   mutants, 22 proofs), ADR 008, language.md, architecture, README.
   Also close the gap Task 8 Step 2 found: restoring derived Eq/Ord on
   Domain.Type.Ty is caught by no test (add a bounded test that compares
   long source arrows, e.g. unifying two 20,000-parameter written
   signatures), and run the plan's "nested closures" mutant.
3. Whole-branch review, then ask the user about merging fn001 into main.
Open items to keep in view: BACKLOG T003 (timing headroom), T002
(concurrent test runs share .build/go-batches), G002 (recover ~24
nesting levels lost in Task 3's parser), G003 (long operator chains
become one Go expression; 20,000-term bodies exhaust Go's memory), an
unidentified failing test in one differential harvest run (progress,
"Differential harvest failure"), and FN001 before C001, R001 and FX001
(review C001/R001 jointly; decide whether instances are ordinary
records).

Long-term discussion is recorded in plans/2026-10-08-language-direction.md:
row/service architecture, explicit effects design (FX001), inspectable
lowered IR (L001), and future target evaluation (J001). These do not
authorize new implementation.

Open items: E002 remainder, E006-E011 (P001 follow-ups: stack margin,
exponential type size, Expand keys, lowercase-type hint, mismatch `_`,
near-limit elision), F001-F003, F005-F007, E001, E003, E004, O001, H001,
A002, A004, A005; design follow-ups FN001, FX001, L001, J001 and D001.
