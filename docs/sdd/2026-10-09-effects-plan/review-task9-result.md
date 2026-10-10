# Review: FX001 Task 9 "Diagnostic quality" (e2c3809..2fc7a02)

Focused tests run: `node --test test/fx-diagnostics.test.mjs
test/fx-diagnostic-origins.test.mjs test/fx-signature.test.mjs`: 37/37 pass.
I also ran node probes against output/ (2fc7a02). Nothing in the working tree
was changed.

### Spec Compliance

- ✅ Diagnostic model. `NoteReason` replaces `RequiredBy`
  (src/Domain/Syntax.purs:18-32). The wire's `related` is
  `[{ span, message }]` (src/Format/Diagnostic/Note.purs:14,
  src/Format/Wire.purs).
- ✅ Interfaces match the brief exactly: `Consumed`, `Boundary`,
  `Origin = { span, consumed, via }` and the first-wins `remember`
  (src/Features/Check/Provenance.purs).
- ✅ Links live in `Subst.links`, first per occurrence wins, and `compose`
  keeps the earlier link (src/Features/Check/Subst.purs `linkTo`, `compose`).
- ✅ Links are recorded on every unification path:
  - `unifyRows`, through `linked`;
  - `consumeVia`;
  - `settleRows` retries, whose postponed pairs keep their `Sides`
    (Unify.purs:58-66).
  The hooks live in the new Origin.purs (ruling F13). UnifyRow.purs shrank
  from 249 to 243 lines.
- ✅ All note texts match the brief verbatim (Note.purs:85-101).
- ✅ The constants are named in Format.Diagnostic.Row: `visibleLabels` 4,
  `pathHops` 2, `maxNotes` 4, `maxCharacters` 2000.
- ✅ `unabbreviated` is a test-only full renderer, and the 50-label test
  first asserts that the unabbreviated text is over the bound
  (fx-diagnostics.test.mjs:80-83).
- ✅ Headline, primary span and distinguished kinds:
  - `LabelMismatch` is E_TYPE and elides off-path arguments.
  - Side condition: both rows, differing labels first, multiplicity counted,
    shared tail printed with the callee's variable name.
  - `Unhandled Fail(DbError) in main` (F9).
  - "(required by …)" is now an origin note (F10).
- ✅ Every test case listed in Step 1 is present.
  - Probes: a 1,000-deep chain checks in 0.44 s and a 3,000-deep chain in
    1.0 s, each with 7 notes, bounded.
- ✅ Pre-FX001 diagnostics:
  - `Format.Diagnostic.noted` (Diagnostic.purs) renders notes only for the
    7 effect/label problems, so every other diagnostic has `related: []` by
    construction.
  - No pre-FX001 test file was edited.
- ⚠️ Boundary spans (risk a):
  - "the signature does not allow" and "has an ambient row" point at the
    whole declaration (Reject.purs:60).
  - "this parameter must be pure" points at the parameter name
    (Use.purs:74,78).
  - "...e is declared here" points at the parameter name (DeferNotes.purs:81).
  - §6 asks for "the signature's `with`" and "the `with pure` parameter
    annotation". Syntax already has these spans (`RowRef Span`, `FunRef Span`);
    Resolved does not carry them.
- ⚠️ Character bound (risk b): only the notes are capped. The headline is not
  (Note.purs:71). For a large single label it goes over the bound; see I2.
- ❌ Defer through a `Fail` key settled after the `defer`: the brief wants
  "each with its origin note inside the deferred expression". The test
  (fx-diagnostic-origins.test.mjs:104-112) asserts only a note at
  `fail(x`, which is inside lambda `f`, outside `defer f(y)`. There is no
  note at `f(y)`. The called-function case does get its call note.

### Strengths

- The layering is clean:
  - unification never reads origins or links;
  - origins live in checker State;
  - the report logic is in Report, Reject and Path;
  - all rendering and bounds are in Format.
- Walks are loops with seen-sets (`trail`, `followed`), so the two-way
  `Matched` links cannot loop (risk d).
  - The reverse link (site label to first consumer) is what lets the walk
    continue into a callee, and it keeps "first origin wins".
  - Probes show no wrong attribution: two consumers of one signature label,
    repeated families, already-extended rows.
- Re-checking callees (risk c) happens only on the failure path. It is linear
  in chain depth: one re-check per (callee, index), and a re-check never
  recurses because callees succeed. There is no exponential case.
- `RowPayload` applies only to traced (consuming) unifications, so the Task 3
  unify-row tests stay unchanged. `Fail` keeps its family rules.
- The fx-signature edits (risk f) make the assertions stronger: `[]` became
  exact notes.
  - The regression needle tracks the renamed line, and its mutant still
    produces the wrong code.
- Style holds: all files are ≤ 250 lines and ≤ 80 characters (counted in
  characters).

### Issues

**Critical:** none.

**Important**

- **I1. Boundary notes do not point where §6 says** (Reject.purs:91-97 and :60;
  Use.purs:71-78; DeferNotes.purs:76-81).
  - The span is the whole declaration or the parameter name, not the
    `with` or the annotation.
  - Separately, `signature` classifies a row as ambient by its tail alone.
    By §2, `with Log` is `Log + ambient`. So the probe
    `fn s(): Int with Log = t()`, where `t` performs Clock, gets
    "the signature of s has an ambient row", although a `with` is written.
    §6 says "the signature's `with`, or the signature when its row is
    ambient".
  - Fix: carry the optional `with` row span on `Resolved.FunctionDecl` and
    on `Parameter` (small, mechanical: Syntax has it). Choose
    `AmbientSignature` only when no `with` was written.
  - Or get an explicit controller ruling accepting the declaration and name
    spans.
- **I2. `maxCharacters` does not bound the headline** (Note.purs:71-80).
  - `withinCharacters` drops notes only. The probe
    `Unhandled E(T<2,500 chars>) in main` totals 2,522 characters.
  - §6: "the character bound holds", and "each diagnostic has fixed bounds
    on … total characters".
  - Fix: either elide the label arguments in `labelName` headlines past a
    width (the same elision as `LabelMismatch`), or record a ruling that
    labels wait for E011's type elision, and name that gap in the progress
    entry.
- **I3. Missing in-`e` origin note for a key settled after the `defer`**
  (DeferNotes.purs:20-24; fx-diagnostic-origins.test.mjs:112).
  - The postponed consumption of `f(y)` records stage origins, but the trail
    reaches only the `fail`. The brief asks for a note inside the deferred
    expression.
  - Fix: assert and emit "Fail(E) comes from this function value" at `f(y)`
    before the raise note.

**Minor**

- **M1.** In the DeferMayPerform fallback (risk e), a named call carrying the
  rigid tail (probe `defer use(release)`) gets "any effect of ... comes from
  this function value" at `use(release)`. The span is fine, but the text says
  function value for a named call (DeferNotes.purs:35).
- **M2.** The "every pre-FX001 diagnostic keeps `related: []`" test samples
  9 sources (fx-diagnostics.test.mjs:147). The guarantee is structural
  (`noted`), so this is acceptable, but a comment should say so.
- **M3.** `Path.followed` appends `pending.notes <> …` on each hop
  (Path.purs:60), which is quadratic in depth. It only runs on failure and is
  negligible at 3,000 hops.
- **M4.** Out of scope for this diff, as a note only: the spec's same-key
  example says "note at the innermost `State(Int)`". The implementation (and
  the brief) note the innermost occurrence, `State(Bool)`. This is a spec
  wording ambiguity, not a code defect.

### Assessment

**Needs fixes:** I1, I2 and I3. Each can either be fixed small or ruled on by
the controller.
