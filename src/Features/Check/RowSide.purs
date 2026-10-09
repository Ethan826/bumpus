module Features.Check.RowSide
  ( Tail(..)
  , Entry
  , Side
  , tailOf
  , written
  , expanded
  ) where

import Prelude
import Prim hiding (Row)
import Control.Monad.Rec.Class (Step(..), tailRec)
import Data.Array as Array
import Data.Maybe (Maybe, maybe)
import Data.Tuple (Tuple(..))
import Domain.Row (Label, Row(..))
import Domain.Syntax (Span)
import Domain.Type (Ty, TyRow, VarId)
import Features.Check.Occurrence (OccurrenceId)
import Features.Check.Occurrence as Occurrence
import Features.Check.Subst (Flex(..), Subst, boundRow, metaOf)

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
