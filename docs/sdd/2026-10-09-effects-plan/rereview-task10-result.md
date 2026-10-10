### Finding Verdicts
1. ADDRESSED. test/fx-task7-programs.mjs holds all 8 probes (4 `specialized`, 4 `checkedRuns`), imported by test/fx-specialize.test.mjs:466,496 and test/fx-handler-check.test.mjs:195,238. test/fx-oracle.test.mjs:364,386-390 hand-traces all 8 with expected stdout; no exclusions needed. The strings match the originals (clock and main constants unchanged).
2. ADDRESSED. The report gives 152 ms and 25 ms for the shrinker tests in the parallel phase, under the 10 s threshold, with no assertions changed.
3. ADDRESSED. test/fx-differential.serial.test.mjs:136-138 calls saveEvidence (source and outcomes) before shrinking. The `-min.wxw` is saved afterwards (:141-142).
4. ADDRESSED. test/fx-diff-support.mjs:94-95 sets GOWORK 'off'. test/fx-shrink.mjs:440-448 adds a wall-time deadline and returns the best so far; the test passes 180 s (:125,141).
5. ADDRESSED. fx-oracle.mjs:91 records {created, called}. fx-oracle-frames.mjs:19-22: escaped-callback needs the handler resolved from the call context (`called`) to equal the performing frame and to differ from the creation-context handler. fx-oracle-cleanup.mjs:46-47 and frames.mjs:24-27: cleanup-registration-context needs the frame to equal the registration-context handler and to differ from the abort's raise-context handler, and it fires only on a perform inside a cleanup running under a pending abort. fx-census.mjs:67 adds a separate forward row (minimum 50, 68 at the default seed). The generator was changed (fx-gen-fragments.mjs:170, 60 to 80) and no minimum was lowered. The reported default-seed census meets every minimum; the pendingAbort shape change has no other consumers.
6. ADDRESSED. docs/engineering.md now says both run in verify, with the differential test in the serial phase.
7. ADDRESSED. fx-oracle.test.mjs:410 uses new URL(file, import.meta.url), and the paths are now bare file names.

### New Breakage in the Fix Diff
None (Critical or Important).
- Minor: the header comment of fx-oracle-frames.mjs:3 still describes `lambdas` as "creation contexts", but entries are now {created, called}.
- Minor: a callback created where no handler for the effect exists counts as escaped, because `undefined !== frame`. That is slightly broader than "created under one handler". Generated scenarios plausibly always have a handler.
- Minor: the shrink deadline is checked only between candidates, so one Go run (up to about 3 minutes) can overshoot it.

### Out-of-Scope Observations
- The escaped-callback count (109) is unchanged after the predicate was tightened, and it equals the crossing count. This is plausible if that scenario always produces a genuine cross-handler call, but it is a coincidence worth a glance.
- The regression and serial failures (T004 and T007 timing cases) are pre-existing and are documented in the report.

### Verdict
All findings addressed
