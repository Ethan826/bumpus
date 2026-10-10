module Features.Check.Path (Located, expandPath) where

import Prelude
import Control.Monad.Rec.Class (Step(..), tailRec)
import Data.Array as Array
import Data.Maybe (Maybe(..), maybe)
import Data.Set (Set)
import Data.Set as Set
import Data.Tuple (Tuple(..))
import Domain.Syntax (Note, NoteReason(..), Span)
import Features.Check.Occurrence (OccurrenceId(..), nowhere)
import Features.Check.Provenance (trail)
import Features.Check.Report (originNotesVia)
import Features.Check.Scheme (State)

-- A function checked again for its provenance: its name, its declaration
-- and the state its check ended in.
type Located = { name ∷ String, span ∷ Span, state ∷ State }

-- A rejection's notes end, for a label that came from a call, at a
-- `ContinuesInto` marker. The callee's own check knows where the label
-- arose in its body: this replaces the marker with the callee's notes,
-- each call it made on the way read as the path through the callee, and
-- goes on into the next callee, to the operation, the `fail` or the
-- function value. The function that checked `callee` is `locate`. A loop
-- over the calls, ending at a function met twice (links do not promise an
-- acyclic path).
expandPath
  ∷ (String → Maybe Located) → Array Note → Array Note
expandPath locate = Array.concatMap expanded
  where
  expanded note = case note.reason of
    ContinuesInto callee index label → followed locate
      { callee, index, label }
    _ → [ note ]

type Next = { callee ∷ String, index ∷ Int, label ∷ String }

type Walking =
  { next ∷ Maybe Next
  , seen ∷ Set (Tuple String Int)
  , notes ∷ Array Note
  }

followed ∷ (String → Maybe Located) → Next → Array Note
followed locate first = tailRec step
  { next: Just first, seen: Set.empty, notes: [] }
  where
  step ∷ Walking → Step Walking (Array Note)
  step pending = maybe (Done pending.notes) (visit pending) pending.next
  visit pending next
    | Set.member (Tuple next.callee next.index) pending.seen = Done
        pending.notes
    | otherwise = maybe (Done pending.notes) (enter pending next)
        (locate next.callee)
  enter pending next located =
    Loop
      { next: marker (Array.last made)
      , seen: Set.insert (Tuple next.callee next.index) pending.seen
      , notes: pending.notes <> Array.dropEnd (continuing made) made
      }
    where
    made = originNotesVia (const (ThroughFunction next.callee)) nowhere
      next.label
      ( trail located.state.subst located.state.origins
          (Written located.span next.index)
      )
  marker found = continuation =<< found
  continuation note = case note.reason of
    ContinuesInto callee index label → Just { callee, index, label }
    _ → Nothing
  continuing made = maybe 0 (const 1) (marker (Array.last made))
