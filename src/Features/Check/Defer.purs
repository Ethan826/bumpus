module Features.Check.Defer (checkDefer, settleDeferred) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Foldable (foldM, traverse_)
import Data.Maybe (Maybe(..), maybe)
import Data.Tuple (Tuple(..), fst, snd)
import Domain.Checked.Internal (Open(..))
import Domain.Checked.Internal as Checked
import Domain.Problem (Problem(..))
import Domain.Resolved as Resolved
import Domain.Row (EffectRef(..), Label(..), Row(..), openRow)
import Domain.Syntax (Diagnostic, Span)
import Domain.Type (Ty(..), TyRow, VarId(..))
import Features.Check.Consume (consumeVia)
import Features.Check.Context (CheckEnv, Infer, Locals)
import Features.Check.DeferNotes (failureNotes, tailNotes)
import Features.Check.Entry (resolvedRow)
import Features.Check.Occurrence (OccurrenceId)
import Features.Check.Provenance
  ( Boundary(DeferItem)
  , Consumed(Application)
  , occurrencesOf
  )
import Features.Check.RowName (labelName)
import Features.Check.Require (require)
import Features.Check.Scheme (Deferral, State, Threaded, flexible, flexibleRow)
import Features.Check.Unify (Subst)

type DeferEnv r = CheckEnv (locals ∷ Locals | r)

-- FX001 design §2: `defer e` has type Unit and must not fail. `e` is
-- checked against a row of its own, whose tail is never unified with the
-- enclosing row: its labels are consumed into the enclosing row (with a
-- fresh tail), so the other effects of `e` are the function's own, but
-- what `e` performs stays known apart from the rest. A `Fail` already
-- there is E_EFFECT at the item. Anything that reaches the row later (a
-- shared meta, a deferred key) is judged by `settleDeferred`. Each label
-- consumed into the enclosing row is linked to the occurrence it has in
-- the deferred row, through the `defer` boundary (design §6).
checkDefer
  ∷ ∀ r
  . Infer (locals ∷ Locals | r)
  → DeferEnv r
  → State
  → Span
  → Resolved.Expr
  → Either Diagnostic (Threaded Checked.Expr)
checkDefer infer env state span value = do
  inferred ← infer (env { current = row, sites = [] })
    (state { next = state.next + 1 })
    value
  typed ← require env inferred.state TUnit inferred.value
  let Row labels _ = resolvedRow typed.subst row
  traverse_ (refuseFail env typed span inferred.value) (placed typed labels row)
  consumed ← consumeVia env typed (crossing span)
    (occurrencesOf typed.subst (flexibleRow row))
    (Row labels (Just (Hole typed.next)))
  pure
    { value: inferred.value
    , state: consumed
        { next = consumed.next + 1
        , deferrals = Array.snoc consumed.deferrals
            { span
            , row
            , current: env.current
            , sites: env.sites
            , body: inferred.value
            }
        }
    }
  where
  row = openRow (Hole state.next)

-- The labels of a deferred row with the occurrences they have in it.
placed
  ∷ State
  → Array (Label (Ty Open))
  → TyRow Open
  → Array (Tuple (Label (Ty Open)) OccurrenceId)
placed state labels row = Array.zip labels
  (occurrencesOf state.subst (flexibleRow row))

crossing
  ∷ Span
  → { span ∷ Span
    , consumed ∷ Consumed
    , via ∷ Maybe Boundary
    }
crossing span = { span, consumed: Application, via: Just DeferItem }

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
  judged found = judge env state found
  later reached found = bumped <$> consumeVia
    (env { current = found.current, sites = found.sites })
    reached
    (crossing found.span)
    (map snd kept)
    (Row (map fst kept) (Just (Hole reached.next)))
    where
    kept = Array.filter (not <<< failing <<< fst)
      (placed reached (rowLabels reached found) found.row)
  bumped reached = reached { next = reached.next + 1 }
  rowLabels reached found = case resolvedRow reached.subst found.row of
    Row labels _ → labels

judge ∷ ∀ r. DeferEnv r → State → Deferral → Either Diagnostic Unit
judge env state found = do
  traverse_ (refuseFail env state found.span found.body)
    (placed state labels found.row)
  maybe (Right unit) (rigidTail env state found) tail
  where
  Row labels tail = resolvedRow state.subst found.row

-- A hole is an unsolved tail, closed to empty; a rigid variable is the
-- ambient row or a named one, spelled as Row display spells it.
rigidTail
  ∷ ∀ r. DeferEnv r → State → Deferral → Open → Either Diagnostic Unit
rigidTail env state found = case _ of
  Hole _ → Right unit
  Rigid variable@(VarId index) → Left
    { problem: DeferMayPerform (spread index)
    , span: found.span
    , related: tailNotes env state found variable
    }
  where
  spread index = "..." <> maybe "" identity (Array.index env.variables index)

failing ∷ ∀ v. Label (Ty v) → Boolean
failing (Label effect _) = effect == FailEffect

refuseFail
  ∷ ∀ r
  . DeferEnv r
  → State
  → Span
  → Checked.Expr
  → Tuple (Label (Ty Open)) OccurrenceId
  → Either Diagnostic Unit
refuseFail env state span body (Tuple label@(Label _ arguments) occurrence) =
  if failing label then named else Right unit
  where
  named = do
    name ← labelName env span (Label FailEffect (map flexible payload))
    Left
      { problem: DeferMayFail name
      , span
      , related: failureNotes state span body name occurrence
      }
  payload = Array.take 1 arguments
