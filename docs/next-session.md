# Continuation after installing Superpowers

Continue Sprig in `/Users/ethan/Desktop/gofuncyourself`.

Read AGENTS.md, README.md, docs/plans/bootstrap.md, docs/progress.md,
docs/findings.md, docs/engineering.md, docs/provenance.md, ADRs, BACKLOG.md,
and docs/planning-skills.md. Preserve the completed Stage 0 compiler.

Latest user steering overrides the former reset prompt: **install skills,
backport in-flight work, then plan the run together**. Installation and plan
migration are done; audit execution has not started. Do not automatically
resume the audit or plan/implement ADTs.

Superpowers: 15 project-local skills in `.agents/skills`, pinned to
`8ca22dba9a94f28898bbce59f2537ff4d87c747d`; skills-lock.json records hashes.
Read installed writing-plans/executing-plans and relevant support skills.
Project/user instructions outrank upstream defaults.

Review docs/plans/2026-10-07-bootstrap-audit.md and its companion
bootstrap-migration-ledger.md with the user. Agree execution approach and
checkpoint/isolation. Git has no HEAD; task-start/task-done and review ranges
need a real baseline (W001). No commits or pushes have been made.

Compiler at prior checkpoint: typed first-order functions, Int/Bool, calls,
wrapping int32 addition and conditionals; deterministic Go, example prints 42.
Prior verification passed 19 tests plus an isolated regression mutation proof.
Consult docs/progress.md for any fresh installation/migration verification.
Do not invent historical TDD evidence or reimplement completed tasks.

MileAhead edit remains unapplied: docs/patches/mileahead-eliminators.patch.
Earlier automatic approval rejected the outside-workspace write. Preserve it;
no external write or publication is authorized by skill installation.

Finish the bounded audit when execution is agreed. Closed ADTs and exhaustive
matching require a separate later milestone; preserve Stage 0 throughout.
