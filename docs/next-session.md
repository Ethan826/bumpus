# Prepare FN001 (P001 merged)

Workspace: /Users/ethan/Desktop/gofuncyourself, branch main (P001 merged
2026-10-08 at dcb40fb, T001 at 4230eb9, after E005 at 09f3071 and G001 at 44a735b; history
was rewritten by the user to shift commit times and is the history to
keep; origin/main is the remote). Read AGENTS.md, README.md,
docs/plans/bootstrap.md, docs/progress.md, docs/findings.md,
docs/engineering.md, ADRs 001-007 and BACKLOG.md. The uncommitted
.vscode/settings.json change predates this work.

State: A003, G001, E005, T001 and P001 are Done and merged. On main,
`rm -rf output && npm run verify` exits 0 with 318 tests and twelve
regression proofs (.build/p001-merge-verify.log). Not pushed (the user
declined a push for P001).
Decisions: docs/adr/007-specialization.md; archived execution ledger
with rulings R1-R20: .build/merged-p001-evidence/sdd/
2026-10-08-polymorphism-plan/progress.md.

Next steps, in order:
1. FN001 (first-class functions, lambdas, closures). Direction settled
   with the user 2026-10-08 (curried, `fn(x) => body`, `|>` in scope, no
   let; see BACKLOG and progress). The design draft is
   docs/plans/2026-10-08-functions-design.md; approved 2026-10-08;
   Amendment A1's architecture approved; the plan
   docs/plans/2026-10-08-functions-plan.md approved with changes. Task 1
   (measure the linked environment; no quadratic fallback) runs on branch
   fn001 in .worktrees/fn001; Tasks 2-9 depend on its result. FN001 precedes C001, R001 and
   FX001; review C001/R001 jointly and decide whether instances are
   ordinary records.

Long-term discussion is recorded in plans/2026-10-08-language-direction.md:
row/service architecture, explicit effects design (FX001), inspectable
lowered IR (L001), and future target evaluation (J001). These do not
authorize new implementation.

The same direction document records proposed `do` notation under FX001:
bind/lambda elaboration, result bindings and discarded results, final
computation, deferred execution, and inferred service/error requirements.
Syntax, bind/pure selection and monadic versus algebraic effects remain
open; this records discussion without authorizing implementation.

Open items: E002 remainder, E006-E011 (P001 follow-ups: stack margin,
exponential type size, Expand keys, lowercase-type hint, mismatch `_`,
near-limit elision), F001-F003, F005-F007, E001, E003, E004, O001, H001,
A002, A004, A005; design follow-ups FN001, FX001, L001, J001 and D001.
