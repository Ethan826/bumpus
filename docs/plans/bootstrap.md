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
7. **IN PROGRESS — Durable artifacts and handoff.** README, language spec,
   architecture, ADRs, provenance, engineering mapping, backlog, bootstrap
   plan, progress/findings. These files now exist; audit their claims against
   code and finish the claims/style audit. The README verification command has now
   passed from a clean output directory.
8. **PARTLY DONE — Final audit.** Clean strict build and full verification
   passed (19 tests plus regression proof); evidence is in docs/progress.md.
   User requested a stopping checkpoint before the final documentation review. Confirm no generated artifact or
   temporary fixture is mistaken for maintained source. No feature expansion.

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

Resume with the remaining review in tasks 7 and 8; do not redo the completed
implementation. The research on planning skills is advisory;
installation is not required to finish this project.

## Next step

User steering changed on 2026-10-07: install the skills first, backport the
in-flight work, then plan the run together. Skills are now installed locally.
Remaining tasks 7/8 are mapped into
[the migrated audit plan](2026-10-07-bootstrap-audit.md) and
[the migration ledger](bootstrap-migration-ledger.md).
Completed tasks 1–6 and their prior evidence are preserved. Audit execution
and the separate ADT milestone are pending. See docs/planning-skills.md for
execution prerequisites; do not resume the audit from the old reset prompt.
