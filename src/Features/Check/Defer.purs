module Features.Check.Defer (checkDefer, settleDeferred) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Foldable (foldM, traverse_)
import Data.Maybe (Maybe(..), maybe)
import Domain.Checked.Internal (Open(..))
import Domain.Checked.Internal as Checked
import Domain.Problem (Problem(..))
import Domain.Resolved as Resolved
import Domain.Row (EffectRef(..), Label(..), Row(..), openRow)
import Domain.Syntax (Diagnostic, Span, problemAt)
import Domain.Type (Ty(..), TyRow, VarId(..))
import Features.Check.Consume (consumeAt)
import Features.Check.Context (CheckEnv, Infer, Locals)
import Features.Check.Entry (resolvedRow)
import Features.Check.RowName (labelName)
import Features.Check.Require (require)
import Features.Check.Scheme (State, Threaded, flexible)
import Features.Check.Unify (Subst)

type DeferEnv r = CheckEnv (locals ∷ Locals | r)

-- FX001 design §2: `defer e` has type Unit and must not fail. `e` is
-- checked against a row of its own, whose tail is never unified with the
-- enclosing row: its labels are consumed into the enclosing row (with a
-- fresh tail), so the other effects of `e` are the function's own, but
-- what `e` performs stays known apart from the rest. A `Fail` already
-- there is E_EFFECT at the item. Anything that reaches the row later (a
-- shared meta, a deferred key) is judged by `settleDeferred`.
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
  let Row labels _ = resolvedRow typed.subst row
  traverse_ (refuseFail env span) labels
  consumed ← consumeAt env typed span (Row labels (Just (Hole typed.next)))
  pure
    { value: inferred.value
    , state: consumed
        { next = consumed.next + 1
        , deferrals = Array.snoc consumed.deferrals
            { span, row, current: env.current }
        }
    }
  where
  row = openRow (Hole state.next)

-- After the function's keys are settled: each deferred row, resolved, may
-- hold no `Fail` and must not end in a rigid row variable, which a caller
-- may fill with one; an unsolved tail closes to empty. What reached a row
-- after its `defer` is consumed into the enclosing row now. The result is
-- the substitution to settle once more.
settleDeferred
  ∷ ∀ r. DeferEnv r → State → Either Diagnostic Subst
settleDeferred env state = do
  traverse_ judged state.deferrals
  finished ← foldM later state state.deferrals
  pure finished.subst
  where
  judged found = judge env found.span (resolvedRow state.subst found.row)
  later reached found = bumped <$> consumeAt (env { current = found.current })
    reached
    found.span
    (laterRow reached found)
  bumped reached = reached { next = reached.next + 1 }
  laterRow reached found = Row
    (Array.filter (not <<< failing) (rowLabels reached found))
    (Just (Hole reached.next))
  rowLabels reached found = case resolvedRow reached.subst found.row of
    Row labels _ → labels

judge ∷ ∀ r. DeferEnv r → Span → TyRow Open → Either Diagnostic Unit
judge env span (Row labels tail) = do
  traverse_ (refuseFail env span) labels
  maybe (Right unit) (rigidTail env span) tail

-- A hole is an unsolved tail, closed to empty; a rigid variable is the
-- ambient row or a named one, spelled as Row display spells it.
rigidTail ∷ ∀ r. DeferEnv r → Span → Open → Either Diagnostic Unit
rigidTail env span = case _ of
  Hole _ → Right unit
  Rigid (VarId index) → Left (problemAt (DeferMayPerform (spread index)) span)
  where
  spread index = "..." <> maybe "" identity (Array.index env.variables index)

failing ∷ ∀ v. Label (Ty v) → Boolean
failing (Label effect _) = effect == FailEffect

refuseFail
  ∷ ∀ r. DeferEnv r → Span → Label (Ty Open) → Either Diagnostic Unit
refuseFail env span label@(Label _ arguments) =
  if failing label then named else Right unit
  where
  named = labelName env span (Label FailEffect (map flexible payload))
    >>= (Left <<< flip problemAt span <<< DeferMayFail)
  payload = Array.take 1 arguments
