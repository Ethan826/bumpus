module Format.Diagnostic
  ( WireDiagnostic
  , code
  , codeName
  , message
  , wire
  ) where

import Prelude
import Data.Array as Array
import Data.String (joinWith)
import Domain.Problem
  ( DuplicateKind(..)
  , EntryKind(..)
  , Problem(..)
  , TypeName(..)
  , UnboundKind(..)
  , Witness(..)
  )
import Domain.Syntax (Diagnostic, ErrorCode, Span)
import Domain.Syntax as Code

type WireDiagnostic = { code ∷ String, message ∷ String, span ∷ Span }

code ∷ Problem → ErrorCode
code = case _ of
  Lexical → Code.LexError
  Syntax _ → Code.SyntaxError
  IntegerOutOfRange → Code.IntegerRange
  NestingTooDeep _ → Code.NestingLimit
  EntryProblem _ → Code.EntryError
  Duplicate _ _ → Code.DuplicateName
  Unbound _ _ → Code.UnboundName
  NotCallable _ → Code.NotCallable
  CtorNotCallable _ → Code.NotCallable
  CtorNeedsArguments _ → Code.ArityMismatch
  Arity → Code.ArityMismatch
  FieldArity → Code.ArityMismatch
  TypeArguments _ → Code.ArityMismatch
  TypeMismatch _ _ → Code.TypeMismatch
  InfiniteType _ _ → Code.TypeMismatch
  RedundantArm → Code.Redundant
  NonExhaustive _ → Code.NonExhaustive
  Internal _ → Code.InternalError

codeName ∷ ErrorCode → String
codeName = case _ of
  Code.LexError → "E_LEX"
  Code.SyntaxError → "E_SYNTAX"
  Code.IntegerRange → "E_INTEGER"
  Code.NestingLimit → "E_NESTING"
  Code.EntryError → "E_ENTRY"
  Code.DuplicateName → "E_DUPLICATE"
  Code.UnboundName → "E_UNBOUND"
  Code.NotCallable → "E_NOT_CALLABLE"
  Code.TypeMismatch → "E_TYPE"
  Code.InternalError → "E_INTERNAL"
  Code.ArityMismatch → "E_ARITY"
  Code.Redundant → "E_REDUNDANT"
  Code.NonExhaustive → "E_NON_EXHAUSTIVE"

message ∷ Problem → String
message = case _ of
  Lexical → "Unexpected character"
  Syntax text → text
  IntegerOutOfRange → "Integer literal is outside signed 32-bit range"
  NestingTooDeep limit → "Nesting exceeds " <> show limit <> " levels"
  EntryProblem kind → entryMessage kind
  Duplicate kind name → "Duplicate " <> duplicateWord kind <> " " <> name
  Unbound kind name → "Unbound " <> unboundWord kind <> " " <> name
  NotCallable name → "Local is not callable: " <> name
  CtorNotCallable name → "Constructor is not callable: " <> name
  CtorNeedsArguments name → "Constructor " <> name <> " needs arguments"
  Arity → "Wrong number of arguments"
  FieldArity → "Wrong number of fields"
  TypeArguments name → "Wrong number of type arguments for " <> name
  TypeMismatch expected found → "Expected " <> typeName expected
    <> ", found "
    <> typeName found
  InfiniteType meta whole → "Infinite type: " <> typeName meta
    <> " occurs in "
    <> typeName whole
  RedundantArm → "Redundant match arm"
  NonExhaustive witness → "Missing pattern: " <> pattern witness
  Internal text → text

wire ∷ Diagnostic → WireDiagnostic
wire diagnostic =
  { code: codeName (code diagnostic.problem)
  , message: message diagnostic.problem
  , span: diagnostic.span
  }

entryMessage ∷ EntryKind → String
entryMessage = case _ of
  MissingEntry → "Expected fn main()"
  EntryParameters → "main must have no parameters"
  EntryPolymorphic → "Expected fn main() with a concrete result type"

duplicateWord ∷ DuplicateKind → String
duplicateWord = case _ of
  DuplicateType → "type"
  DuplicateConstructor → "constructor"
  DuplicateFunction → "function"
  DuplicateParameter → "parameter"
  DuplicateBinder → "binder"
  DuplicateTypeParameter → "type parameter"

unboundWord ∷ UnboundKind → String
unboundWord = case _ of
  UnboundLocal → "local"
  UnboundFunction → "function"
  UnboundConstructor → "constructor"
  UnboundType → "type"
  UnboundTypeVariable → "type variable"

typeName ∷ TypeName → String
typeName = case _ of
  IntName → "Int"
  BoolName → "Bool"
  DataName name → name
  AppliedName name arguments → name <> listed (map typeName arguments)
  VariableName name → name
  HoleName → "_"

-- Witnesses print as Bumpus patterns: `_`, literals, `Name(field, …)`.
pattern ∷ Witness → String
pattern = case _ of
  WAny → "_"
  WInt value → show value
  WBool value → show value
  WCtor name fields → name <> listed (map pattern fields)

-- `(a, b)`, or nothing for no items: `Nil`, not `Nil()`.
listed ∷ Array String → String
listed items =
  if Array.null items then ""
  else "(" <> joinWith ", " items <> ")"
