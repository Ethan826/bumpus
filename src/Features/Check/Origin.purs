module Features.Check.Origin
  ( RowEvent(..)
  , linked
  , attributed
  ) where

import Prelude
import Data.Foldable (foldl)
import Features.Check.Occurrence (OccurrenceId, anonymous)
import Features.Check.Occurrence as Occurrence
import Features.Check.Provenance (Origin, Origins, remember)
import Features.Check.Subst (Subst, linkTo)

-- What unification did with each label (design §6): a left label matched
-- an existing right entry (the right occurrence says through which
-- written row or meta binding it was reached), or a meta tail was
-- extended with a label, which is then occurrence `Extended m`, the same
-- label as the one it was copied from.
data RowEvent = Matched OccurrenceId OccurrenceId | Extended Int OccurrenceId

-- Row unification calls this on every event, so rows nested in arrow
-- types and retried postponed pairs are linked too (ruling F13). A
-- consumed label is linked to the entry it matched, a new occurrence to
-- its source, so a report follows a label to where it first arose. A
-- matched entry also names the first label that matched it, which says
-- which of a callee's labels an origin consumed. Occurrences nobody wrote
-- anywhere are never linked.
linked ∷ Array RowEvent → Subst → Subst
linked events subst = foldl link subst events
  where
  link reached = case _ of
    Matched consumed existing → connect existing consumed
      (connect consumed existing reached)
    Extended meta source → connect (Occurrence.Extended meta) source reached
  connect from to reached =
    if anonymous from || anonymous to then reached
    else linkTo from to reached

-- The consuming origin becomes that of each occurrence a consumption
-- extended or matched; an occurrence that had one keeps it.
attributed ∷ Origin → Array RowEvent → Origins → Origins
attributed origin events origins = foldl attribute origins events
  where
  attribute reached = case _ of
    Matched _ existing → remembered existing reached
    Extended meta _ → remembered (Occurrence.Extended meta) reached
  remembered occurrence reached =
    if anonymous occurrence then reached
    else remember occurrence origin reached
