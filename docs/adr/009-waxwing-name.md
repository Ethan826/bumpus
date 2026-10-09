# ADR 009: Waxwing name and `.wxw` source extension

Accepted 2026-10-09. Supersedes ADR 001's provisional language name.

## Decision

The language is Waxwing. Source files use `.wxw`; command and package
identities use `waxwing`. This is a naming migration, with no new language
semantics, command verbs, extension-based input rejection or compatibility
aliases. Stage 0 still runs through Node and emits ordinary Go.

Rename the CLI script, npm script, workspace packages, source fixtures,
generated Go identifiers and panic texts, temporary prefixes and internal
harvest hooks together. Keep the compiler's neutral module/layer names.
Regenerate Go snapshots and compare them with the former snapshots under
only the expected name substitution.

## Rationale and boundaries

The user chose Waxwing / `.wxw` after investigating extension collisions.
That research is user-provided context, not an independent availability or
trademark clearance performed by this repository. The symmetric extension
and bird identity were part of the user's choice.

Current documentation and active FX001 specifications use the settled
name. Historical plans, progress entries, findings, prior naming decisions
and original branding provenance retain their old names as evidence.
The Bumpus mascot is archived. User-supplied Waxwing flight-lines artwork
is the current logo; its original assets and editing notes are preserved.

The migration runs in the existing FX001 worktree after its Task 3
checkpoint (3481468), before further effects implementation. The workspace
directory, remote repository and publication settings are unchanged.
No push or external publication is authorized by this decision.

## Verification

Existing CLI usage, source diagnostic, executable, snapshot and isolated
mutation tests remain authoritative. Prove the renamed usage assertion
rejects the former usage text in an isolated copy. Run `npm run verify`
and preserve every failure, including pre-existing timing failures.
Execution evidence and actual results belong in docs/progress.md.
