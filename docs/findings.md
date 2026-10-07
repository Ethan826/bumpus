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

## A001 final review fixes (2026-10-07)

- A function/constructor clash was reported at the constructor even when the
  function came first, because constructors were checked before functions and
  the program keeps the two in separate arrays. Source order is now recovered
  from span offsets. Record: docs/plans/closed-adts-review.md.
- Random flat multi-arm matches are often redundant (an arm subsumed by an
  earlier one), so the flat execution property uses a seed whose programs are
  all accepted, asserted to reach a third arm and the `_` tail.
- The old coverage oracle passed a mutant that offers uninhabited
  constructors; only the generated-type-system test catches it.

## F004 fix (2026-10-07)

- purs recompiles a workspace module whose output directory is missing, so
  deleting only workspace module outputs is enough; a full clean is not
  needed. Each build now recompiles the 32 workspace modules (about 1 s).
- The strict-rebuild proof copies output and .spago (about 40 MB) into
  .build/strict-rebuild and shares .build/home by symlink; verify takes
  about 8 s longer. It deletes the copy only on success, leaving it for
  inspection after a failure.

## A003 observations (2026-10-07)

- Test time is dominated by `go build`, one binary per executed program, not
  by the JavaScript runtime (BACKLOG T001).
- A second quadratic resolver cost survived Task 3b: `uniqueTypes`,
  `uniqueCtors` and `typeInfo` (which filtered every constructor per type).
  The final-review fix wave made them Repeated-based or linear.
- Go emission searched the type table per constructor (`tagOf`) and every
  constructor per type (Show), so 20,000 one-constructor types took 25.7 s
  to compile; one constructor layout per program (Format.Go.Layout) brought
  it to 0.2 s with byte-identical output. Many-declaration tests should cover
  every declaration kind, not just functions.
- Go `==` on generated structs would compare field pointers, so comparison
  always goes through generated helpers (ADR 005).
- Printed values reproduce themselves under the same declarations: the
  witness format minus `_` is valid source, which made the print round trip
  a strong printer test. Re-reading is bounded by E002 (constructor nesting
  overflows the parser at about 420 levels in a cold process).
- The coverage-oracle LCG used low bits that alternate, so seeds were
  reselected in Task 3b with assertions unchanged.

## G001 observations (2026-10-07)

- An applicative-only `Parser` was enough for the whole grammar because
  every choice is LL(1) on the next token (`dispatch`); the only sequencing
  on parsed values is `refine`, which checks a value without consuming.
  The style gate is syntactic, so it also bans `run`/`initialState`
  imports outside Format.Parse: running a sub-parser and inspecting its
  result would be Bind by another route.
- The combinator layers cost more stack per nesting level than the
  hand-written parser (cold `Cons(1, ` capacity fell from about 419 to 313
  levels in Task 2), so the limit was derived from a measured minimum
  (304, ADR 006) rather than chosen first; 128 also bounds printed lists,
  replacing the A003 note above about 420 levels.
- Breadth overflows hid in three more places once the parser stopped
  crashing first: the resolver's Array.foldM (about 1,700 arms or
  arguments), Coverage.redundancy's Array.foldM (about 1,929 arms) and
  Usefulness's two constructor searches (about 2,000 constructors).
  Array.foldM over Either nests one bind per item; `traverse` is balanced
  and `tailRecM` loops, so both are safe.
- Go's inliner expands nested immediately invoked closures exponentially:
  a match nested 24 deep takes 34.6 s and 7.5 GB to build (BACKLOG E005).
  The compiler accepts these programs; the remedy is pending a user
  decision.
- A flat sum counts one level per operator, so 130 operands are E_NESTING
  although the phases overflow only near 2,928 operands (ADR 006 table);
  lifting it needs iterative chains in every later phase (BACKLOG O001).
