# Findings and operational memory

## Tooling

Spago 1.0.4 uses env-paths and opens a SQLite cache database under the real
user directory. The sandbox rejected that access. scripts/cache.mjs overrides
Node's os.homedir in the Spago process only to .build/home; it does not modify
HOME or the installed tool. On this macOS host the normal cache at
~/Library/Caches/spago-nodejs was copied to
.build/home/Library/Caches/spago-nodejs to allow cached package resolution.
That cache is ignored and is not part of the deliverable. No reference source
was copied into this compiler. The adapter clears host XDG_CACHE_HOME/APPDATA/LOCALAPPDATA settings in the
Spago process so env-paths uses the workspace home on other platforms too.
Only macOS execution has been verified.

PureScript 0.15.16, Spago 1.0.4, purs-tidy 0.11.1, Go 1.26.4, and Node
26.6.0 are installed here. Spago's package set 81.0.0 declares a 0.15.15
baseline but compiles successfully under pinned 0.15.16. Strict builds caught
Prim.Type/Function name shadowing and a redundant tuples dependency; both
were fixed rather than suppressing warnings.

npm could not resolve registry.npmjs.org (ENOTFOUND) during a package-lock
attempt. Local npm dependencies were unnecessary: the pinned tools are PATH
prerequisites. No npm install is needed to verify this repository once tools
and PureScript caches are present. Online installation still needs a separate
network-capable validation; local issue F001 records this distinction.

## Compiler traps worth retaining

Go typed constant addition can reject overflowing expressions even though
runtime int32 addition wraps. Emit sprigAdd with int32 arguments rather than
folding source addition to a Go constant. Range-check source literals first.

PureScript is eager. maybe's computed fallback executes even for Just; use
maybe' with a named fallback function when work should be conditional.
Use either for Either; use maybe/maybe' for Maybe. Name record builders and
transformations in where, not just simple pass-through branches.

Resolved IDs are deterministic array indices. Local values shadow function
names in call position and are rejected as non-callable; no source names are
copied into Go identifiers. This avoids Go keyword and helper-name collisions.

Negative checks must validate the expected diagnostic, not any failure.
The mutant must compile before its rejection assertion is tested. Mutations
run in .build/regression and never change live sources or normal output.

## Reference documentation boundary

The user explicitly authorized a MileAhead guidance amendment. apply_patch
rejected /Users/ethan/Desktop/trailmapper/AGENTS.md with:
"writing outside of the project; rejected by user approval settings".
Do not claim it was changed and do not bypass the sandbox. The proposed patch
is in docs/patches/mileahead-eliminators.patch.

## Planning workflow

Plan, durable findings, and verification evidence must precede further broad
exploration. docs/plans/bootstrap.md owns task status; docs/progress.md owns
what actually ran; ADRs own decisions; BACKLOG.md owns future and unresolved
work. A future skill installation must not silently replace this convention.

purs-tidy 0.11.1 writes its version to stderr with success status. The version
gate checks the combined output exactly, rather than assuming stdout.

## Skills migration prerequisites

Escalated bunx installation and GitHub access succeeded on 2026-10-07; the
earlier npm DNS failure remains historical, not a claim of current outage.
Fresh compiler prerequisite installation/cross-platform builds remain untested.
All 15 pinned skills plus helper files are installed in .agents/skills.

At migration, Git had no commits: git rev-parse --verify HEAD reported "Needed a single
revision". task-start/task-done require HEAD/BASE and review-package requires
commit ranges; do not invoke them until a real checkpoint exists (W001).
Sandboxed git status also emitted xcrun temporary-cache permission errors;
escalated Git inspection worked. Record this environment distinction (F003).

The reviewed pinned writing-plans uses self-review rather than a plan-review
subagent. At migration the audit plan was self-reviewed only; execution had not begun. Existing docs stay durable even when scratch is cleaned.

## Bootstrap audit findings

Computed record/error fallbacks in Lex.scan, Parse.Core.failAt,
Parse.Expression.integer, Resolve lookups, and Check.checkLocal used eager
maybe. They now use maybe' with named fallback functions. Context-dependent
traverse/filter callbacks in checking/resolution are named in where. Resolver
globals moved from an independent do-let to where. Branch rendering/building
work was extracted and private Parse.Core plumbing is no longer exported.

Architecture prose overstated defensive E_INTERNAL coverage: Check checks
local/call indices during inference, but trusts the resolved entry/table
structure. Documentation now states that exact contract. The CLI respects an
existing GOCACHE; README now describes its default, rather than an override.

The ten-arm (now twelve; see BACKLOG E003) codeName mapping exceeds the eight-branch review target; splitting
a short exhaustive ADT tag mapping would obscure its wire contract. E003
records it explicitly. Other declaration budgets were reviewed manually;
module/file limits remain automatically checked. The Spago no-files message
for test/**/*.purs is informational: tests are Node .mjs files. Actual strict
build tables report zero warnings/errors; no message was suppressed.

A setup command accidentally ran an extra verification in the original root
after worktree creation. It passed but is not the worktree baseline evidence.
The separate clean-output worktree run compiled 269 modules and passed 19
tests plus the regression proof; .build/audit-baseline.log in the worktree
is the actual evidence. Both locations' previous outputs were preserved.

Task 1 verification initially failed with ModuleNotFound for
Sprig.IResolved.Internal. A naive R.-to-Resolved. replacement also matched
the suffix of IR.; it corrupted the import and IR references in Check.purs.
The replacement is corrected, not retried unchanged. The original failure
is preserved in the execution workspace task-1-failed-alias.log. A copied
defective source tree independently failed purs compile with the same missing
module in .build/alias-regression/failure.log. The build itself detects this
edit failure; no gate or assertion was disabled.

The isolated reproduction helper incorrectly expected diagnostics only on
stderr, while purs wrote them on stdout. That helper assertion failed before
the live fix ran, and its trailing verify re-observed the still-broken build
in .build/audit-task-1-fixed.log. Inspected the combined saved output, confirmed
the expected missing module, then corrected live IR references. Those logs
remain evidence of the failed attempts, not successful fix evidence.

Execution setup resolved W001 with baseline 9624bec and the user-authorized
audit/bootstrap-docs worktree. Full verification from clean output passed
there, and Task 1 changes are committed at 4410609. Docs are handoff artifacts,
not evidence that unimplemented ADTs or hostile-IR validation exist.

The fresh whole-branch review found no blockers and one minor item: two test
titles overstate assertions (E004). The existing named-helper fixture uses
maybe 0, not a computed maybe' fallback; the snapshot test makes one direct
compile, not repeated CLI invocations. Manual repeated CLI emissions now
independently agree. These titles are deferred per executor minor-finding
policy, without weakening the tests or overstating their automated coverage.

## A001 closure observations (2026-10-07)

- F004 reproduced during Task 6: a promoted strict warning appears only on the
  build that compiles the module. Clean-output verify is the workaround; the
  fix is open in BACKLOG.md.
- Four `sprig-regression-*` directories from earlier Task 3-era probe runs
  remain in $TMPDIR; a clean verify did not add any. Tracked as F005.
- The nil-guard policy deliberately does not validate fields skipped by
  wildcards or binders (ADR 003); this is a documented limit, not a defect.
- `E_USAGE`, `E_IO`, `E_TOOL` are strings in Format.Wire (A005).
