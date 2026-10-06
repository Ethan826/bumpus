module Sprig.Check.Match
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
import Sprig.IR.Internal as IR
import Sprig.Model (ErrorCode(..), Diagnostic, Span, problem)
import Sprig.Resolved
  ( CtorId(..)
  , CtorInfo
  , LocalId
  , Tables
  , Ty(..)
  , TypeInfo
  , describe
  )
import Sprig.Resolved as Resolved

type Typed = { id ∷ LocalId, ty ∷ Ty }

type Checked = { pattern ∷ IR.Pattern, locals ∷ Array Typed }

-- Open rows let Sprig.Check pass its own environment through unchanged.
type MatchEnv r =
  { types ∷ Array TypeInfo, ctors ∷ Array CtorInfo, locals ∷ Array Typed | r }

type Infer r = MatchEnv r → Resolved.Expr → Either Diagnostic IR.Expr

require
  ∷ ∀ r. { types ∷ Array TypeInfo | r } → Ty → IR.Expr → Either Diagnostic Unit
require env expected actual =
  expectType env.types expected (IR.typeOf actual) (IR.spanOf actual)

-- Each arm is checked as pattern, then body, then against the first arm.
checkMatch
  ∷ ∀ r
  . Infer r
  → MatchEnv r
  → Span
  → Resolved.Expr
  → Array Resolved.Arm
  → Either Diagnostic IR.Expr
checkMatch infer env span scrutinee arms = do
  head ← infer env scrutinee
  maybe' empty (checkArms head) (Array.uncons arms)
  where
  empty _ = Left (problem InternalError span "Empty resolved match")
  checkArms head split = do
    first ← checkArm infer env (IR.typeOf head) split.head
    rest ← traverse (laterArm head first) split.tail
    pure
      ( IR.Expr
          { ty: IR.typeOf first.body
          , span
          , node: IR.Match head (Array.cons first rest)
          }
      )
  laterArm head first arm = do
    checked ← checkArm infer env (IR.typeOf head) arm
    require env (IR.typeOf first.body) checked.body
    pure checked

-- Patterns are checked top-down against the scrutinee's type.
checkPattern
  ∷ Tables → Ty → Resolved.Pattern → Either Diagnostic Checked
checkPattern tables expected = case _ of
  Resolved.Wildcard span → leaf span IR.Wildcard []
  Resolved.Bind span id → leaf span (IR.Bind id) [ { id, ty: expected } ]
  Resolved.IntLit span value → literal TInt span (IR.IntLit value)
  Resolved.BoolLit span value → literal TBool span (IR.BoolLit value)
  Resolved.Ctor span id fields → checkCtor tables expected span id fields
  where
  leaf span shape locals = pure
    { pattern: IR.Pattern { ty: expected, span, shape }, locals }
  literal actual span shape = do
    expectType tables.types expected actual span
    leaf span shape []

checkArm
  ∷ ∀ r
  . Infer r
  → MatchEnv r
  → Ty
  → Resolved.Arm
  → Either Diagnostic IR.Arm
checkArm infer env ty arm = do
  matched ← checkPattern { types: env.types, ctors: env.ctors } ty arm.pattern
  body ← infer (env { locals = env.locals <> matched.locals }) arm.body
  pure { pattern: matched.pattern, body, span: arm.span }

-- Arity is intrinsic to the constructor, so it is checked before ownership.
checkCtor
  ∷ Tables
  → Ty
  → Span
  → CtorId
  → Array Resolved.Pattern
  → Either Diagnostic Checked
checkCtor tables expected span id@(CtorId index) fields = maybe' missing found
  (Array.index tables.ctors index)
  where
  missing _ = Left (problem InternalError span "Invalid resolved constructor")
  found ctor = do
    when (Array.length fields /= Array.length ctor.fields)
      (Left (problem ArityMismatch span "Wrong number of fields"))
    expectType tables.types expected (TData ctor.owner) span
    checked ← traverse checkField (Array.zipWith fieldPair ctor.fields fields)
    pure
      { pattern: IR.Pattern
          { ty: expected, span, shape: IR.Ctor id (map patternOf checked) }
      , locals: Array.concatMap localsOf checked
      }
  fieldPair ty pattern = { ty, pattern }
  checkField field = checkPattern tables field.ty field.pattern
  patternOf checked = checked.pattern
  localsOf checked = checked.locals

expectType ∷ Array TypeInfo → Ty → Ty → Span → Either Diagnostic Unit
expectType types expected actual span =
  if expected == actual then Right unit
  else Left
    ( problem TypeMismatch span
        ( "Expected " <> describe types expected <> ", found "
            <> describe types actual
        )
    )
