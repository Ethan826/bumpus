module Features.Check.Consume (consume, consumeAt) where

import Prelude
import Data.Either (Either(..), either)
import Data.Maybe (Maybe(..), maybe')
import Domain.Checked.Internal (Open)
import Domain.Problem (Problem(..))
import Domain.Row (Row(..), openRow)
import Domain.Syntax (Diagnostic, Span, problemAt)
import Domain.Type (Ty(..), TyRow)
import Features.Check.Context (CheckEnv)
import Features.Check.RowName (labelName, rowConflict)
import Features.Check.Scheme (State, flexible)
import Features.Check.Unify (Failure(..), Flex(..), Subst(..), unify)
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
  converted found = case flexible (TFun TUnit found TUnit) of
    TFun _ result _ → result
    _ → openRow (Meta 0)
  finished subst = Right (state { subst = subst })
  failed = case _ of
    RowMissing label _ → rejected label
    RowExtra label → rejected label
    RowSharedTail left right → rowConflict env span left right
    _ → Left (problemAt (Internal "Effect row consumption failed") span)
  rejected label = do
    name ← labelName env span label
    Left (problemAt (EffectNotAllowed env.functionName name) span)
