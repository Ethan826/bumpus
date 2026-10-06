# Sprig stage 0 language specification

A file is a single program with required function signatures. Identifiers use
ASCII letters/underscore followed by ASCII letters/digits/underscore.
Whitespace is space, tab, CR, or LF. Keywords: fn, if, then, else, true, false,
Int, Bool. Comments and strings are not in this slice.

```ebnf
program    = { function } ;
function   = "fn", identifier, "(", [ parameters ], ")", ":", type,
             "=", expression, ";" ;
parameters = parameter, { ",", parameter } ;
parameter  = identifier, ":", type ;
type       = "Int" | "Bool" ;
expression = "if", expression, "then", expression, "else", expression
           | addition ;
addition   = atom, { "+", atom } ;
atom       = integer | "true" | "false" | identifier
           | identifier, "(", [ arguments ], ")"
           | "(", expression, ")" ;
arguments  = expression, { ",", expression } ;
integer    = [ "-" ], digit, { digit } ;
```

Tokenization occurs before parsing; whitespace may separate minus and digits.
Minus only belongs to integer literals; there is no subtraction or general
negation. Leading zeroes are accepted as decimal. Values must fit
[-2147483648, 2147483647]. Addition associates left and has higher precedence
than if. Parenthesize an if used as an addition operand.

Types are Int and Bool; no coercions. Addition requires Int operands. An if
requires Bool condition and equal branch types. Each call has exact arity and
parameter types; each body must agree with the declared result. Every function
is checked, including unused functions and unselected branches. There is no
inference of source signatures from PureScript types.

Functions are first-order and may call forward or recursively. No functions
as values, let bindings, closures, partial application, overloads, or effects.
A bare name denotes a parameter; a name in call position denotes a top-level
function unless shadowed by a parameter (then E_NOT_CALLABLE). Duplicate
functions/parameters are rejected. Exactly one main with no parameters is
required; it returns either primitive type.

Evaluation is strict, with argument and addition operand computations in
source left-to-right order; if evaluates its condition and only one branch.
Recursion can diverge and tail calls are not guaranteed. Int addition wraps
modulo 2^32, interpreted as signed two's-complement. The generated executable
prints main's returned value plus LF using fmt.Println. Printing is a backend
entry wrapper, not a source effect.

Locations are half-open UTF-16 code-unit offsets, zero based; line/column are
one based. LF increments line and resets column; CR and tab each advance one
column. Parenthesized expressions retain the enclosed expression's span.
AST expressions, parameters, and functions retain spans; resolution and IR
carry them forward. A diagnostic reports the first error in deterministic
phase/traversal order. E_INTERNAL is a compiler invariant failure, not an
ordinary invalid-source category. Codes are a closed ADT before JSON encoding.
