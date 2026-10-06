# Engineering guidance and actual enforcement

AGENTS.md is normative. CLAUDE.md is a pointer, so rules are not duplicated.
The verification command is npm run verify. Never obtain green results by
suppressing a gate, weakening an assertion, or adding a bypass allowlist.

## Automated now

- pinned PureScript/Spago, purs-tidy formatting, strict warnings, pedantic
  packages, dependency lock, Unicode PureScript punctuation and 80 columns;
- 250 physical lines for maintained PureScript/JS source, tests, and tools;
  final newlines, textual escape/suppression checks (conservative, includes
  text inside comments/strings; checker fixture strings are assembled);
- purs graph parses imports; exact project dependency allowlist and core
  library allowlist prevent reversed layers, effects, and unchecked IR use;
- no JS FFI files inside Sprig; all runtime capabilities live in Shell;
- separate language-cst-parser style package rejects let-in, anonymous lambdas,
  Maybe/Either constructor cases (including record-building or guarded cases),
  and do-blocks directly in case/if branches; parse recovery fails the gate;
- structured negative diagnostics, generated-Go snapshot, positive build/run,
  seeded AST roundtrips/reference execution, and isolated mutation proof.

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
asserting retroactive TDD/commit records. Execution remains a separate step.
