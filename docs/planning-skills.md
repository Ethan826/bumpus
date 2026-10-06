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

## Execution preparation, still pending

No execution mode has been selected. Do not run migrated audit tasks yet.
Git is unborn: `git rev-parse --verify HEAD` reported no revision.
All existing project files are untracked. Helpers that resolve BASE or review
commit ranges cannot run correctly until a real baseline commit exists.
Before execution, agree the checkpoint/branch or worktree approach and review
exact files to preserve. Do not stage all files indiscriminately or invent BASE.
Load using-git-worktrees at that time; preserve the current in-flight files.

For inline execution, resolve the plan workspace with
`.agents/skills/subagent-driven-development/scripts/sdd-workspace`, seed its
ledger from the durable migration ledger, and then use task-start/task-done.
Keep the historical task mapping separate from new completion records.
For subagent execution, use that skill's corresponding setup and review gates.
Both methods require reviewing the migrated plan before implementation.

## Earlier research

Superpowers and planning-with-files were researched before this installation.
planning-with-files remains uninstalled; existing local plan/findings/progress
artifacts provide continuity. Earlier npm DNS failures were historical;
the skills installation succeeded with escalated network access today.
Fresh compiler-tool installation remains unverified (F001).
