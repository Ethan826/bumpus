module Features.Check.Unsettled (unsettled) where

import Prelude
import Data.Array as Array
import Data.Maybe (Maybe(..), maybe)
import Domain.Problem (Problem(FailNeedsConcrete))
import Domain.Syntax (Diagnostic, NoteReason(NoFamilyHere), Span)
import Features.Check.Context (CheckEnv)
import Features.Check.Occurrence (nowhere)
import Features.Check.Reject (rightSpan)
import Features.Check.Report (noteAt)
import Features.Check.Subst (RowPair)

-- A row pair still set aside once the function is settled: its Fail
-- payload is a meta nothing decided. A signature's `Fail(a)` is refused
-- where it is written (Features.Resolve.Row), so this guards the metas.
-- Reported at the expression that met the pair (its left span; `fallback`
-- when plain unification wrote none), with a note at the parameter row an
-- argument was unified against, when a call wrote one.
unsettled ∷ ∀ r. CheckEnv r → Span → RowPair → Diagnostic
unsettled env fallback pair =
  { problem: FailNeedsConcrete, span, related: annotation }
  where
  span = if pair.sides.left == nowhere then fallback else pair.sides.left
  annotation = maybe [] (Array.singleton <<< noted) (met env pair)
  noted at = noteAt at NoFamilyHere

-- The ambient row of a consumption is not an annotation.
met ∷ ∀ r. CheckEnv r → RowPair → Maybe Span
met env pair =
  if pair.sides.right == nowhere || pair.sides.right == rightSpan env then
    Nothing
  else Just pair.sides.right
