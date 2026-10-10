module Features.Check.Consume (consumeAt, consumeVia) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..), either)
import Data.Foldable (foldl)
import Data.Maybe (Maybe(..))
import Domain.Checked.Internal (Open)
import Domain.Row (Row(..))
import Domain.Syntax (Diagnostic, Span)
import Domain.Type (TyRow)
import Features.Check.Context (CheckEnv)
import Features.Check.Occurrence (OccurrenceId(Written), Sides)
import Features.Check.Origin (RowEvent(..), attributed, linked)
import Features.Check.Provenance (Consumed, Origin, remember)
import Features.Check.Reject (rejected, rightSpan, siteOccurrence)
import Features.Check.Scheme (State, flexibleRow)
import Features.Check.Subst (linkTo)
import Features.Check.Unify (Failure, Flex(..), Subst(..), resolveRow, unify)
import Features.Check.UnifyRow (Traced, unifyRowsTraced)

-- A row consumed into the current one at `span`, recording what was
-- consumed there as the origin of each label occurrence it adds or
-- reaches (design §6).
consumeAt
  ∷ ∀ r
  . CheckEnv r
  → State
  → Span
  → Consumed
  → TyRow Open
  → Either Diagnostic State
consumeAt env state span consumed =
  consumeVia env state { span, consumed, via: Nothing } []

-- The same through a boundary, or with each stage label known to be an
-- occurrence already (`sources`, by position: a deferred expression's
-- labels, consumed into the enclosing row, are linked to where `e`
-- performed them before the consumption's own links, which come second).
consumeVia
  ∷ ∀ r
  . CheckEnv r
  → State
  → Origin
  → Array OccurrenceId
  → TyRow Open
  → Either Diagnostic State
consumeVia env state origin sources row = either failed finished
  (consume start sides (flexibleRow row) (flexibleRow env.current))
  where
  sides = { left: origin.span, right: rightSpan env }
  start = foldl linkSource state.subst (Array.mapWithIndex numbered sources)
  numbered index source = { index, source }
  linkSource subst found =
    linkTo (Written origin.span found.index) found.source subst
  failed = rejected env state origin
  finished traced = Right
    ( state
        { subst = linked (named traced.events) traced.subst
        , origins = recorded traced
        }
    )
  named = map site
  site = case _ of
    Matched consumed existing → Matched consumed (siteOccurrence env existing)
    Extended meta source → Extended meta (siteOccurrence env source)
  recorded traced =
    if traced.postponed then foldl keep state.origins (stageOccurrences row)
    else attributed origin (named traced.events) state.origins
  keep origins occurrence = remember occurrence origin origins
  stageOccurrences (Row labels _) = Array.mapWithIndex placed labels
  placed index _ = Written origin.span index

-- Closed rows open only for consumption; the function value stays closed.
-- Whether the stage is closed is decided on the row resolved, but an open
-- one is consumed as it stands, so its labels keep the occurrences their
-- meta bindings gave them.
consume
  ∷ Subst → Sides → TyRow Flex → TyRow Flex → Either Failure Traced
consume subst sides stage current = case resolveRow subst stage of
  Row labels Nothing → unifyRowsTraced unify sides fresh
    (Row labels (Just (Meta bindings.fresh)))
    current
  _ → unifyRowsTraced unify sides subst stage current
  where
  Subst bindings = subst
  fresh = Subst bindings { fresh = bindings.fresh - 1 }
