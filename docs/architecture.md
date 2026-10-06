# Compiler architecture

The semantic pipeline is pure:

```text
String -> Parse -> Syntax -> Resolve -> Resolved -> Check -> typed IR -> Go
                                                    Either Diagnostic
```

Sprig.Model owns raw syntax, ground types, spans, and tagged diagnostics.
Lex and Parse.* consume text/tokens. Resolve builds deterministic function and
local IDs, checks duplicate definitions, and resolves names. Resolved has its
own expression representation. Check consumes only resolved syntax, enforces
language types, and elaborates explicit typed IR. Go consumes CheckedProgram
and emits deterministic text. Compiler composes phases; Shell.CLI performs
filesystem, process, argv, environment, and logging work through a small FFI.
Expected source errors use Either. Shell maps them to JSON wire diagnostics;
IO/tool failures are tagged boundary values. The semantic core has no FFI.

IR.Internal wraps each expression node with explicit Ty/span annotations. Checking is the
only producer used by the pipeline. CheckedProgram has no publicly exported
constructor at the Check facade; the internal representation is exported to
checking/lowering and protected by a parsed dependency graph allowlist.
This is an enforced project boundary, not a claim that PureScript has private
subtrees. The resolver produces IDs indexing known definitions. The checker reports
E_INTERNAL for invalid local or called-function indices encountered during
expression checking. Its exported resolved-syntax input is a trusted phase
interface: it does not independently validate arbitrary forged entry IDs or
function-table IDs. This is not a general hostile-IR validator.

The present Type grammar contains only two ground constructors of kind Type.
No separate kind solver is needed yet. There are no patterns or class
constraints; coverage and instance resolution are not implemented. Their
future responsibilities remain distinct from expression type inference.
Future stages will be Syntax -> Resolved -> Kinded -> Checked constraints ->
coverage/instances -> Elaborated IR -> lowered Go IR -> emitted Go.
Do not add fake success stages for features absent from the grammar.

Go generation preserves scalar annotations, uses mangled IDs, contains no nil
or open sum payloads, and returns initialized expressions from all functions.
There is no mutable source state, uninitialized source variable, or zero-value
construction. Go's scalar zero values are valid source values. For future ADTs,
reserve tag zero as invalid, expose constructors only, and validate tag/payload
consistency at Go FFI boundaries. Arbitrary Go zero values or nil must never
silently become inhabited closed source sums. Records/boxing must obey the
same boundary invariant. See ADR 002 for the planned representation strategy.

Generated Go is canonical emitter output; gofmt can format a presentation copy
but bootstrap comparisons use original bytes. No timestamps, absolute paths,
or source identifier spellings influence names. Declaration order determines
IDs; comparisons use the same source and compiler configuration.
