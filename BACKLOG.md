# Local backlog

Current delivery: stage 0 ground vertical slice. Plan and verification evidence
are in docs/plans/bootstrap.md and docs/progress.md. No remote tracking.

| ID | State | Next concrete work and acceptance |
|---|---|---|
| V001 | Done | Documentation/style audit closed after fresh review found no blockers; final closure verification is recorded in docs/progress.md. |
| A001 | Next | Closed product/sum declarations, constructor resolution and typed construction; match patterns, exhaustiveness/redundancy checks; executable and negative examples, representation tag/payload tests. |
| P001 | Planned | Rank-1 schemes, substitution and occurs-checked unification; mandatory signatures, no polymorphic recursion; meaningful composition/idempotence/occurs-check properties and reference comparisons. |
| K001 | Planned | Explicit kind IR/checker, constructor arities, Type/Row/arrow kinds, HKTs restricted to first-order constructor application; reject ill-kinded programs before type solving. |
| C001 | Planned | Classes and non-overlapping coherent instances, terminating resolution, ambiguity errors, dictionary elaboration; negative overlap/coherence cases. |
| R001 | Planned | Unique-label row-polymorphic records with lacks constraints and normalized layouts; accessor evidence; extensible variants remain deferred. |
| M001 | Planned | Modules/imports, explicit interfaces, deterministic whole-program linking/specialization; stable binary separate compilation deferred. |
| I001 | Planned | Explicit Go FFI with refined ingress, typed foreign errors, effect sequencing and nil/zero validation; optional Go go/parser and go/types inspection helper. |
| S001 | Planned | Port scanner/parser to Sprig as equivalence pilot, then Stage 1 compiler; preserve Stage 0 and generated compiler-Go snapshot; Stage 2/3 comparisons and full tests. |
| F001 | Environment limit | Verify fresh online tool install/package downloads on network-capable host; earlier sandbox npm lookup failed ENOTFOUND. Escalated skills installation now works; fresh compiler tool setup remains unverified. |
| F002 | Blocked by sandbox | Apply requested MileAhead guidance patch to trailmapper/AGENTS.md; filesystem approval denied outside workspace. Patch in docs/patches; no external edit claimed. |
| E001 | Planned | Full CST complexity, top-down ordering, naming, numeric and branch-expression budgets beyond essential gates. Review conventions already apply; do not spend initial slice on a full lint clone. |
| E002 | Planned | Test large/deep source limits and move parser passes to stack-safe traversals before compiler-sized Sprig inputs. Initial slice is intended for small programs; no hostile-input resource guarantee yet. |
| W001 | Resolved | Checkpoint 9624bec preserves Stage 0 and pinned skills; user approved audit worktree/inline execution. HEAD-based task helpers now have a real BASE. |
| F003 | Environment limit | Sandboxed Git inspection emits xcrun cache permission errors under /tmp; escalated inspection succeeds. Use approved access for Git operations and record the distinction; do not treat these as compiler failures. |
| E003 | Reviewed target exception | src/Sprig/Model.purs codeName has ten exhaustive ErrorCode branches against the eight-branch review target. Keep the wire mapping readable; reassess grouping when diagnostics grow, preserving every tag with exact rejection tests. |
| E004 | Minor, deferred | test/compiler.test.mjs:84 title overstates repeated CLI assertions; test/style.test.mjs:21–22 title overstates lazy-fallback fixture. Rename to snapshot agreement and named helpers with constant fallback; preserve assertions. Manual repeated emissions separately verified. |
