module Format.Diagnostic
  ( WireDiagnostic
  , code
  , codeName
  , message
  , typeName
  , wire
  ) where

import Prelude
import Control.Monad.Rec.Class (Step(..), tailRec)
import Data.Array as Array
import Data.String (joinWith)
import Domain.Problem
  ( DuplicateKind(..)
  , EntryKind(..)
  , Hint(..)
  , Problem(..)
  , TypeName(..)
  , UnboundKind(..)
  , Witness(..)
  )
import Domain.Syntax (Diagnostic, ErrorCode, Note, Span)
import Domain.Syntax as Code

type WireDiagnostic =
  { code ∷ String, message ∷ String, span ∷ Span, related ∷ Array Note }

code ∷ Problem → ErrorCode
code = case _ of
  Lexical → Code.LexError
  Syntax _ → Code.SyntaxError
  IntegerOutOfRange → Code.IntegerRange
  NestingTooDeep _ → Code.NestingLimit
  TypeTooDeep _ → Code.NestingLimit
  EntryProblem _ → Code.EntryError
  Duplicate _ _ → Code.DuplicateName
  Unbound _ _ → Code.UnboundName
  NotCallable _ → Code.NotCallable
  CtorNotCallable _ → Code.NotCallable
  FunctionNeedsCall _ → Code.ArityMismatch
  Arity → Code.ArityMismatch
  FieldArity → Code.ArityMismatch
  TypeArguments _ → Code.ArityMismatch
  TypeMismatch _ _ → Code.TypeMismatch
  NotAFunction _ → Code.TypeMismatch
  InfiniteType _ _ → Code.TypeMismatch
  NotComparable _ → Code.TypeMismatch
  AmbiguousType _ → Code.TypeMismatch
  PolymorphicRecursion _ → Code.SpecializationError
  NestedDatatype _ → Code.SpecializationError
  SpecializationLimit _ → Code.SpecializationError
  RedundantArm → Code.Redundant
  NonExhaustive _ → Code.NonExhaustive
  Internal _ → Code.InternalError
  Hinted problem _ → code problem
  EffectNotAllowed _ _ → Code.EffectError
  UnhandledEffect _ → Code.EffectError
  MustBePure _ → Code.EffectError
  RowEquality _ _ _ → Code.EffectError
  RowSort _ → Code.TypeMismatch
  NotPrintable _ → Code.TypeMismatch
  DeferMayFail _ → Code.EffectError
  HandlerMissing _ → Code.HandlerError
  HandlerDuplicate _ → Code.HandlerError
  HandlerOperation _ _ → Code.HandlerError
  FailNeedsConcrete → Code.TypeMismatch
  ExpectedHandler _ → Code.TypeMismatch

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
  Code.SpecializationError → "E_SPECIALIZATION"
  Code.EffectError → "E_EFFECT"
  Code.HandlerError → "E_HANDLER"

message ∷ Problem → String
message = case _ of
  Lexical → "Unexpected character"
  Syntax text → text
  IntegerOutOfRange → "Integer literal is outside signed 32-bit range"
  NestingTooDeep limit → "Nesting exceeds " <> show limit <> " levels"
  TypeTooDeep limit → "Inferred type nesting exceeds " <> show limit
    <> " levels"
  EntryProblem kind → entryMessage kind
  Duplicate kind name → "Duplicate " <> duplicateWord kind <> " " <> name
  Unbound kind name → "Unbound " <> unboundWord kind <> " " <> name
  NotCallable name → "Local is not callable: " <> name
  CtorNotCallable name → "Constructor is not callable: " <> name
  FunctionNeedsCall name → "Expected " <> name <> "()"
  Arity → "Wrong number of arguments"
  FieldArity → "Wrong number of fields"
  TypeArguments name → "Wrong number of type arguments for " <> name
  TypeMismatch expected found → "Expected " <> typeName expected
    <> ", found "
    <> typeName found
  NotAFunction found → "Expected a function, found " <> typeName found
  InfiniteType meta whole → "Infinite type: " <> typeName meta
    <> " occurs in "
    <> typeName whole
  NotComparable ty → "Type " <> typeName ty <> " is not comparable"
  AmbiguousType ty → "Ambiguous type " <> typeName ty <> " in comparison"
  PolymorphicRecursion name → "Recursive call to " <> name
    <> " changes its type arguments"
  NestedDatatype name → "Recursive use of " <> name
    <> " changes its type arguments"
  SpecializationLimit limit → "More than " <> show limit <> " specializations"
  RedundantArm → "Redundant match arm"
  NonExhaustive witness → "Missing pattern: " <> pattern witness
  Internal text → text
  Hinted problem hint → message problem <> hintMessage hint
  EffectNotAllowed name label → name <> " performs " <> label
    <> ", which its signature does not allow"
  UnhandledEffect label → "Unhandled " <> label <> " in main"
  MustBePure label → "This function must be pure, but it performs " <> label
  RowSort true → "Expected an effect row, found a type"
  RowSort false → "Expected a type, found an effect row"
  NotPrintable ty → "Expected a printable value, found " <> typeName ty
  DeferMayFail label → "defer must not fail, but it performs " <> label
  RowEquality left right tail → left <> " and " <> right
    <> " cannot be made equal: both end in ..."
    <> tail
  HandlerMissing operation → "Missing clause for " <> operation
  HandlerDuplicate operation → "Duplicate clause for " <> operation
  HandlerOperation operation effect → operation
    <> " is not an operation of "
    <> effect
  FailNeedsConcrete → "Fail needs a concrete error family"
  ExpectedHandler _ → "Expected a handler"

wire ∷ Diagnostic → WireDiagnostic
wire diagnostic =
  { code: codeName (code diagnostic.problem)
  , message: message diagnostic.problem
  , span: diagnostic.span
  , related: diagnostic.related
  }

entryMessage ∷ EntryKind → String
entryMessage = case _ of
  MissingEntry → "Expected fn main()"
  EntryParameters → "main must have no parameters"
  EntryPolymorphic → "Expected fn main() with a concrete result type"
  EntryFunction → "Expected fn main() with a printable result type"

hintMessage ∷ Hint → String
hintMessage = case _ of
  MissingArguments name count → "; missing " <> counted count
    <> " to "
    <> name
    <> "?"
  TrailingSemicolon → "; remove the trailing ;?"
  where
  counted count
    | count == 1 = "1 argument"
    | otherwise = show count <> " arguments"

duplicateWord ∷ DuplicateKind → String
duplicateWord = case _ of
  DuplicateType → "type"
  DuplicateConstructor → "constructor"
  DuplicateFunction → "function"
  DuplicateParameter → "parameter"
  DuplicateBinder → "binder"
  DuplicateTypeParameter → "type parameter"
  DuplicateEffect → "effect"
  DuplicateOperation → "operation"

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
  UnitName → "Unit"
  DataName name → name
  AppliedName name arguments → name <> listed (map typeName arguments)
  VariableName name → name
  HoleName → "_"
  arrow@(FunctionName _ _) → arrowName arrow

-- Right-associative: `(Int -> Int) -> List(Int) -> List(Int)`, a parameter
-- that is itself an arrow parenthesized. The spine of results is followed
-- by a loop, so a name of thousands of parameters costs no stack.
arrowName ∷ TypeName → String
arrowName name = tailRec step { written: "", rest: name }
  where
  step pending = case pending.rest of
    FunctionName parameter result → Loop
      { written: pending.written <> parameterName parameter <> " -> "
      , rest: result
      }
    result → Done (pending.written <> typeName result)
  parameterName = case _ of
    parameter@(FunctionName _ _) → "(" <> arrowName parameter <> ")"
    parameter → typeName parameter

-- Witnesses print as Waxwing patterns: `_`, literals, `Name(field, …)`.
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
