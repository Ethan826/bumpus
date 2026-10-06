# Bootstrap Audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish the existing Stage 0 documentation/style audit and handoff.

**Architecture:** Preserve the pure compiler and explicit Shell boundary.
Audit documented contracts against source and actual CLI evidence. Keep the
historical checkpoint separate from newly verified completion records.

**Tech Stack:** PureScript 0.15.16, Spago 1.0.4, purs-tidy 0.11.1,
Go 1.26.4 (tested), Node >=22.5.0; installed pinned Superpowers skills.

**Spec:** `AGENTS.md`, `docs/engineering.md`, `docs/language.md`,
`docs/architecture.md`, `docs/bootstrap.md`, and original
`docs/plans/bootstrap.md` acceptance criteria.

## Global Constraints

- Finish the current vertical slice before adding language features.
- Run `npm run verify` before reporting completion.
- Never disable checks, suppress warnings, skip tests, or weaken assertions.
- Demonstrate regression tests failing with the corresponding defect restored,
  in an isolated copy.
- Keep Sprig.* pure. Effects and foreign imports belong in Shell.*.
- Preserve Stage 0 sources, locks, grammar, tests and build instructions.
- Follow every AGENTS.md style rule; 250 physical lines maximum applies to
  maintained source/tests/tooling. Installed third-party skills are upstream
  material, not independently maintained Sprig code; keep them unmodified.
- Keep tracking local; no external publication, remote issues, or pushing.
- Reference projects stay read-only; preserve the unapplied MileAhead patch.

## Review Focus

- README setup claims must distinguish cached success from fresh online setup.
- Architecture claims must match import gates, including IR constructor access.
- Manual complexity/naming/order rules must not be described as automated.
- Generated/example snapshots must not be described as compiler bootstrap seeds.
- Handoff must preserve pending work and the blocked external edit accurately.

## Execution Gate

User requested installation and backport first, then joint execution planning.
This plan has not been executed. See `docs/planning-skills.md` for the unborn
Git prerequisite and `bootstrap-migration-ledger.md` for historical evidence.
Agree execution method and checkpoint/isolation before using task-start.
No baseline commit, worktree, or review range has been invented.

### Task 1: Audit contracts and source style

**Files:**
- Review: `src/**/*.purs`, `src/Shell/CLI.js`, `test/*.mjs`,
  `scripts/*.mjs`, `tools/style/src/**/*.purs`, `bootstrap/answer.go`.
- Modify as findings require: `README.md`, `docs/language.md`,
  `docs/architecture.md`, `docs/engineering.md`, `docs/bootstrap.md`,
  `docs/provenance.md`, `BACKLOG.md`, `docs/findings.md`, `docs/progress.md`.
- Tests for any defect: the existing owning file in `test/` plus an isolated
  regression witness; specify exact assertion after identifying the defect.

**Interfaces:**
- Consumes: unchanged Stage 0 CLI emit/build/run and documented contracts.
- Produces: audited claim-to-evidence table in `docs/progress.md`, with each
  Review Focus item covered; all findings fixed or locally tracked.

- [x] **Step 1: Compare claims and manual conventions with their sources.**
  Read maintained source and owning tests. Record each Review Focus item with
  file references and observed behavior. Do not add tests that mirror code.
- [x] **Step 2: Resolve each finding with the smallest justified change.**
  Fix prose directly. For behavior defects, first specify and observe an exact
  failing regression, then fix and prove sensitivity with the defect restored
  in an isolated copy. Record RED/GREEN commands and results. If a larger fix
  exceeds this audit, add a specific BACKLOG item with evidence and next action.
- [x] **Step 3: Verify the audit changes.**
  Run: `npm run verify`.
  Expected: strict/pedantic builds, style/architecture gates, all tests pass
  with zero skips, isolated regression proof succeeds. Baseline is 19 tests;
  any count change must be explained by real new regressions.
- [x] **Step 4: Record task completion and checkpoint locally.**
  Use the selected executor's ledger/commit workflow after execution setup.
  Preserve durable claim evidence; no publication or push.

### Task 2: Close the audit handoff

**Files:**
- Modify: `docs/plans/bootstrap.md`, `docs/progress.md`, `docs/findings.md`,
  `docs/next-session.md`, `BACKLOG.md`, and affected ADRs/provenance only when
  their claims or decisions change.

**Interfaces:**
- Consumes: Task 1 audited claim-to-evidence table and verification results.
- Produces: consistent local handoff marking original tasks 7/8 complete only
  when justified; A001 remains a separate, unimplemented milestone.

- [ ] **Step 1: Synchronize status and limitations.**
  Check V001, original tasks 7/8, next-session and progress for agreement.
  Preserve F001/F002 and any newly observed failures. No ADT implementation
  or ADT plan is part of this audit.
- [ ] **Step 2: Run final verification after the documentation changes.**
  Run: `npm run verify`.
  Expected: complete exit 0; record command, test count, regression result,
  date and actual log path. Distinguish proposed behavior from verified work.
- [ ] **Step 3: Complete the chosen executor's final review and handoff.**
  Review the whole change with all five Review Focus items. Follow its review
  gates; retain durable rulings/evidence before scratch cleanup. Report the
  unresolved limitations and leave future ADTs for a later bounded plan.

## Plan Self-Review (migration only)

All five Review Focus items belong to Task 1's evidence table; Task 2 checks
status consistency. Task 2 consumes only that table and verification results.
Documentation-only changes need no synthetic RED step; behavioral fixes need
exact regressions once identified. Historical implementation tasks are not
re-executed. This plan covers remaining original tasks 7/8, not future features.
