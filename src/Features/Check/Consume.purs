module Features.Check.Consume (consume, consumeAt, failureAt) where

import Prelude
import Data.Either (Either(..), either)
import Data.Maybe (Maybe(..), maybe')
import Domain.Checked.Internal (Open)
import Domain.Row (Row(..), openRow)
import Domain.Problem (Problem(..))
import Domain.Syntax (Diagnostic, Span, problemAt)
import Domain.Type (Ty(..), TyRow)
import Features.Check.Context (CheckEnv)
import Features.Check.RowName (labelName, rowConflict)
import Features.Check.Scheme (State, flexible, opened)
import Features.Check.TypeName (typeName)
import Features.Check.Unify (Failure(..), Flex(..), Subst(..), resolve, unify)
import Features.Check.UnifyRow (unifyRows)

-- Closed rows open only for consumption; the function value stays closed.
consume ∷ Subst → TyRow Flex → TyRow Flex → Either Failure Subst
consume subst stage@(Row labels tail) current = maybe' closed opened tail
  where
  Subst bindings = subst
  fresh = Subst bindings { fresh = bindings.fresh - 1 }
  closed _ = unifyRows unify fresh
    (Row labels (Just (Meta bindings.fresh)))
    current
  opened _ = unifyRows unify subst stage current

consumeAt
  ∷ ∀ r. CheckEnv r → State → Span → TyRow Open → Either Diagnostic State
consumeAt env state span row = either failed finished
  (consume state.subst (converted row) (converted env.current))
  where
  converted found =
    case
      resolve state.subst
        (flexible (TFun TUnit found TUnit))
      of
      TFun _ result _ → result
      _ → openRow (Meta 0)
  finished subst = Right (state { subst = subst })
  failed failure = failureAt env span failure

failureAt
  ∷ ∀ r a. CheckEnv r → Span → Failure → Either Diagnostic a
failureAt env span = case _ of
  Mismatch found expected → mismatch expected found
  RowMissing label _ → rejected label
  RowExtra label → rejected label
  RowSharedTail left right → rowConflict env span left right
  RowMismatch left right → rowConflict env span left right
  _ → Left (problemAt (Internal "Effect row consumption failed") span)
  where
  mismatch expected found = do
    expectedName ← typeName env span (opened expected)
    foundName ← typeName env span (opened found)
    Left (problemAt (TypeMismatch expectedName foundName) span)
  rejected label = do
    name ← labelName env span label
    Left (problemAt (EffectNotAllowed env.functionName name) span)
