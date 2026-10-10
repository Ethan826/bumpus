# User requirements: backend-maintainability proposal (2026-10-10, verbatim)

Add a bounded backend-maintainability proposal as feasible within the current running/planned tasks. Do not implement it now or expand the current milestone.
Review direct string assembly in Format.Go, especially functions that mix layout calculations with long chains of punctuation, signatures, loops, switches, and calls. Assess whether a small Go syntax representation and composable renderer would improve readability, correctness, and future backend work.
The proposal should:

* Separate semantic/layout planning from target syntax construction and final rendering.
* Compare lightweight rendering helpers, pretty-printing documents, and a target AST for the subset of Go we actually generate.
* Evaluate existing libraries only where compatible with our PureScript implementation and dependencies. Avoid introducing another runtime or tool boundary without a concrete benefit.
* Show a proposed before/after sketch using the wrapper-entry generator as a representative example.
* Explain what each approach prevents: formatting errors, malformed syntax, precedence mistakes, or invalid statement placement. Distinguish these from target type correctness and semantic preservation, which require additional validation.
* Consider separate representations for identifiers, literals, expressions, statements, and declarations where they prevent demonstrated mistakes.
* Preserve explicit evaluation order, deterministic output, generated naming, and current runtime contracts.
* Allow fixed runtime support to remain readable templates where appropriate.
* Recommend an incremental migration with existing executable tests and snapshots, documenting any intentional output changes.

For future targets, propose a shared compiler IR feeding separate backend implementations. Keep target ASTs language-specific: Go, C, JavaScript, LLVM, and WASM should not be forced into a universal syntax tree. Identify genuinely reusable pieces such as document rendering, naming utilities, and source-location infrastructure. Explain where a future target-neutral lowered IR would help, without prematurely designing it.
Recommend the smallest useful abstraction based on repeated patterns and actual failure risks. Record its priority relative to concurrency foundations and other planned work. Complete Task 8 and its handoff, then stop for user review.
