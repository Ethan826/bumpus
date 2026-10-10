module Features.Check.Provenance
  ( Consumed(..)
  , Boundary(..)
  , Origin
  , Origins
  , Hop
  , noOrigins
  , remember
  , trail
  , occurrencesOf
  , occurrencesAt
  ) where

import Prelude
import Control.Monad.Rec.Class (Step(..), tailRec)
import Data.Array as Array
import Data.Map (Map)
import Data.Map as Map
import Data.Maybe (Maybe(..), maybe')
import Data.Set (Set)
import Data.Set as Set
import Domain.Syntax (Span)
import Domain.Type (TyRow)
import Features.Check.Occurrence (OccurrenceId, nowhere)
import Features.Check.RowSide (expanded, written)
import Features.Check.Subst (Flex, Subst, linkOf)

-- What a label was consumed from (design §6): an operation, a call of a
-- named function, an application of a function value, or a `fail`. The
-- strings name the operation, function or payload family.
data Consumed
  = Operation String
  | CallOf String
  | Application
  | FailOf String

-- The boundary a label crossed on its way to the rejection.
data Boundary
  = Signature String
  | AmbientSignature String
  | PureParameter
  | Installation String
  | Main
  | DeferItem

-- Where a label entered a row by consumption: the consuming expression's
-- span, what it consumed, and the boundary it crossed, if any.
type Origin = { span ∷ Span, consumed ∷ Consumed, via ∷ Maybe Boundary }

-- The first origin per occurrence, in the checker state. Neither this nor
-- the substitution's links is read by unification.
type Origins = Map OccurrenceId Origin

-- One step of a report's walk: an occurrence and its own origin, if any.
type Hop = { occurrence ∷ OccurrenceId, origin ∷ Maybe Origin }

noOrigins ∷ Origins
noOrigins = Map.empty

-- The first origin per occurrence wins.
remember ∷ OccurrenceId → Origin → Origins → Origins
remember occurrence origin = Map.insertWith keepFirst occurrence origin
  where
  keepFirst first _ = first

-- The occurrence and those its links lead to, by a loop, each with its own
-- origin. The report decides what to print; a cycle (links are not
-- acyclic by construction) ends the walk at the first repeat.
trail ∷ Subst → Origins → OccurrenceId → Array Hop
trail subst origins start = tailRec step
  { next: Just start, seen: Set.empty, hops: [] }
  where
  step ∷ Pending → Step Pending (Array Hop)
  step pending = maybe' (ended pending) (visit pending) pending.next
  ended pending _ = Done pending.hops
  visit pending occurrence =
    if Set.member occurrence pending.seen then Done pending.hops
    else Loop
      { next: linkOf subst occurrence
      , seen: Set.insert occurrence pending.seen
      , hops: Array.snoc pending.hops (hopAt occurrence)
      }
  hopAt occurrence =
    { occurrence, origin: Map.lookup occurrence origins }

type Pending =
  { next ∷ Maybe OccurrenceId, seen ∷ Set OccurrenceId, hops ∷ Array Hop }

-- The occurrences of a row's labels, in order, under the substitution: the
-- row's own labels are written nowhere in particular, those its bound
-- tails added are the metas' extensions.
occurrencesOf ∷ Subst → TyRow Flex → Array OccurrenceId
occurrencesOf = occurrencesAt nowhere

-- The same for a row written at `span`, a signature's.
occurrencesAt ∷ Span → Subst → TyRow Flex → Array OccurrenceId
occurrencesAt span subst row = map occurrenceOf
  (expanded subst (written span row)).entries
  where
  occurrenceOf entry = entry.occurrence
