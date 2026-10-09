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
  and gives each internal IR its own importer allowlist (since P001
  Task 1): only Features.Check* and Features.Specialize* import
  Domain.Checked.Internal, and only Features.Specialize* and Format.Go*
  import Domain.IR.Internal (scripts/structure.mjs `internalModules`;
  test/structure.test.mjs pins both directions).
  The core allowlist (scripts/structure.mjs `coreLibraries`) is Prelude and
  Data.{Array, Either, Maybe, Int, String, Foldable, Traversable} modules
  plus, since A003 Task 3b, exactly Control.Monad.Rec.Class, for `tailRecM`
  loops over long inputs (BACKLOG E002); test/structure.test.mjs pins that
  Control.Monad.ST, Control.Monad and near-miss names stay rejected. Since
  P001 Task 3 it also admits exactly Data.Map, Data.Set and Data.Tuple
  (packages ordered-collections and tuples), for the unifier's
  substitution; their submodules (Data.Map.Internal, Data.Set.NonEmpty,
  Data.Tuple.Nested) and Data.List stay rejected, pinned by the same file;
- no JS FFI files outside src/Runtime; all runtime capabilities live in
  Runtime and Program; Program.Command runs over the Domain.Host ports and
  may not import Effect or Runtime, so tests drive it with fake hosts;
- separate language-cst-parser style package rejects let-in, anonymous lambdas,
  Maybe/Either constructor cases (including record-building or guarded cases),
  and do-blocks directly in case/if branches; parse recovery fails the gate;
- the same CST gate keeps parser productions applicative (G001;
  tools/style/src/Style/Parser.purs): in Format.Parse and
  Format.Parse.{Literal, Pattern, Expression, Declaration, Type, Lambda}
  it rejects every `do` block, the operators `>>=`, `=<<`, `>=>` and
  `<=<` (including sections such as `(>>=)`), and the names `bind`,
  `join`, `discard`, Prelude's `ap`, `ifM`, `whenM`, `unlessM` and
  `liftM1`, and Control.Bind's `bindFlipped`, `composeKleisli` and
  `composeKleisliFlipped`, plain,
  qualified or in backticks. Format.Parse.Grammar, which holds the
  Parser instances, and Format.Parse.Cursor, the token cursor beneath it,
  are exempt; fixtures in test/style.test.mjs pin both the rejected and the
  exempt modules. The gate is syntactic: an aliased or re-exported Bind
  under another name would pass it, which review must catch;
- only Format.Parse may run a parser (G001 Task 5, same CST gate): every
  other module that imports Format.Parse.Grammar or Format.Parse.Cursor
  must name its imports, without `run` or `initialState`; an open, `as`-only
  or `hiding` import of either module is rejected. Format.Parse.Grammar,
  which defines `run` and re-exports `initialState`, is exempt. Without
  this, a production could run a sub-parser and inspect its result, which
  is Bind by another route. Fixtures in test/style.test.mjs cover the
  rejected forms, the exempt modules and an ordinary named import;
- structured negative diagnostics (test/diagnostics.test.mjs, one row per
  code family with exact code, span and text), generated-Go snapshots
  (bootstrap/answer.go, bootstrap/shapes.go), positive build/run, seeded AST
  roundtrips and reference execution (nested and flat multi-arm matches), a
  brute-force coverage oracle with brute-forced inhabitedness over generated
  type systems (test/coverage.test.mjs), and fake-host command tests
  (test/program.test.mjs);
- `npm run verify` runs every test/*.test.mjs file (32 files, 302 tests at
  P001 Task 9, no skips; the list is read from the directory, never
  hand-kept) in one parallel `node --test` run, except the
  `test/*.serial.test.mjs` files, which it runs afterwards in a second
  run with `--test-concurrency=1` (scale tests that time `go build` or
  long Bumpus phases against fixed bounds, so the parallel runner's own
  load cannot fail them; user decision 2026-10-09, FN001 Task 8). A new
  test that builds large Go programs against a time bound takes the
  `.serial.test.mjs` suffix (review convention; the split by suffix is
  automated in scripts/verify.mjs). Then verify runs
  scripts/regression.mjs, a table of isolated-copy mutations, each of which
  must pass on the healthy build and fail on its mutant: `branch`
  (Features.Check.Infer branch type), `nil-guard` (Format.Go.Match drops the `!= nil`
  test; probe requires the unmatched panic, not a runtime error),
  `exhaustive` (Features.Check.Coverage always succeeds), `ctor-order`
  (Format.Go.Compare reverses the tag comparison), `first-field` (compares
  the last field first), `show-fields` (Format.Go.Show prints only the
  first field) and `state-thread` (Format.Parse.Grammar's `apply` runs the
  second parser from the original state; examples/answer.bumpus must still
  compile to bootstrap/answer.go) and `capture` (Format.Go.Match drops a
  match's scrutinee from its free locals, so an enclosing lifted match
  misses a local read only there; probe builds and runs test/match-lift's
  capture program), and since P001 four more, whose probes live in
  test/regression-poly.mjs (imported by test/regression.mjs): `occurs`
  (Features.Check.Unify `bindBounded` skips the occurs check; probe
  requires E_TYPE `Infinite type: _ occurs in List(_)`), `rigid` (a rigid
  variable unifies with any type; probe requires `fn f(x: a): Int = x;`
  to be E_TYPE `Expected Int, found a`), `instantiate`
  (Features.Check.Scheme `instantiate` does not advance the meta counter,
  so uses of a scheme share metas; probe requires `pair(id(1), id(true))`
  to print `Pair(1, true)`) and `spec-key` (Features.Specialize.Keys keys
  a type application's data-type arguments without their identity, so
  `List(List(Int))` and `List(List(Bool))` share one Go type; probe
  requires a program using both to build and print `Pair(1, 2)`), and
  since FN001 ten more, rows in scripts/regression-fn.mjs and probes in
  test/regression-fn.mjs (ADR 008): `stage-value` and `stage-lambda` (a
  named value or a lambda eta-expanded to its type's arity; timing probe
  `use(stuck)` must enter `stuck`, via test/support.mjs `panicOnEntry`),
  `partial-strict` (partial arguments evaluated inside the closure),
  `pipe-order` (every pipe lowered as the rewritten call), `block-order`
  (an application helper evaluates its 64 arguments before applying any),
  `lambda-capture` (Format.Go.Capture leaves a lambda's parameters free),
  `fun-compare` (Comparable ignores arrows), `functional-fixpoint`
  (Functional stops at its seeds), `value-edge` (bare references and
  lambda bodies are no instantiation edges) and `arrow-key` (arrows
  interned without their parameter): twenty-two `Regression proof (…)`
  lines in all (`node scripts/regression.mjs name…` proves only the named
  rows); the A003 order and print tests also use an independent value
  oracle (test/value-oracle.mjs);
- Go execution in tests is batched per test file (T001, test/go-batch.mjs):
  `runGoBatch(import.meta.url, cases, label?)` takes an array of
  `[name, source]` pairs (an array, so a computed name collision is refused
  at declaration rather than collapsing silently) and, on the first `run(name)`, compiles them all, writes a synthetic module
  under `.build/go-batches/<id>/` (its own go.mod with module path
  `bumpusbatch` and the pinned toolchain's language version, one package
  `c<N>` per case, a dispatcher `main` importing them), builds once with
  GOCACHE under .build and GOWORK off, and runs each case as its own process
  (the binary invoked with the case's package name). `<id>` is the test
  file's basename plus an optional label, sanitized; a batch clears only its
  own directory, never the root, and an id may be claimed once per process.
  Before rewriting, each program must have exactly one `package main` clause
  and exactly one `func main() { fmt.Println(...) }` line (Format.Go's
  entryMain) and no `func Main`; only those two lines change. Failure
  contract: a Bumpus rejection is recorded per case and rethrown, unchanged,
  by that case's `run` (runGo's error), while the other cases still build;
  an unexpected program shape or a Go compile failure is a batch
  infrastructure failure, thrown by every case's `run`, naming the offending
  case(s) when Go's output identifies their package. `run` keeps runGo's
  contract (stdout, exit status 0 asserted); `result` returns the raw
  process outcome. Panics keep their message and exit status; stack traces
  differ (package path `bumpusbatch/c<N>`, `Main`). Batch directories
  (binaries included) persist after a run and are replaced only by that
  batch's next run; `rm -rf .build/go-batches` reclaims them. Because the
  directories are fixed per test file, two concurrent test runs in one
  checkout race on them (and on the build); run one at a time per checkout.
  The `go build` timeout (300 s) kills only the go command, not its compile
  children (spawnSync cannot kill a process group); depth.test.mjs's timed
  builds group-kill because their timeout is an assertion. Self-tests:
  test/go-batch.test.mjs. Not batched: depth.test.mjs timing builds,
  scripts/regression.mjs probes, and `goTest`; `runGo` remains as the
  self-tests' standalone reference;
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

Loops whose length grows with the input (characters, tokens, declarations)
use `tailRecM` or a self tail call, and accumulate with Format.Stack or
indexing rather than Array.snoc/uncons/drop per item, which copy the array.
This is a review convention; only test/large-source.test.mjs (megabyte
padding, 20,000 declarations) checks it, and only for the paths it drives.

No coverage percentage is claimed. Properties use deterministic generators
and explicit edge cases with no discarded inputs. Parsing tests compare with
independent generated trees; executable comparisons use a BigInt interpreter.
The unifier (Features.Check.Unify, P001 Task 3) is compared with an
independent union-find oracle (test/unify-oracle.mjs) and checked for
soundness, acyclicity and most-generality over generated pairs.

Measurement and checking tools are committed, not ad hoc (T003); neither
runs in verify. scripts/differential.mjs compares two built compilers
phase by phase (lex, parse, resolve, check, specialize, Go emission, full
compile) over the sources the test suite parses (harvested by
scripts/differential-hook.mjs into .build), token soups, generated
nested-match programs and mutations, and exits 1 on any difference: run
it against an isolated build of the previous commit for every
behavior-preserving refactor or performance change.
scripts/ladder-profile.mjs times the match-lift ladder cold and per phase,
alternating with a baseline build. Both are review conventions.

## Definition of done and handoff

Acceptance criteria must run through the actual CLI/backend, with typed
rejections and regression sensitivity. Check new instructions from a clean
output directory, because incremental zero warnings do not prove a rebuild.
Update plan, progress, findings, ADRs, provenance, and backlog together.
Record known failures with concrete next actions; deferred language features
are scope decisions, not hidden failures. No external issue/commit/push rule
from a reference project is inherited.

Generated output/output caches and lockfiles are excluded from line limits.
Bumpus fixture files and generated Go are data; maintained source or test code
cannot be moved into those trees to evade checks. The checker tests test the
checker itself. Structural guarantees are bounded by direct imports and known
library APIs, not a proof of arbitrary dependency purity.

## Installed workflow material

Superpowers is project-local, revision-pinned third-party guidance, preserved
unmodified under .agents/skills with its MIT notice. It is distinct from
maintained Bumpus source/tests/tooling; project gates still cover their existing
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
