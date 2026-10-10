# Re-review 2: FX001 Task 9 fix round 2 (04ab898..cee8542)

I read the fix diff (rereview2-task9.diff) once. Focused tests:
`node --test test/fx-diagnostics.test.mjs test/fx-diagnostic-origins.test.mjs
test/fx-signature.test.mjs` passes 45/45. I also ran node probes against
output/ (cee8542). Nothing in the tree was changed.

### Finding Verdicts

- **N1 (nested-arrow boundary notes): fixed for the reported shapes, with one
  residual wrong-`with` shape.**
  - Both earlier probes now land on the parameter name:
    - `f: Int -> (Int -> Int with pure) with Log` gives "this parameter must
      be pure" at `f`;
    - `k: (Unit -> Unit with ...e) -> Unit with pure` gives "...e is
      declared here" at `k`.
  - The tests for both shapes are present.
  - When the tail is both top-level and nested
    (`k: (Unit -> Unit with ...e) -> Unit with ...e`), the note is at the
    outer `with ...e`. That is correct, because it is a mention of `...e`.
  - Falling back to the name for a nested row is acceptable under §6.
    - It is imprecise, not wrong: the note still names the boundary
      parameter.
    - A per-arrow span is feasible: `Syntax.FunRef` carries a `RowRef` span
      for every arrow, and `Resolve/Types.arrowRows` already walks them. It
      can wait for a later precision pass.
  - **Residual (Minor, but it is a wrong note of the kind N1 named):**
    - Source: `Argument.purs` `topRowPure`. It asks only whether the
      top-level row is pure, not whether that row is the one violated.
    - Probe: `fn once(f: Int -> (Int -> Int with pure) with pure): Int = 0;`
      with `main ... = once(fn(x) => fn(y) => { log(y); y })`. The outer
      lambda is pure and the inner one performs Log. The note "this
      parameter must be pure" lands on the outer `with pure` (offset 79)
      instead of the inner one (offset 68).
    - When only the top row is violated (`fn(x) => { log(x); fn(y) => y }`),
      offset 79 is correct.
    - Fix, one line: use `rowSpan` only when the top row is pure and no
      nested row is pure. Equivalently, require
      `Array.length (Array.filter isPure (rowsOf expected)) == 1` together
      with `topRowPure`. Otherwise fall back to the name. Add this probe as
      a test.
- **N2 (late-Fail-key note blames the wrong call): fixed. No wrong
  `brought` note found.**
  - Both reported probes are correct:
    - `defer { k(()); a(A) }` gives the note at `a(A)`;
    - `defer { b(B); a(A) }` gives the note at the reported family's call;
    - shadowing by LocalId (`a2(B); a(A)` in either order) is attributed
      correctly.
  - Correct notes in other shapes:
    - a nested block inside the defer;
    - a `let` inside the deferred expression;
    - a `defer` inside a lambda;
    - an enclosing `let outer = { let a = …; a }` called as `outer(A)`;
    - two defers.
  - Misses, which give no `brought` note; the "Fail(A) is raised here" note
    is still emitted:
    - a lambda literal applied directly;
    - a local bound through another local (`let c = a`, with or without a
      preceding innocent call);
    - a wrapper local (`let w = fn(y) => a(y)`);
    - `p(a)(A)`;
    - a callee whose body calls the failing local (`m(())`).
  - Not misses, because they take the `viaCall` path through origin notes:
    - a top-level named function gives "comes from this call of a";
    - a parameter callback gives "comes from this function value" at `f(A)`.
  - "No note" is acceptable under §6.
    - The required notes are the origin (`fail`) and the boundary, and both
      remain.
    - The application note is an aid for an origin that would otherwise be
      lost. A miss loses precision; it does not mislead.
  - Can the heuristic give a wrong note in principle? Only if a local's
    definition lexically contains the raising `fail` without bringing it.
    The only shape I found is a factory (`let mk = fn(u) => fn(x: A) =>
    fail(x)`). There the checker itself types `mk(())` as failing, because
    `let` rows are monomorphic: `defer { let z = mk(()); () }` alone is
    rejected. That note comes from the origin trail, not from `brought`, so
    it is not new.
  - Linearity of `settleDeferred` receiving `whole`:
    - `failureNotes` is built only on the `Left` path (inside `named`). The
      success path does no new walk.
    - On an error, `letsContaining` and `boundCall` walk the body once each,
      for the single report.
    - Probe: 20,000 `let`s plus 200 defers plus a failing defer reports in
      about 0.8 s, the same as the non-reporting run. The walkers recurse
      by expression depth, like the existing `firstApplication`, so stack
      exposure does not change.
- **I2 bound comment: fixed.** `Row.purs` now says:
  - `maxLabelCharacters` bounds labels only;
  - `maxCharacters` hard-bounds notes but not a headline;
  - long leaf type and effect names are the E011 gap.

  This is accurate. One condition is still open for the controller:
  BACKLOG/progress does not yet name the gap. The fix report says "for
  BACKLOG", and E011's row does not mention effect-label headlines. Add it
  at task close.

### New Breakage

- No regressions found. The wire shape is unchanged, the earlier-round tests
  pass, and pre-FX001 diagnostics are untouched (no test edits outside
  fx-diagnostic-origins).
- The only defect is the N1 residual above: a nested `with pure` violated
  under an outer `with pure` gets the outer span.

### Out-of-Scope Observations

- Origin-trail notes can point outside the deferred expression. Both cases
  are pre-existing: `originNotes` is unchanged, and the `viaCall` gate
  matches the old `consumed` gate exactly, because Consumed has 4
  constructors.
  - `let a = fn(x) => fail(x); a(A); defer { a(A) }` gives two "comes from
    this function value" notes. The second is at the pre-defer `a(A)`, and
    there is no "raised here" note.
  - In the factory shape, a note lands at `let a = mk(())`.
- The second N2 test accepts either family (the headline picks A or B). It
  pins the note to the call of the reported family, which is the invariant,
  but it does not fix which family is reported.
- Monomorphic `let` rows make a factory call (`mk(())`) count as performing
  its result's `Fail`. This is a typing-precision matter, not Task 9's.

Task 9: Needs fixes
