module Features.Check.UnifyRow
  ( Unifier
  , Sides
  , Traced
  , RowEvent(..)
  , unifyRows
  , unifyRowsTraced
  ) where

import Prelude
import Prim hiding (Row)
import Control.Monad.Rec.Class (Step(..), tailRec)
import Data.Array as Array
import Data.Either (Either(..), either)
import Data.Foldable (foldM)
import Data.Maybe (Maybe(..), maybe')
import Data.Tuple (Tuple(..))
import Domain.Row (Label(..), Row(..), isPure, labelKey, openRow)
import Domain.Syntax (Span)
import Domain.Type (Ty, TyRow)
import Domain.Type.Parts (typeHead)
import Features.Check.Binding (bindTail, extendRow)
import Features.Check.Occurrence (OccurrenceId)
import Features.Check.RowSide
  ( Entry
  , Side
  , Tail(..)
  , expanded
  , tailOf
  , written
  )
import Features.Check.Search (Stack(..), stackItems)
import Features.Check.Subst
  ( Failure(..)
  , Flex(..)
  , Subst
  , resolveLabel
  , resolveRow
  , walk
  )

-- The type unifier, passed in: Features.Check.Unify calls this module.
type Unifier = Subst → Ty Flex → Ty Flex → Either Failure Subst

-- Where each operand's own labels were written.
type Sides = { left ∷ Span, right ∷ Span }

type Traced = { subst ∷ Subst, events ∷ Array RowEvent }

-- What unification did with each label (for provenance, design §6): a
-- left label matched an existing right entry (the right occurrence says
-- through which written row or meta binding it was reached), or a meta
-- tail was extended with a label, which is then occurrence `Extended m`.
data RowEvent = Matched OccurrenceId OccurrenceId | Extended Int OccurrenceId

type Pending =
  { subst ∷ Subst, left ∷ Side, right ∷ Side, events ∷ Stack RowEvent }

-- The operands as given, which failures name, resolved.
type Operands = { left ∷ TyRow Flex, right ∷ TyRow Flex }

-- Leijen's scoped-label unification (2005, §7; design §2). Each left
-- label, in order, matches the first right entry with its key, whose
-- arguments then unify; with none, the right's meta tail is extended with
-- it, unless that would bind the left's own tail (`tail(r1) ∉ dom(θ)`),
-- which would rewrite forever (`Clock + ...r` against `Log + ...r`).
-- Left over right entries extend the left's meta tail, one at a time.
-- A loop over labels: no recursion per label.
-- Two pure rows (every row before row syntax) skip the loop.
unifyRows ∷ Unifier → Subst → TyRow Flex → TyRow Flex → Either Failure Subst
unifyRows unify subst left right =
  if isPure left && isPure right then Right subst
  else solved <$> unifyRowsTraced unify untraced subst left right
  where
  solved traced = traced.subst

-- The same, with each label's fate reported by occurrence.
unifyRowsTraced
  ∷ Unifier
  → Sides
  → Subst
  → TyRow Flex
  → TyRow Flex
  → Either Failure Traced
unifyRowsTraced unify sides subst left right = tailRec
  (step unify { left, right })
  { subst
  , left: written sides.left left
  , right: written sides.right right
  , events: Bottom
  }

-- Spans for the untraced form, whose events are dropped unread.
untraced ∷ Sides
untraced = { left: nowhere, right: nowhere }
  where
  nowhere = { start: origin, end: origin }
  origin = { offset: 0, line: 0, column: 0 }

step
  ∷ Unifier
  → Operands
  → Pending
  → Step Pending (Either Failure Traced)
step unify operands pending =
  maybe' (finish operands current) (consume unify operands current)
    (Array.index current.left.entries current.left.next)
  where
  current = pending
    { left = expanded pending.subst pending.left
    , right = expanded pending.subst pending.right
    }

consume
  ∷ Unifier
  → Operands
  → Pending
  → Entry
  → Step Pending (Either Failure Traced)
consume unify operands pending entry =
  maybe' (absent operands pending entry) (present unify pending entry)
    (keyed =<< labelKey (typeHead <<< walk pending.subst) entry.label)
  where
  entries = pending.right.entries
  keyed key = located =<< Array.findIndex (sameKey key) entries
  sameKey key other = labelKey (typeHead <<< walk pending.subst) other.label
    == Just key
  located index = withIndex index <$> Array.index entries index
  withIndex index other = { index, other }

present
  ∷ Unifier
  → Pending
  → Entry
  → { index ∷ Int, other ∷ Entry }
  → Step Pending (Either Failure Traced)
present unify pending entry found =
  either (Done <<< Left) (Loop <<< matched)
    (foldM unifyPair pending.subst (Array.zip arguments others))
  where
  Label _ arguments = entry.label
  Label _ others = found.other.label
  unifyPair subst (Tuple one other) = unify subst one other
  entries = pending.right.entries
  matched subst = pending
    { subst = subst
    , left = pending.left { next = pending.left.next + 1 }
    , right = pending.right
        { entries = Array.take found.index entries
            <> Array.drop (found.index + 1) entries
        }
    , events = Push (Matched entry.occurrence found.other.occurrence)
        pending.events
    }

-- No right entry has the label's key: extend the right's meta tail.
absent
  ∷ Operands → Pending → Entry → Unit → Step Pending (Either Failure Traced)
absent operands pending entry _ = case tailOf pending.right.tail of
  MetaTail meta
    | tailOf pending.left.tail == MetaTail meta → Done
        (Left (shared operands pending.subst))
    | otherwise → either (Done <<< Left) (Loop <<< extended meta)
        (extendRow pending.subst meta entry.label)
  _ → Done
    ( Left
        ( RowMissing (resolveLabel pending.subst entry.label)
            (resolveRow pending.subst operands.right)
        )
    )
  where
  extended meta made = pending
    { subst = made.subst
    , left = pending.left { next = pending.left.next + 1 }
    , right = pending.right { tail = Just (Meta made.fresh) }
    , events = Push (Extended meta entry.occurrence) pending.events
    }

-- Every left label is matched: what is left on the right extends the
-- left's meta tail, one entry per step; then the tails unify.
finish
  ∷ Operands → Pending → Unit → Step Pending (Either Failure Traced)
finish operands pending _ =
  maybe' closing extra (Array.head pending.right.entries)
  where
  closing _ = Done (traced <$> unifyTails operands pending)
  traced subst = { subst, events: stackItems pending.events }
  extra first = case tailOf pending.left.tail of
    MetaTail meta
      | tailOf pending.right.tail == MetaTail meta → Done
          (Left (shared operands pending.subst))
      | otherwise → either (Done <<< Left) (Loop <<< swapped meta first)
          (extendRow pending.subst meta first.label)
    _ → Done (Left (RowExtra (resolveLabel pending.subst first.label)))
  swapped meta first made = pending
    { subst = made.subst
    , left = { entries: [], next: 0, tail: Just (Meta made.fresh) }
    , right = pending.right { entries = Array.drop 1 pending.right.entries }
    , events = Push (Extended meta first.occurrence) pending.events
    }

-- Two unbound tails with no entries left. Of two metas the larger is
-- bound to the smaller, as Features.Check.Unify binds type metas.
unifyTails ∷ Operands → Pending → Either Failure Subst
unifyTails operands pending =
  case tailOf pending.left.tail, tailOf pending.right.tail of
    one, other | one == other → Right subst
    MetaTail one, MetaTail other | one < other → Right
      (bindTail subst other (openRow (Meta one)))
    MetaTail meta, _ → Right (bindTail subst meta (Row [] pending.right.tail))
    _, MetaTail meta → Right (bindTail subst meta (Row [] pending.left.tail))
    _, _ → Left
      ( RowMismatch (resolveRow subst operands.left)
          (resolveRow subst operands.right)
      )
  where
  subst = pending.subst

shared ∷ Operands → Subst → Failure
shared operands subst = RowSharedTail (resolveRow subst operands.left)
  (resolveRow subst operands.right)
