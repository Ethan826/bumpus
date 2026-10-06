# Installed planning workflow

Installed 2026-10-07 after explicit user steering: install skills first,
backport in-flight work second, then plan execution together.

## Installation and provenance

Superpowers is installed project-locally for Codex in `.agents/skills`.
All 15 skills were included so relative support-skill and script references
resolve. Primary skills: writing-plans and executing-plans. Installing the
bundle does not initiate feature execution, reviews, commits, or publication.
Skills are available to discovery on the next turn; local files can be read now.

Pinned upstream revision: `8ca22dba9a94f28898bbce59f2537ff4d87c747d`.
`skills-lock.json` records the revision and each skill's computed hash.
Upstream MIT notice: `.agents/skills/SUPERPOWERS-LICENSE`.

Installation command (from repository root):

```sh
bunx skills add https://github.com/obra/superpowers/tree/8ca22dba9a94f28898bbce59f2537ff4d87c747d/skills --skill '*' --agent codex -y
```

`bunx skills list --agent codex --json` confirmed 15 project-scoped skills.
The CLI version itself was not pinned. The skill source revision is pinned;
review any future updates before adopting them.

## Backport and instruction precedence

The current unfinished audit is expressed in
[the migrated plan](plans/2026-10-07-bootstrap-audit.md).
[The migration ledger](plans/bootstrap-migration-ledger.md) maps old tasks
to completed evidence and remaining tasks. Historical completed work stays
complete; no retroactive test runs, commits, or RED/GREEN history are invented.
`docs/plans/bootstrap.md` remains the historical bootstrap status index.

Reviewed installed writing-plans, executing-plans, using-git-worktrees,
verification-before-completion, and task/workspace helper sources for this
migration. Load TDD and review guidance before actual implementation.
Writing-plans at this revision requires self-review, not a plan subagent.
Executing-plans uses task briefs, a plan-scoped ledger, commit ranges, TDD,
and one fresh reviewer at the end when tools are available.

Project/user instructions take precedence: local tracking, Stage 0
preservation, no publication or push, no unrequested reference writes.
Documentation migration does not require fabricated behavior tests. Any code
fix found during the later audit requires a regression proven with the defect
restored in isolation. Keep durable evidence in docs even if scratch is deleted.

## Execution setup

User approved inline execution, a reviewed local checkpoint and isolation.
Baseline 9624bec on main preserves the compiler/docs/tests and installed skills.
Temporary IDE port and .worktrees are ignored; no cache was committed.
Audit ran in .worktrees/bootstrap-audit on audit/bootstrap-docs. User approved
the completed local merge into main; merged verification passed. The merged
worktree/branch were removed and raw evidence is in .build/merged-audit-evidence.
The previous unborn-Git prerequisite W001 is resolved; real BASE/HEAD values
are available. Task helpers and the final review package use that history.
Worktree setup copied ignored Spago caches and built compiler output from
scratch. No npm install was required because no local npm dependencies exist.

For inline execution, resolve the plan workspace with
`.agents/skills/subagent-driven-development/scripts/sdd-workspace`, seed its
ledger from the durable migration ledger, and then use task-start/task-done.
Keep the historical task mapping separate from new completion records.
For subagent execution, use that skill's corresponding setup and review gates.
The migrated plan was reviewed and inline execution authorized before work.

## Earlier research

Superpowers and planning-with-files were researched before this installation.
planning-with-files remains uninstalled; existing local plan/findings/progress
artifacts provide continuity. Earlier npm DNS failures were historical;
the skills installation succeeded with escalated network access today.
Fresh compiler-tool installation remains unverified (F001).
