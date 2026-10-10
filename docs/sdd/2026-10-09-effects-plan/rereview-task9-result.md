# Re-review: FX001 Task 9 fix round 1 (2fc7a02..04ab898)

I read the fix diff (rereview-task9.diff) once. Focused tests:
`node --test test/fx-diagnostics.test.mjs test/fx-diagnostic-origins.test.mjs
test/fx-signature.test.mjs` passes 41/41. I also ran node probes against
output/ (04ab898). Nothing in the tree was changed.

### Finding Verdicts

- **I1 (boundary spans): partially fixed.**
  - What works:
    - `Resolved.FunctionDecl.rowSpan` and `Parameter.rowSpan` are carried by
      Resolve.
    - `signatureNote` picks `AmbientSignature` only when no `with` is
      written. `with Log` gives "the signature of stamp does not allow
      Clock" at `with Log` (tested).
    - `with pure` and `with ...e` point at the written row.
    - The headline text and primary span are unchanged.
  - New defect (see New Breakage N1): `annotationSpan` takes only the
    parameter's top-level arrow row. When the relevant row is nested, the
    note lands on a different `with`.
- **I2 (character bound): fixed for FX001's required cases.**
  - Covered:
    - `Unhandled E(…) in main`;
    - the 50-label row, with the missing label and `...r` still named;
    - the long-label row conflict.
  - The string-level `shortLabel` meets §6 for these cases. In a
    missing-label headline the whole label is the difference: no
    differing subterm sits inside it, so `Effect(…)` keeps the effect
    name and the relationship.
  - Payload mismatch: `mismatchMessage` / `elideLabels` do not go through
    `shortLabel`. The structural path elision is unchanged, so
    `State(Pair(…, List(Bool)))` vs `State(Pair(…, List(Int)))` still
    shows the differing subterm. Cutting does not hide it. Only the
    "the innermost X is here" note text is shortened, and that note is a
    location.
  - Structural elision is not needed now.
  - But `maxCharacters` is still not a hard bound, though Row.purs:800-803
    claims "the whole diagnostic stays within maxCharacters". Probes:
    - a payload mismatch `State(T<2,500 chars>)` vs `State(Int)` gives a
      2,535-character headline;
    - an effect with a 2,500-character name gives 2,548.
  - Both are leaf-name length, which is E011's type elision (§6: "Types
    inside labels use E011's elision once it exists").
  - Accept, if the controller agrees, on two conditions:
    - the comment is corrected;
    - the gap (long leaf names in payload-mismatch headlines and in
      effect names) is named in the progress entry.
- **I3 (in-`e` note for a late-settled Fail key): fixed for the tested
  shape, but the attribution is wrong in other shapes** (N2).
- **Minor e / M1 (named-call wording): fixed.** `defer use(release)` gives
  "any effect of ... comes from this call of use" at `use(release)`
  (tested).
- **M2: fixed.** The comment states the structural guarantee.
- **M3 and M4:** not addressed. Both are acceptable as they stand.

### New Breakage

- **N1 (Important): a nested arrow parameter's note points at the wrong
  `with`.** Source: Resolve.purs `annotationSpan`, used by Use.purs:78 and
  DeferNotes.purs:347.
  - Probe:
    `fn once(f: Int -> (Int -> Int with pure) with Log): Int with Log`.
    A Log-performing inner lambda gets "this parameter must be pure" at
    `with Log`.
  - Probe: `k: (Unit -> Unit with ...e) -> Unit with pure` gets "...e is
    declared here" at `with pure`.
  - Before the fix, both notes pointed at the parameter name: imprecise,
    but not wrong.
  - Fix:
    - use `rowSpan` only when the top-level arrow's row is the one
      concerned (its tail is the variable, or it is the pure row);
    - otherwise fall back to the parameter span;
    - or carry per-row spans.
  - Add a nested-arrow test.
- **N2 (Important): the I3 note picks the first application whose resolved
  row holds any `Fail`.** Source: DeferNotes.purs:248-260 `brought` /
  `firstApplication failing`.
  - Lambda rows in a block resolve to the shared row, so innocent
    applications match:
    - `defer { k(()); a(A) }` with `k = fn(u) => u` gives "Fail(A) comes
      from this function value" at `k(())`;
    - `defer { b(B); a(A) }` puts the Fail(A) note at `b(B)`.
  - This regresses the earlier strength "no wrong attribution".
  - Fix: choose the application tied to the reported label. One way is
    the application whose callee's value contains the hop's `fail` span,
    or whose consumption origin matches the occurrence. Otherwise emit no
    `brought` note rather than a wrong one. Add the two probes as tests.
- **Wire JSON and stack safety: no change.**
  - `rowSpan` lives only on Resolved and the checker env, so the wire
    shape is `{code, message, span, related}` as before.
  - Pre-FX001 diagnostics are untouched, and the only test edits are to
    FX001 note spans.
  - `annotationSpan` is a non-recursive match per parameter. Probes:
    - 20,000 `Int -> Int with pure` parameters compile in about 1.5 s;
    - 20,000 parameters plus an effect error report in 0.4 s.

### Out-of-Scope Observations

- Two same-effect labels longer than 120 characters both print as `E(…)`
  in a row conflict (for example `E(…) + E(…) + ...r and E(…) + ...r`).
  The multiplicity shows, but which payload differs does not. This is an
  edge case, to be resolved with E011.
- `shortLabel` cuts at the first `(`, so a long effect name with no
  arguments is not shortened at all. This is the same E011-scope gap as
  the I2 residual.
- `with ...` / `with Log + ...` do not parse (E_SYNTAX "Expected an
  identifier"). This matches §2's spelling, so it is not a defect here.
