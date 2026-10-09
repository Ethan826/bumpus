module Features.Check.Defer (checkDefer, rejectDeferred) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Foldable (traverse_)
import Data.Maybe (Maybe(..), isJust, maybe)
import Domain.Checked.Internal (Open(..))
import Domain.Checked.Internal as Checked
import Domain.Problem (Problem(..))
import Domain.Resolved as Resolved
import Domain.Row (EffectRef(..), Label(..), Row(..), openRow)
import Domain.Syntax (Diagnostic, Span, problemAt)
import Domain.Type (Ty(..), TyRow)
import Domain.Type.Parts (typeHead)
import Features.Check.Consume (consumeAt)
import Features.Check.Context (CheckEnv, Infer, Locals)
import Features.Check.Entry (resolvedRow)
import Features.Check.RowName (labelName)
import Features.Check.Require (require)
import Features.Check.Scheme (State, Threaded, flexible, opened, resolved)
import Features.Check.Unify (Subst(..), resolve)

type DeferEnv r = CheckEnv (locals ∷ Locals | r)

-- FX001 design §2: `defer e` has type Unit and must not fail. `e` is
-- checked against a row of its own, so what it performs is known apart
-- from what the enclosing function performs; a `Fail` there is E_EFFECT at
-- the item. Only then is that row consumed into the current one, which
-- makes the other effects of `e` the function's own. A `Fail` whose key
-- is not settled yet is not in that row: unification set its pair aside
-- (Features.Check.UnifyRow). Those pairs `e` added are noted, and
-- `rejectDeferred` judges them once the key is settled, so the message
-- names the payload.
checkDefer
  ∷ ∀ r
  . Infer (locals ∷ Locals | r)
  → DeferEnv r
  → State
  → Span
  → Resolved.Expr
  → Either Diagnostic (Threaded Checked.Expr)
checkDefer infer env state span value = do
  inferred ← infer (env { current = row }) (state { next = state.next + 1 })
    value
  typed ← require env inferred.state TUnit inferred.value
  maybe (Right unit) (refuse env span) (Array.find keyed (performed typed))
  consumed ← consumeAt env typed span row
  pure
    { value: inferred.value
    , state: consumed
        { deferrals = consumed.deferrals
            <> map (deferral span) (unsettled typed)
        }
    }
  where
  row = openRow (Hole state.next)
  performed found = failures (resolvedRow found.subst row)
  keyed = isJust <<< typeHead
  unsettled found = Array.filter (not <<< keyed) (performed found)
    <> postponedPayloads found.subst (postponedCount state.subst)
  deferral at payload = { span: at, payload }

-- The deferred `Fail`s, once their keys are settled (after
-- Features.Check.Failure.settleKeys): the first one fails the function.
rejectDeferred
  ∷ ∀ r
  . CheckEnv r
  → Subst
  → Array { span ∷ Span, payload ∷ Ty Open }
  → Either Diagnostic Unit
rejectDeferred env subst = traverse_ rejected
  where
  rejected found = refuse env found.span (resolved subst found.payload)

-- How many row pairs the substitution has set aside.
postponedCount ∷ Subst → Int
postponedCount (Subst bindings) = Array.length bindings.postponed

-- The payloads of the `Fail` labels with no settled key in the pairs set
-- aside after the first `before` of them.
postponedPayloads ∷ Subst → Int → Array (Ty Open)
postponedPayloads subst@(Subst bindings) before = Array.mapMaybe unsettled
  (Array.concatMap labelsOf (Array.drop before bindings.postponed))
  where
  labelsOf pair = rowLabels pair.left <> rowLabels pair.right
  rowLabels (Row labels _) = labels
  unsettled (Label FailEffect arguments) = Array.head arguments
    >>= unkeyed
  unsettled _ = Nothing
  unkeyed payload =
    if isJust (typeHead found) then Nothing
    else Just (opened found)
    where
    found = resolve subst payload

-- The payloads of the `Fail` labels of a row, in order.
failures ∷ TyRow Open → Array (Ty Open)
failures (Row labels _) = Array.concatMap payloads labels
  where
  payloads (Label FailEffect arguments) = Array.take 1 arguments
  payloads _ = []

refuse
  ∷ ∀ r a. CheckEnv r → Span → Ty Open → Either Diagnostic a
refuse env span payload = do
  name ← labelName env span (Label FailEffect [ flexible payload ])
  Left (problemAt (DeferMayFail name) span)
