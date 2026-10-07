# Engineering guidance and actual enforcement

AGENTS.md is normative. CLAUDE.md is a pointer, so rules are not duplicated.
The verification command is npm run verify. scripts/build.mjs removes the
output of every workspace module before building, so each build recompiles
them and a promoted strict warning fails every build (F004 fixed; dependency
output stays cached). scripts/strict-rebuild.mjs, run by verify, proves it.
Never obtain green results by suppressing a gate, weakening an assertion, or
adding a bypass allowlist.

## Automated now

- pinned PureScript/Spago, purs-tidy formatting, strict warnings, pedantic
  packages, dependency lock, Unicode PureScript punctuation and 80 columns;
- 250 physical lines for maintained PureScript/JS source, tests, and tools;
  final newlines, textual escape/suppression checks (conservative, includes
  text inside comments/strings; checker fixture strings are assembled);
- purs graph parses imports; the five-layer gate (Domain, Features, Format,
  Runtime, Program; docs/plans/2026-10-07-five-layers-design.md) rejects
  unlayered modules and imports of a later layer, restricts Domain, Features
  and Format to the core library allowlist (no Effect, Unsafe or Partial),
  and lets only Features.Check* and Format.Go* import Domain.IR.Internal;
- no JS FFI files outside src/Runtime; all runtime capabilities live in
  Runtime and Program; Program.Command runs over the Domain.Host ports and
  may not import Effect or Runtime, so tests drive it with fake hosts;
- separate language-cst-parser style package rejects let-in, anonymous lambdas,
  Maybe/Either constructor cases (including record-building or guarded cases),
  and do-blocks directly in case/if branches; parse recovery fails the gate;
- structured negative diagnostics (test/diagnostics.test.mjs, one row per
  code family with exact code, span and text), generated-Go snapshots
  (bootstrap/answer.go, bootstrap/shapes.go), positive build/run, seeded AST
  roundtrips and reference execution (nested and flat multi-arm matches), a
  brute-force coverage oracle with brute-forced inhabitedness over generated
  type systems (test/coverage.test.mjs), and fake-host command tests
  (test/program.test.mjs);
- `npm run verify` runs every test/*.test.mjs file (13 files, 68 tests, no
  skips; the list is read from the directory, never hand-kept) and then
  scripts/regression.mjs, a table of isolated-copy mutations, each of which
  must pass on the healthy build and fail on its mutant: `branch`
  (Features.Check branch type), `nil-guard` (Format.Go.Match drops the `!= nil`
  test; probe requires the unmatched panic, not a runtime error), and
  `exhaustive` (Features.Check.Coverage always succeeds);
- scripts/strict-rebuild.mjs (run by verify after the build) copies the
  workspace to .build/strict-rebuild, checks the unmodified copy builds, adds
  a shadowed name to one module and requires two consecutive builds to fail
  with ShadowedName (F004).

The CST ban on all anonymous lambdas is deliberately stronger than MileAhead's
manual 'name what you pass' rule. The Maybe/Either rule is stronger than its
pass-through-only automated eliminator gate, following explicit user steering.
Named where helpers and maybe' preserve laziness for computed fallbacks.

## Review conventions, not full automated lint yet

Types/instances, constants, public functions, private functions; descriptive
names; named constants except 0/1/2 and test data; 30 declaration lines,
3 nested decisions, 8 active branches, 8 where bindings. Branch expressions
should call a named helper when they hold computation. The CST gate currently
catches branch do blocks, not every complicated operator/record expression.
Comments explain why. These conventions were inspected in MileAhead and apply
here; E001 tracks extending automation after the first slice.

No coverage percentage is claimed. Properties use deterministic generators
and explicit edge cases with no discarded inputs. Parsing tests compare with
independent generated trees; executable comparisons use a BigInt interpreter.
There is no unification implementation yet, so no fake unification properties.

## Definition of done and handoff

Acceptance criteria must run through the actual CLI/backend, with typed
rejections and regression sensitivity. Check new instructions from a clean
output directory, because incremental zero warnings do not prove a rebuild.
Update plan, progress, findings, ADRs, provenance, and backlog together.
Record known failures with concrete next actions; deferred language features
are scope decisions, not hidden failures. No external issue/commit/push rule
from a reference project is inherited.

Generated output/output caches and lockfiles are excluded from line limits.
Sprig fixture files and generated Go are data; maintained source or test code
cannot be moved into those trees to evade checks. The checker tests test the
checker itself. Structural guarantees are bounded by direct imports and known
library APIs, not a proof of arbitrary dependency purity.

## Installed workflow material

Superpowers is project-local, revision-pinned third-party guidance, preserved
unmodified under .agents/skills with its MIT notice. It is distinct from
maintained Sprig source/tests/tooling; project gates still cover their existing
roots without weakened checks. docs/planning-skills.md records instruction
precedence and adoption. Migrated plans preserve historical evidence without
asserting retroactive TDD/commit records. Execution uses the installed plan/task/review helpers and real commit ranges.

## Audit review findings (2026-10-07)

The audit moved computed Maybe fallbacks to named maybe' functions, contextual
traversal callbacks into where, independent resolver bindings into where, and
branch calculations into helpers. Private comma-list parsing functions now
have an explicit export boundary. No language semantics or gate was relaxed.
Numeric limits in maintained checking/mutation scripts are named constants.

The 30-line/3-decision/8-branch/8-binding budgets are review targets. The
flat exhaustive mappings in Format.Diagnostic (codeName: twelve ErrorCode arms;
code and message: fifteen Problem arms each) are retained together for
readability; E003 records this specific target exception and its next review.
All maintained code remains below 250 lines; automatic counts do not prove
full naming/complexity compliance. No new source behavior or unification is
claimed. Existing executable/snapshot/diagnostic tests validate this refactor.

## Known gaps in enforcement (A001)

Review conventions only: the layer names describe reasons to change, which no
gate checks; the gate checks import direction, purity and IR access.
F005: the nil-guard probe's temp-directory cleanup is not asserted.
