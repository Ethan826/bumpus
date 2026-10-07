# Sprig language specification (stage 0 plus closed ADTs)

Provisional name. A file is one program: type declarations and functions in
any order, with required function signatures. Behavioral claims below name
their verifying test file in test/.

Identifiers: ASCII letters/underscore then letters/digits/underscore.
Whitespace: space, tab, CR, LF. Reserved words: `fn if then else true false
Int Bool type match`, and the lone `_`. `type`, `match` and `_` were
identifiers in Stage 0 (ADR 003). Punctuation includes `|`, `{`, `}` and the
single token `=>` (adt-syntax). Comments and strings do not exist.

```ebnf
program     = { declaration } ;
declaration = typedecl | function ;
typedecl    = "type", upper, "=", ctor, { "|", ctor }, ";" ;
ctor        = upper, [ "(", type, { ",", type }, ")" ] ;
function    = "fn", identifier, "(", [ parameters ], ")", ":", type,
              "=", expression, ";" ;
parameters  = parameter, { ",", parameter } ;
parameter   = identifier, ":", type ;
type        = "Int" | "Bool" | upper ;
expression  = "if", expression, "then", expression, "else", expression
            | "match", expression, "{", arm, { ",", arm }, [ "," ], "}"
            | addition ;
arm         = pattern, "=>", expression ;
pattern     = "_" | lower | upper, [ "(", pattern, { ",", pattern }, ")" ]
            | integer | "true" | "false" ;
addition    = atom, { "+", atom } ;
atom        = integer | "true" | "false" | identifier
            | identifier, "(", [ arguments ], ")" | "(", expression, ")" ;
arguments   = expression, { ",", expression } ;
integer     = [ "-" ], digit, { digit } ;
upper       = identifier starting with "A".."Z" ;
lower       = identifier starting with "a".."z" or "_", other than "_" ;
```

A constructor field list must be nonempty (`C()` is E_SYNTAX). Type and
constructor names must be `upper`; `Int` and `Bool` are reserved, so
`type Int = A;`, `type Bool = A;` and `type T = Int;` are E_SYNTAX. `match`
and `if` are expression forms at the same level, so either must be
parenthesized as an addition operand; an empty `match x {}` is E_SYNTAX; a
trailing comma is accepted (adt-match). Minus belongs only to integer literals
(may be separated by whitespace); leading zeroes are decimal; values must fit
int32 (E_INTEGER). Integer patterns use the same syntax.

## Semantics

Types: `Int`, `Bool`, and declared types (monomorphic, closed, recursive,
mutually recursive in any declaration order; adt-types). No coercions.
Addition needs Int operands; `if` needs a Bool condition and equal branch
types; calls need exact arity and types. Every function is checked, including
unused ones and unreachable arms.

Names. Types, and functions plus constructors (one global table), are distinct
namespaces; locals are parameters then pattern binders. A bare name is a
local, else a nullary constructor; a bare function name is E_UNBOUND; a bare
constructor with fields is E_ARITY. In call position a local is
E_NOT_CALLABLE, a function is a call, a constructor with fields is a
construction, a nullary constructor is E_NOT_CALLABLE. A binder shadows a
parameter within its own arm only; outside it is E_UNBOUND; a binder called as
a function is E_NOT_CALLABLE. Duplicate types, globals, parameters or binders
(`Pair(a, a)` is never equality) are E_DUPLICATE at the first duplicated
declaration in source order, whatever its kind (`fn A(): Int = 1; type T = A;`
reports the function). `main` takes no parameters and returns Int or Bool; a
named result type is E_ENTRY. Rejection fixtures: test/diagnostics.test.mjs,
adt-types, adt-match.

Patterns. `_` matches anything; a lowercase name binds; an uppercase name is a
constructor with exactly its field count (E_ARITY); literals match their
primitive type. Pattern type errors are E_TYPE at the pattern. All arm bodies
must have the first arm's type.

Coverage. After the whole program type-checks, each match is checked in
source pre-order, functions in declaration order. The first redundant arm is
E_REDUNDANT (at its pattern); then a non-exhaustive match is E_NON_EXHAUSTIVE
(at the whole match) with message `Missing pattern: <witness>`, rendered like
`Cons(_, Nil)`, `false`, `2`. Witnesses never name an uninhabited
constructor. A type with no inhabited constructor (`type T = C(T);`) is legal;
a wildcard over only such a remainder is E_REDUNDANT (adt-coverage;
coverage.test.mjs compares with a brute-force oracle).

Evaluation is strict, operands and arguments left to right; `if` and `match`
evaluate the scrutinee/condition and only the selected branch. Arms are tried
in order. Deep structures work: an 8192-element list built by doubling sums
correctly (adt-match). Int addition wraps modulo 2^32. The executable prints
`main`'s value plus LF; printing is a backend wrapper, not a source effect.
ADT values cannot be printed, compared or returned from `main`.
Foreign (Go) values are not validated: Proposed, with I001.

Locations are half-open UTF-16 code-unit offsets, zero based; line/column one
based; LF increments line and resets column. Parenthesized expressions keep
the inner span. A diagnostic reports the first error in phase/traversal order.
E_INTERNAL is a compiler invariant failure. Codes are a closed ADT: E_LEX,
E_SYNTAX, E_INTEGER, E_ENTRY, E_DUPLICATE, E_UNBOUND, E_NOT_CALLABLE, E_TYPE,
E_ARITY, E_REDUNDANT, E_NON_EXHAUSTIVE, E_INTERNAL. The CLI adds E_USAGE,
E_IO and E_TOOL.
