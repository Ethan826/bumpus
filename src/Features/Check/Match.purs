module Features.Check.Match
  ( Typed
  , checkMatch
  , checkPattern
  , require
  ) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (maybe')
import Data.Traversable (traverse)
import Domain.Checked.Internal (Open, rigid)
import Domain.Checked.Internal as Checked
import Domain.Problem (Problem(..), TypeName(..))
import Domain.Syntax (Diagnostic, Span, problemAt)
import Domain.Resolved
  ( CtorId(..)
  , CtorInfo
  , LocalId
  , Tables
  , Ty(..)
  , TypeId(..)
  , TypeInfo
  )
import Domain.Resolved as Resolved

type Typed = { id ∷ LocalId, ty ∷ Ty Open }

type Matched = { pattern ∷ Checked.Pattern, locals ∷ Array Typed }

-- Open rows let Features.Check pass its own environment through unchanged.
type MatchEnv r =
  { types ∷ Array TypeInfo, ctors ∷ Array CtorInfo, locals ∷ Array Typed | r }

type Infer r = MatchEnv r → Resolved.Expr → Either Diagnostic Checked.Expr

require
  ∷ ∀ r
  . { types ∷ Array TypeInfo | r }
  → Ty Open
  → Checked.Expr
  → Either Diagnostic Unit
require env expected actual = expectType env.types expected
  (Checked.typeOf actual)
  (Checked.spanOf actual)

-- Each arm is checked as pattern, then body, then against the first arm.
checkMatch
  ∷ ∀ r
  . Infer r
  → MatchEnv r
  → Span
  → Resolved.Expr
  → Array Resolved.Arm
  → Either Diagnostic Checked.Expr
checkMatch infer env span scrutinee arms = do
  head ← infer env scrutinee
  maybe' empty (checkArms head) (Array.uncons arms)
  where
  empty _ = Left (problemAt (Internal "Empty resolved match") span)
  checkArms head split = do
    first ← checkArm infer env (Checked.typeOf head) split.head
    rest ← traverse (laterArm head first) split.tail
    pure
      ( Checked.Expr
          { ty: Checked.typeOf first.body
          , span
          , node: Checked.Match head (Array.cons first rest)
          }
      )
  laterArm head first arm = do
    checked ← checkArm infer env (Checked.typeOf head) arm
    require env (Checked.typeOf first.body) checked.body
    pure checked

-- Patterns are checked top-down against the scrutinee's type.
checkPattern
  ∷ Tables → Ty Open → Resolved.Pattern → Either Diagnostic Matched
checkPattern tables expected = case _ of
  Resolved.Wildcard span → leaf span Checked.Wildcard []
  Resolved.Bind span id → leaf span (Checked.Bind id) [ { id, ty: expected } ]
  Resolved.IntLit span value → literal TInt span (Checked.IntLit value)
  Resolved.BoolLit span value → literal TBool span (Checked.BoolLit value)
  Resolved.Ctor span id fields → checkCtor tables expected span id fields
  where
  leaf span shape locals = pure
    { pattern: Checked.Pattern { ty: expected, span, shape }, locals }
  literal actual span shape = do
    expectType tables.types expected actual span
    leaf span shape []

checkArm
  ∷ ∀ r
  . Infer r
  → MatchEnv r
  → Ty Open
  → Resolved.Arm
  → Either Diagnostic Checked.Arm
checkArm infer env ty arm = do
  matched ← checkPattern { types: env.types, ctors: env.ctors } ty arm.pattern
  body ← infer (env { locals = env.locals <> matched.locals }) arm.body
  pure { pattern: matched.pattern, body, span: arm.span }

-- Resolution has already checked the constructor's arity, so a field count
-- that disagrees with the table is a compiler bug, not a truncation.
checkCtor
  ∷ Tables
  → Ty Open
  → Span
  → CtorId
  → Array Resolved.Pattern
  → Either Diagnostic Matched
checkCtor tables expected span id@(CtorId index) fields = maybe' missing found
  (Array.index tables.ctors index)
  where
  missing _ = Left
    (problemAt (Internal "Invalid resolved constructor") span)
  found ctor = do
    expectType tables.types expected (TData ctor.owner []) span
    when (Array.length ctor.fields /= Array.length fields) (Left arityBug)
    checked ← traverse checkField
      (Array.zipWith fieldPair (map rigid ctor.fields) fields)
    pure
      { pattern: Checked.Pattern
          { ty: expected, span, shape: Checked.Ctor id (map patternOf checked) }
      , locals: Array.concatMap localsOf checked
      }
  arityBug = problemAt (Internal "Resolved constructor arity mismatch") span
  fieldPair ty pattern = { ty, pattern }
  checkField field = checkPattern tables field.ty field.pattern
  patternOf checked = checked.pattern
  localsOf checked = checked.locals

expectType
  ∷ Array TypeInfo → Ty Open → Ty Open → Span → Either Diagnostic Unit
expectType types expected actual span =
  if expected == actual then Right unit
  else mismatch
  where
  mismatch = do
    wanted ← typeName types span expected
    found ← typeName types span actual
    Left (problemAt (TypeMismatch wanted found) span)

-- Names appear only in diagnostics, never in generated Go.
-- No variable or type argument exists before P001 Task 2, so one here is a
-- compiler bug until variables get names of their own.
typeName ∷ Array TypeInfo → Span → Ty Open → Either Diagnostic TypeName
typeName types span = case _ of
  TInt → Right IntName
  TBool → Right BoolName
  TData (TypeId index) _ → maybe' missing named (Array.index types index)
  TVar _ → Left (problemAt (Internal "Unnamed type variable") span)
  where
  missing _ = Left (problemAt (Internal "Invalid resolved type") span)
  named info = Right (DataName info.name)
