# Task 9 re-review 3
(1) Nested pure row note: ADDRESSED. src/Features/Check/Argument.purs:85-92 topRowPure now requires isPure top row and pureRows ty == 1; used at :48-49. Test test/fx-diagnostic-origins.test.mjs (new "two pure rows" test) asserts note at parameter `f`.
(2) N2 second test: ADDRESSED. test/fx-diagnostic-origins.test.mjs (late Fail key, `defer { b(B); a(A) }`) asserts code, message "defer must not fail, but it performs Fail(B)", primary span, note at `b(B)` "Fail(B) comes from this function value" and `fail(x` raise, via exact spans.
Probes (node vs output/): single pure top row -> note on `with pure`; two pure rows (nested, or curried) -> note on `f`; no pure parameter row -> unchanged (Unhandled Log, no parameter note). No new wrong note found. Target tests: 46/46 pass.
Task 9: Approve
