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
  EntryProblem _ → Code.EntryError
  Duplicate _ _ → Code.DuplicateName
  Unbound _ _ → Code.UnboundName
  NotCallable _ → Code.NotCallable
  CtorNotCallable _ → Code.NotCallable
  CtorNeedsArguments _ → Code.ArityMismatch
  Arity → Code.ArityMismatch
  FieldArity → Code.ArityMismatch
  TypeMismatch _ _ → Code.TypeMismatch
  RedundantArm → Code.Redundant
  NonExhaustive _ → Code.NonExhaustive
  Internal _ → Code.InternalError

codeName ∷ ErrorCode → String
codeName = case _ of
  Code.LexError → "E_LEX"
  Code.SyntaxError → "E_SYNTAX"
  Code.IntegerRange → "E_INTEGER"
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
  EntryProblem kind → entryMessage kind
  Duplicate kind name → "Duplicate " <> duplicateWord kind <> " " <> name
  Unbound kind name → "Unbound " <> unboundWord kind <> " " <> name
  NotCallable name → "Local is not callable: " <> name
  CtorNotCallable name → "Constructor is not callable: " <> name
  CtorNeedsArguments name → "Constructor " <> name <> " needs arguments"
  Arity → "Wrong number of arguments"
  FieldArity → "Wrong number of fields"
  TypeMismatch expected found → "Expected " <> typeName expected
    <> ", found "
    <> typeName found
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

duplicateWord ∷ DuplicateKind → String
duplicateWord = case _ of
  DuplicateType → "type"
  DuplicateConstructor → "constructor"
  DuplicateFunction → "function"
  DuplicateParameter → "parameter"
  DuplicateBinder → "binder"

unboundWord ∷ UnboundKind → String
unboundWord = case _ of
  UnboundLocal → "local"
  UnboundFunction → "function"
  UnboundConstructor → "constructor"
  UnboundType → "type"

typeName ∷ TypeName → String
typeName = case _ of
  IntName → "Int"
  BoolName → "Bool"
  DataName name → name

-- Witnesses print as Sprig patterns: `_`, literals, `Name(field, …)`.
pattern ∷ Witness → String
pattern = case _ of
  WAny → "_"
  WInt value → show value
  WBool value → show value
  WCtor name fields → name <> arguments fields

arguments ∷ Array Witness → String
arguments fields =
  if Array.null fields then ""
  else "(" <> joinWith ", " (map pattern fields) <> ")"
