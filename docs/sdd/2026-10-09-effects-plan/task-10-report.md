# Task 10 report: reference interpreter and differential execution

Status: DONE_WITH_CONCERNS. Commit 50f84ae `test: FX001 reference interpreter and differential corpus`.
No compiler (PureScript) code changed. The only doc edited is docs/engineering.md.

## Concern 1 (compiler): a hole in the strict `defer` rule, found by the interpreter

The reference interpreter reports "typed abort escaped cleanup" for this program, which the compiler
ACCEPTS. It is the case the brief says the error would witness:

```
type E = E; effect Log { fn log(n: Int): Unit; };
fn main(): Unit with Console = handle with handler Log { log(n) => fail(E) }
  { defer log(1); print(2) } { fail(error: E) => print(9) };
```

`defer log(1)` performs only `Log`, so strict `defer` passes it. But the enclosing handler's clause fails with `E`
(the clause row belongs to the `with`'s context, not to the cleanup), so the cleanup ends in a typed abort.
Go runs it and exits 1 with stderr `fail(E): E`. This is neither the spec's "pending abort reaches its handle" nor a
defect report line of the form the design lists. Pinned by test `a cleanup ending in a typed abort is an interpreter error`
(interpreter side only; no assertion about the compiler).

Generator response: no generated handler clause can fail where a cleanup may use its operation. Random clauses use `safe`
(no Fail labels), designed fragments use fail-free clauses, and the one failing-clause scenario (`crossing`) has no
`Log` available to cleanups in its body. Seed 1..3000 (3,000 programs), 20261010..+499 and 7..+1999 produced 0 oracle
errors. Next action for the controller: a BACKLOG/FX007-adjacent item (a `defer` whose operations can reach a failing
clause), or a rule that clauses of handlers wrapping a `defer` cannot fail.

Minor, not a defect for this task: the compiler accepts `with h ();` (a unit literal as the body); the oracle parser
(and the shrinker) require a block there.

## Implemented

Interpreter (all test-side, no compiler import; each file <= 250 lines):
- test/fx-oracle-lex.mjs (84), fx-oracle-parse.mjs (240), fx-oracle-values.mjs (78), fx-oracle-context.mjs (31),
  fx-oracle-frames.mjs (92), fx-oracle-cleanup.mjs (71), fx-oracle.mjs (171).
- Models: context chain of `with` frames (effect identity key, innermost State wins) and `fail` frames (payload head key);
  clause context = outside its `with`; `handle` = one frame per clause, first innermost, fresh marker per activation;
  FN001 stage semantics (over-application, partial application, pipes); `defer` registers when reached, LIFO, once,
  registration context; pending abort reaches its `handle` only if all cleanups finish; a cleanup crash heads the report
  with `fail(T): V` (inserted before the crash line); later causes `cleanup failed: `; `<not printable>` by declared type;
  `\n` escaped; stderr plus status 1; typed abort escaped from cleanup is an oracle error (status -1, "oracle error: ...").
- Option `clauseContext: 'inner'` (sensitivity flag). The interpreter also collects feature events used for the census.
- Deviation from "extends test/poly-parse.mjs by import": parseProgram in poly-parse.mjs is a closure with no extension
  points and a tokenizer that cannot read `...`, so fx-oracle-parse.mjs re-implements the shared grammar and imports only
  `isUpper` and `unit` (poly-parse.mjs unedited, 226 lines).

Generator, census, shrinker:
- fx-gen-ast.mjs (typed tree + printer), fx-gen-rng.mjs, fx-gen-expr.mjs (random expressions/blocks/cleanups, label
  tracking), fx-gen-fragments.mjs (nested same-key with forwarding, aborts crossing handles, stage order with
  over-application, escaped callbacks), fx-gen-cleanup.mjs (9 cleanup scenarios, 4 terminal), fx-programs.mjs (assembly;
  program i has focus scenarios by index; `generate(seed, index)`), fx-census.mjs, fx-gen-reject.mjs (25 strict-defer
  rejection variants: direct, through a function, ambient callback, named-row callback, exact Task 8 texts and `defer` span),
  fx-shrink.mjs (drops items/defers/handlers/clauses/arms/functions, literal replacement, coarse first).
- Census counts what the interpreter OBSERVED, not generator intent.

Tests:
- test/fx-oracle.test.mjs (78 tests): hand traces of every executable probe of Tasks 2, 4, 7, 8 (imported); the two
  injected cleanup cases and the fx-block `orders` probes are excluded by name (existence asserted); the hole witness;
  clause-context pin; generation determinism; shrinker (items removed, well-typed, much smaller) and literal replacement;
  sensitivity (flag changes some of 50 programs).
- test/fx-differential.serial.test.mjs (7 tests at 500): census minimums, 25 rejection variants, five go-batch chunks of
  100 (a batch failure names its chunk; a generated program the compiler rejects fails with its seed). Differences write
  seed, source, both outcomes to .build/fx001-differential/ and shrink the first 3 per run (bounded: each candidate costs a Go run).
- Moved unchanged: Task 8's run cases to test/fx-cleanup-programs.mjs (fx-cleanup.test.mjs imports them), Console cases to
  test/fx-console-programs.mjs. docs/engineering.md documents the corpus and both knobs. Inline run cases of
  fx-specialize/fx-handler-check (Task 6/7 "end to end" ones) were not moved (outside the brief's list).

## Default run (500 programs, seed 20261010; WAXWING_FX_SEED / WAXWING_FX_PROGRAMS)
Program i has seed 20261010+i (reproduce: `generate(20261010 + i, i)`); list written to .build/fx001-differential/last-run.json.
Result: 0 differences, 0 rejections, 0 oracle errors; 152 of 500 end in a defect report. Wall time 15.0-17.8 s alone
(five Go batches); inside the serial phase similar. Census (programs, minimum):
nested same-key 225 (50); aborts crossing unrelated handle 109 (50); stage order with over-application 90 (50);
escaped callbacks 109 (50); cleanup normal 267 (25); abort 363 (25); defect 119 (25); crash on normal exit 65 (25);
crash while abort pending 38 (25); several crashes 38 (25); own failure during abort 193 (25);
registration context 76 (25); unreached defer 143 (25).
Extra runs: seed 7, 2,000 programs (20 batches, 1m40s): 0 differences (.build/fx001-task10-large.log); 3,000 programs seeds
1..3000 compile and interpret clean. Fewer than about 400 programs cannot meet the minimums and fail by design (documented).

## TDD / sensitivity evidence (isolated copies under the scratchpad; mutations not in the tree)
Mutating the interpreter fails the hand traces: inner clause context (4 handler probes plus pin plus sensitivity),
first clause outermost (2), cleanup FIFO (3), abort not heading the report (3), arguments evaluated before applying (2).
Shrinker mutations: no item removal fails the shrinker test; no literal replacement fails the literal test (which I added
because the first test did not detect it). Strong check of the differential harness: with the interpreter's clause context
mutated to inner, the default run reported differing programs in every chunk, wrote seed/source/json for each and `-min.wxw` for the
first three (e.g. `{ with handler Log { log(n) => () } { with handler Log { log(n) => log(0) } { log(-3) }; () }; 10 }`).
`WAXWING_FX_PROGRAMS=100` fails the census (minimums unmet). Caveat: the interpreter tests were written together with the
interpreter, so there was no separate RED run before it existed; the mutations above are the failing witnesses.

## Verify and regression
- `rm -rf output && GOTOOLCHAIN=go1.26.4 npm run verify` (.build/fx001-task10-verify.log): build, gates, strict-rebuild,
  structure OK; parallel phase 925/926: the one failure is `large-source` `a three-thousand-constructor match is judged in
  full` (5.78 s vs 5 s, the recorded T004 recurrence; passes alone 15/15). verify stops there, so the serial phase and
  regression were run directly:
- Serial phase (.build/fx001-task10-serial.log): 17/29; failures: fn-linear-timing 8 (1-8), fn-scale 2 (5,000-parameter
  value and generics), fx-block 20,000-let (21) = the T007 set, plus the match-lift ladder (`took 2082 ms`, 1.86-1.98 s alone;
  it also failed in Task 9's serial log, .build/fx001-task9-serial.log; it imports none of the new files). The new
  differential tests 22-28 pass.
- `node scripts/regression.mjs` (.build/fx001-task10-regression.log): exit 0, 33 proofs.
- test/style.test.mjs and test/structure.test.mjs pass; the structure gate (250 lines) is clean.

## Self-review
Every brief item present. Weaker spots: the census minimum for over-application (90) depends on the stage scenario
weights; the interpreter's escaped-callback event can fire for any closure under a different handler (it counts the
observed behaviour). The commit trailer follows the harness attribution (Claude Sonnet 5.5), not the Opus 5.5 line in the context file.

## Fix report, round 1
1. Task 7's eight inline run probes moved unchanged to test/fx-task7-programs.mjs (`specialized`, `checkedRuns`); fx-specialize and fx-handler-check import them; fx-oracle.test.mjs hand-traces all eight (all interpret, all agree; no exclusions).
2. Shrinker tests in fx-oracle.test.mjs take 152 ms and 25 ms in the parallel phase; no reduction needed.
3. Evidence (.wxw, .json) is saved before shrinking; the -min.wxw is saved after.
4. goOutcome has GOWORK 'off'; shrink takes a wall-time limit (180 s, best so far returned).
5. escaped-callback now counts only a callback whose handler comes from its call context and differs from its creation context; cleanup-registration-context only an operation in a cleanup whose handler comes from the registration context and differs from the abort's raise context. Intercept-and-forward has its own census row (68, minimum 50; forward clause chance raised 60 to 80 for margin). Default seed census: nested 225, forward 68, crossing 109, over-application 90, escaped 109, cleanup normal 267, abort 363, defect 119, crash-normal 65, crash-abort 38, several 38, own-failure 193, registration 74 (exact), unreached 143. 0 differences, 12.9 s (.build/fx001-task10-fix-default.log).
6. docs/engineering.md sentence corrected. 7. Exclusion test resolves paths from import.meta.url.
Verify (.build/fx001-task10-fix-verify.log): parallel 933/934, sole failure the T004 `three-thousand-constructor match` (passes alone 15/15). Serial (.build/fx001-task10-fix-serial.log): the T007 set (1-8, 17, 20, 21), the ladder (29) and two more fn-scale timing cases (18, 19) that also failed in Task 9's serial log; differential tests pass. Regression (.build/fx001-task10-fix-regression.log): exit 0, 33 proofs. style/structure pass.
