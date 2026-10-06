# Stage 0 vertical slice implementation plan

Objective: a tiny language checked by a PureScript semantic core, emitting
ordinary Go that builds and runs. Do not attempt the full language now.
Last checkpoint: 2026-10-07. This preserves historical bootstrap status.

## Acceptance criteria

Typed functions and basic expressions compile and execute. Malformed syntax,
unbound names, and type incompatibility produce structured diagnostics with
spans. Generated Go is deterministic. One command verifies the entire slice.
Reference influences, decisions, limitations, and continuation work live on disk.

## Tasks and current state

1. **DONE — Inspect references and choose destination.** Workspace was empty.
   MileAhead is ~/Desktop/trailmapper; ~/Desktop/mileahead was absent.
   Syllogic is ~/Desktop/lsatchapelhill. Relevant inspected paths and licensing
   findings are in docs/provenance.md. No substantive reference code copied.
2. **DONE — Pin toolchain and establish pure layers.** spago.yaml/lock,
   scripts/build.mjs, Sprig.Model/Resolved/IR.Internal and Shell.CLI.
   Strict warnings and pedantic dependencies; workspace-local caches.
3. **DONE — Parse and resolve.** ASCII lexer, half-open source spans,
   required typed declarations, expression parser, stable IDs, duplicate
   checking, local scope, forward calls, and explicit entry point.
4. **DONE — Check and elaborate.** Int/Bool types, arity, typed calls,
   addition, predicate and branch compatibility, checked result annotations.
   Checker's own source locations are independent of PureScript typing.
5. **DONE — Emit, build, and run Go.** deterministic names and bytes,
   int32 semantics, runtime addition helper, lazy conditional branches,
   checked example prints 42 through CLI and Go executable.
6. **DONE — Verify contracts.** negative fixture diagnostics, executable
   examples, independent generated-tree properties, oracle comparisons,
   architecture/style gates and their cases, isolated regression mutation.
   Latest complete run: 19 tests passed; regression proof passed.
7. **DONE — Durable artifacts and handoff.** Documentation contracts
   were audited against maintained code/tests. Current handoff and evidence
   are synchronized in the audit worktree; fresh review found no blockers.
8. **DONE — Final audit.** Clean-output worktree verification compiled
   269 modules; post-refactor verification passes 19 tests and regression
   proof. Style findings were corrected; review targets/limitations remain
   explicit in engineering, findings and backlog. No language feature added.

## User steering integrated

Use maybe/either with named where builders, including record constructors.
Prefer where over let-in. Inspect the complete relevant MileAhead lint/style
rules and document which are enforced here. A separate CST style checker
now protects these specific preferences, Unicode/width and module limits.
Do not claim all MileAhead complexity/naming rules are automated here.

MileAhead guidance update was explicitly requested but rejected by the
sandbox because it writes outside this workspace. Preserve the exact patch
under docs/patches and report the boundary clearly; do not work around it.

## Execution discipline

Before a new task, read this plan and docs/progress.md. Complete one task,
run its narrow check, and update evidence/status. Record unexpected failures
in docs/findings.md and local BACKLOG.md before switching tasks. Avoid building
additional policy tooling once current acceptance criteria are satisfied.

Superpowers is installed and executing-plans is active for tasks 7/8.
Do not redo completed compiler implementation; retain local durable evidence.

## Next step

User approved a local baseline (9624bec), isolated audit worktree and inline
execution with one final fresh reviewer. Audit work was completed in the isolated audit/bootstrap-docs worktree.
User-authorized local merge into main and merged verification are complete;
the merged branch/worktree were removed after evidence preservation.
See the migrated plan and docs/progress.md. Closed ADTs
and exhaustive matching remain a separate future design/plan, not implemented.
A001 design spec drafted 2026-10-07 in docs/plans/2026-10-07-closed-adts-design.md;
it was approved by the user. Implementation plan: docs/plans/2026-10-07-closed-adts-plan.md.
