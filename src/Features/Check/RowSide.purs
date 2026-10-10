module Features.Check.RowSide
  ( Tail(..)
  , Entry
  , Side
  , tailOf
  , written
  , expanded
  , mismatched
  ) where

import Prelude
import Prim hiding (Row)
import Control.Monad.Rec.Class (Step(..), tailRec)
import Data.Array as Array
import Data.Maybe (Maybe, maybe)
import Data.Tuple (Tuple(..))
import Domain.Row (EffectRef(..), Label(..), Row(..))
import Domain.Syntax (Span)
import Domain.Type (Ty, TyRow, VarId)
import Features.Check.Occurrence (OccurrenceId, Sides, nowhere)
import Features.Check.Occurrence as Occurrence
import Features.Check.Subst
  ( Failure(..)
  , Flex(..)
  , Subst
  , boundRow
  , metaOf
  , resolveLabel
  )

-- An operand's tail, so its cases are plain constructors.
data Tail = Closed | RigidTail VarId | MetaTail Int

derive instance eqTail ∷ Eq Tail

type Entry = { label ∷ Label (Ty Flex), occurrence ∷ OccurrenceId }

-- One operand of row unification (Features.Check.UnifyRow) as its walk
-- sees it: entries (the left's from `next` on
-- still to match) and a tail, kept unbound by `expanded`.
type Side = { entries ∷ Array Entry, next ∷ Int, tail ∷ Maybe Flex }

-- An operand's own labels, each the occurrence at its position in the
-- row written at `span`.
written ∷ Span → TyRow Flex → Side
written span (Row labels tail) =
  { entries: Array.mapWithIndex at labels, next: 0, tail }
  where
  at index label = { label, occurrence: Occurrence.Written span index }

-- A side with its tail's bindings spliced in, until the tail is unbound.
expanded ∷ Subst → Side → Side
expanded subst = tailRec splice
  where
  splice side = maybe (Done side) (Loop <<< spliced side) (bound side.tail)
  bound tail = Tuple <$> (metaOf =<< tail) <*> boundRow subst tail
  spliced side (Tuple meta (Row labels tail)) = side
    { entries = side.entries <> map (reached meta) labels, tail = tail }
  reached meta label = { label, occurrence: Occurrence.Extended meta }

tailOf ∷ Maybe Flex → Tail
tailOf = maybe Closed fromFlex
  where
  fromFlex = case _ of
    Rigid id → RigidTail id
    Meta meta → MetaTail meta

-- A failure inside the arguments of two same-key labels, reported (for a
-- unification whose rows were written somewhere, a consumption's) as the
-- two labels with the right entry's occurrence, so the message can name
-- `State(Bool)` against `State(Int)`. `Fail` keeps its argument mismatch:
-- its payloads are judged by their own family rules.
mismatched ∷ Sides → Subst → Entry → Entry → Failure → Failure
mismatched sides subst entry other failure = case failure, entry.label of
  Mismatch _ _, Label FailEffect _ → failure
  Mismatch _ _, _ | sides.left /= nowhere → RowPayload
    (resolveLabel subst entry.label)
    (resolveLabel subst other.label)
    other.occurrence
  _, _ → failure
