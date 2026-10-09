# Re-review: FX001 Task 7 fix round 1 (e9a613f..4b80bd1)

Focused run at HEAD: `GOTOOLCHAIN=go1.26.4 node --test test/fx-run.test.mjs test/fx-check-fixes.test.mjs` gives 26/26 pass. output/ is compiled at HEAD (output/Format.Go.Handle/index.js:85 has `Data_Array.reverse`, :63 `malformedKey`).

### Finding Verdicts

1. (Critical) First clause innermost: **ADDRESSED.**
   - src/Format/Go/Handle.purs:135-137: `foldl push "ctx" (Array.reverse (Array.mapWithIndex Tuple branches))`. The fold pushes the last clause first, so it ends up nearest to `ctx`. Clause 0 is the outermost text wrapper, which makes it the innermost frame. Marker indices still come from the original positions, so dispatch to branches is unchanged.
   - The comment at :131-134 now says the first clause is innermost and cites the "first occurrence wins" rule.
   - Both probes are in test/fx-run-programs.mjs:124-131 with exact stdout `'5\n'` and `'3\n'`, and both pass.
   - Seen failing first: the report's isolated mutant (frames un-reversed) makes fx-run cases 19 and 20 fail. Per the read-only constraint I did not re-run that mutant. The claim fits the code: without the reverse, the `Error(Bool)` frame is innermost, so the old panic or wrong value would come back.
2. (Minor) Check-level tests for the two checker fixes: **ADDRESSED.**
   - test/fx-check-fixes.test.mjs is new. It runs parse, resolve and check with no Go.
   - Test 1 (`match j { Job(f) => 1 }` on `Job(Int, Log)`) targets the Tables/Match row-argument fix.
   - Test 2 (`Job(Int, Log + Clock)` field called in a `Log + Clock` row) targets the bound-tail fix in Consume.
   - Reverted-fix evidence comes from the report's mutants: Consume.purs at HEAD~1 makes test 2 fail; the old `TData owner args []` in Match makes tests 1 and 2 fail. Each fix therefore has at least one test that fails without it. I did not re-run these mutants (read-only).
3. (Minor) Key-0 fallbacks: **ADDRESSED.**
   - Lowered.purs:132-133: `effectShape` now returns `Maybe EffectShape`, so the `{ key: 0, operations: [] }` default is gone.
   - Lowered.purs:138-140: `operationWrapper` falls back to the existing `missing` wrapper.
   - Handle.purs:71-78: `installKey` emits `func() int { panic("waxwing: malformed value") }()` for a non-handler type or a missing layout. That expression has type `int`, which matches `waxwingInstall(outer *waxwingCtx, key int, ...)` (Context.purs:121). So it is a valid Go guard, not wrong Go text.
   - The `EffectKey 0` fallback in `handlerKey` was removed. grep finds no other `EffectKey 0` or `key: 0` in src/.

### New Breakage in the Fix Diff

None found.
- The diff touches only Handle.purs, Lowered.purs and two test files.
- `effectShape` has one caller outside Lowered (Handle.purs:74), and it was updated.
- The import changes look clean: `EffectKey(..)` was dropped from Handle and `Maybe` was added to Lowered.

### Out-of-Scope Observations

- On `fx-block.serial` "20,000 let items compile in linear time" (bound 3 x 500 = 1,500 ms): I ran it alone at HEAD with load average about 0.6. It passed at **1,497 ms**, only 3 ms under the bound.
  - The fix diff cannot affect it. It changes only `handle` and `with`-install lowering and effect-shape lookup, and a let chain uses none of these.
  - So "load / T007 class" is plausible for the failure seen among other tests. But the test is not listed in T007 today, and it now sits on the bound even with no other load.
  - Task 7 as a whole (e9a613f, new Go lowering passes) may have added constant-factor cost compared with the earlier 1.4 s.
  - Recommendation: add this test to BACKLOG T007 with the 1,497 ms evidence. Before closing Task 7, have the controller compare against a pre-Task-7 (49717bc) build in a separate worktree, so a real Task 7 slowdown is not filed under environment noise. Do not change the bound.
