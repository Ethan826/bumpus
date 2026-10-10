### Task 9: Diagnostic quality

**Files:**
- Modify: `src/Features/Check/Subst.purs` (occurrence links, merged on
  composition), `src/Features/Check/UnifyRow.purs` (only calls into the
  hook module; no net growth, 249 lines), `src/Features/Check/Unify.purs`
  (`settleRows` retries record links: deferred `Fail` keys, F13),
  `src/Features/Check/Consume.purs` (`consumeAt` records the consuming
  origin), `src/Features/Check/Defer.purs` and `src/Features/Check.purs`
  (deferred-row origins and the `defer` boundary), the consuming
  checkers that pass a `Consumed` (Operation, Call, Apply, Failure,
  Lambda as needed, compile-guided as F19), `src/Domain/Syntax.purs`
  (`NoteReason`), `src/Format/Diagnostic.purs` (calls only; 232 lines),
  `src/Format/Wire.purs` (`related` as rendered `{ span, message }`)
- Create: `src/Features/Check/Provenance.purs` (origins and links),
  `src/Features/Check/Origin.purs` (row-event hooks, ruling F13),
  `src/Format/Diagnostic/Row.purs` (abbreviation),
  `src/Format/Diagnostic/Note.purs` (note texts, paths),
  `test/fx-diagnostics.test.mjs`

**Interfaces:**
- §6 exactly. `Provenance`: `Map OccurrenceId Origin` (Task 3's
  occurrence identity) with `Origin = { span, consumed ∷ Consumed, via ∷
  Maybe Boundary }`. Both `RowEvent`s attribute origins: `Extended m o`
  records the consuming origin for the new occurrence `Extended m`;
  `Matched o existing` (a consumed label matched an existing entry,
  written or extended, without extending any meta) records the origin for
  `existing` if it has none yet, and links `o` to `existing` so later
  attribution follows the matched occurrence. First origin per
    occurrence wins; occurrences are never merged by effect key. Links are
  recorded by every row unification, not only by `unifyRowsTraced` callers:
  they live in the substitution (`links ∷ Map OccurrenceId OccurrenceId`,
  first link per occurrence wins, merged when substitutions compose). That
  covers rows nested in arrow types (a callback's row reaching a `with pure`
  parameter) and `settleRows` retries of deferred `Fail` keys (Unify.purs).
  Origins (`Map OccurrenceId Origin`, in checker state) are recorded where a
  label is consumed. Neither map is read by unification. A test runs every
  pre-FX001 rejection and acceptance test unchanged, and one asserts that all
  non-effect diagnostics have `related: []`. Reports reconstruct paths from
  these links; nothing grows per call during checking.
- Abbreviation constants (named, in Format.Diagnostic.Row):
  `visibleLabels = 4`, `pathHops = 2` at each end, `maxNotes = 4`,
  `maxCharacters = 2000`; type arguments elided off the path to the
    differing subterm.
- Deferred rows (Task 8): `defer e` is checked against its own row, separate
  from the function row. Origins of its labels are recorded inside `e`.
  Consuming them into the enclosing row (in `checkDefer`, and for labels that
  arrive later in `settleDeferred`) links each enclosing occurrence to its
  deferred occurrence with boundary `DeferItem`. `defer must not fail, but it
  performs <L>` keeps the `defer` item as primary span and gets an origin note
  at the operation, call or `fail` inside `e` that introduced L, following
  links through a called function's row and a `Fail` key settled after the
  `defer`. `defer must not fail, but it may perform any effect of <r>` gets a
  note at the application whose row carried the rigid tail (a callback
  parameter, or a local lambda also called outside the `defer`) and a boundary
  note at <r>'s declaration (the enclosing signature for `...`, the `...e`
  annotation for a named row). Provenance adds no unification after
  `settleDeferred` (an unsolved deferred tail is not bound; see §3 R11).
- `Consumed = Operation String | CallOf String | Application | FailOf String`;
  `Boundary = Signature String | AmbientSignature String | PureParameter |
  Installation String | Main | DeferItem`. `NoteReason` (Domain.Syntax;
  replaces the unused `RequiredBy`) and texts, rendered in
  Format.Diagnostic.Note: origin `<L> is performed here` / `<L> comes from
  this call of <f>` / `<L> comes from this function value` / `Fail(<T>) is
  raised here`; path `through <f>`, elision `… <k> more calls`; boundary `the
  signature of <f> does not allow <L>` / `the signature of <f> has an ambient
  row` / `this parameter must be pure` / `<L> is handled here` / `main may
  perform only Console` / `cleanup registered here must not fail` / `<r> is
  declared here`; same-key `the innermost <L> is here`. The wire's `related`
  is `[{ span, message }]`.

- [ ] **Step 1: Write failing tests** asserting code, primary span, each
  note's span and text, and output length: a 30-deep call chain missing
  Database at `main`; an operation in a lambda passed through three
  higher-order functions into a `with pure` parameter; a 50-label row missing
  one label (Review Focus 5; its labels carry type arguments so that the
  unabbreviated rendering exceeds `maxCharacters` (asserted first, through a
  test-only full renderer exported by Format.Diagnostic.Row), and the
  abbreviated diagnostic is within it); a same-key payload mismatch under
  nested `State` handlers with a note at the innermost occurrence; the side
  condition; repeated `Fail` families attribute each origin to its own
  occurrence; a label consumed into a signature-written row (match without
  extension) and one consumed into an already-extended meta row both get
  origin notes; `Unhandled Fail(DbError) in main` (F9 spelling) with an origin
  note at the `fail`; the existing headline `Unhandled <L> in main` is kept
  and "(required by …)" is an origin note (F10); `defer must not fail, but it
  performs Fail(E)` through a called function and through a `Fail` key settled
  after the `defer`, each with its origin note inside the deferred expression;
  `defer must not fail, but it may perform any effect of ...` (callback
  parameter) and `... of ...e` (named row), with notes at the application and
  at the row's declaration; every pre-FX001 diagnostic keeps `related: []`.
- [ ] **Step 2: Run** `node --test test/fx-diagnostics.test.mjs`.
  Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `rm -rf output && npm run verify`. `npm run verify`
  exits 0, or fails only in its serial phase on the BACKLOG T007 timing set,
  named in the progress entry and failing identically at the task's base
  commit; verify then stops before the regression proofs, so `node
  scripts/regression.mjs` is run explicitly and must exit 0. No bound is
  raised and no rerun hides a failure.
- [ ] **Step 5: Commit** `feat: effect diagnostic provenance (FX001)`.

