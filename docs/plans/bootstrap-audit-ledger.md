# SDD ledger — plan: docs/plans/2026-10-07-bootstrap-audit.md

User approved inline execution, baseline checkpoint and isolated worktree.
Baseline: 9624bec; audit/bootstrap-docs; main is the base branch.
Historical tasks 1–6 remain complete; see bootstrap-migration-ledger.md.
Clean-output baseline: npm run verify → 19/19 and regression proof, exit 0.
Raw baseline: .build/audit-baseline.log (269 modules compiled).
Todo: Task 1 in progress; Task 2 pending; final review pending.
Pre-flight: Task 1 produces a claim-to-evidence table; Task 2 consumes that
same table and verification results. No interface conflict.
Ruling: No npm install during worktree setup — package.json has no local npm
dependencies; use pinned PATH tools and copied ignored Spago caches. Cost if
wrong: a missing build prerequisite will fail full verification.
Ruling: Style-only refactors preserve behavior and use existing tests before
and after, plus the existing isolated mutation proof. No fabricated RED test
for prose or helper extraction. Behavioral defects require exact RED/GREEN
and isolated restoration. Cost if wrong: existing suite may miss a refactor
regression; the fresh reviewer inspects changed expressions.

Task 1: build failed on accidental IResolved import; failed log retained.
Root cause: substring rename touched IR. Isolated copied defect reproduced
ModuleNotFound; helper stderr-only assertion failed because diagnostic was
on stdout. Fix applied only after inspecting combined evidence. No task
completion recorded on failure.

Ruling: Retain codeName as a ten-arm exhaustive wire-tag mapping despite
the eight-branch review target; E003 records the exception. Cost if wrong:
future diagnostics could make that dispatch harder to review; reassess on
growth with exact tag tests.
Task 1 changes verified before commit: npm run verify → 19/19, regression
proof, zero warnings/errors; .build/audit-task-1-green.log.
Task 1: complete (commits 9624bec..4410609, tests: npm run verify → Verified compiler, gates, executable programs, rejection diagnostics, properties, and regression proof.)

Task 2 implementation verified before review: npm run verify → 19/19 and
regression proof, .build/audit-task-2-pre-review.log.
Ruling: Task 2 Step 3 includes final executor review; do that one review
after committing its implemented handoff, before recording Task 2 complete.
This keeps task completion truthful. Cost if wrong: completion bookkeeping
order differs from the generic executor loop, not the review coverage.
Todo: Task 1 complete; Task 2 final review pending.

Final review: fresh reviewer, 9624bec..56cbde1; no Critical/Important findings.
Final: minor (deferred): compiler.test.mjs:84 and style.test.mjs:21–22 have
inaccurate pre-existing titles; narrow descriptions without weakening assertions
(E004). Manual repeated CLI emissions agree with each other and snapshot.
Final: Ruling: ADTs/polymorphism/self-hosting stay future milestones — bounded
audit does not implement them — cost if wrong: desired feature delivery waits.
Final: Ruling: Forged resolved entry/table validation stays outside the trusted
phase contract, accurately documented — cost if wrong: unsupported direct API
inputs can produce invalid Go; future external IR ingress needs validation.
Final: Ruling: Large/deep input work stays E002 — no resource guarantee claimed
for small initial programs — cost if wrong: oversized input may exhaust resources.
Final: Ruling: Fresh install/cross-platform work stays F001 — cached macOS
verification cannot prove those setups — cost if wrong: a new host may not build.
Final: Ruling: External patch stays unapplied under F002 — prior approval
rejection remains binding — cost if wrong: MileAhead guidance remains unchanged.
Todo: Task 1 complete; Task 2 closure verification pending; review complete.

Task 2 Step 3 done: one fresh reviewer, no blockers; E004 deferred.
Final closure verify: npm run verify → exit 0,19/19,zero skips,regression
proof,zero warnings/errors; .build/audit-final.log.
Task 2: complete (commits 4410609..f27b499, tests: npm run verify → Verified compiler, gates, executable programs, rejection diagnostics, properties, and regression proof.)

Todo: Task 1 complete; Task 2 complete; fresh review complete.
Integration: pending user choice; main retains baseline; audit branch/worktree
remain preserved. No push or publication.
