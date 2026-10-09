module Features.Check.Occurrence (OccurrenceId(..)) where

import Prelude
import Domain.Syntax (Span)

-- Which occurrence of a label in a row (FX001 design §6 "Provenance"):
-- the label at a position of a row written at a span (a signature, an
-- annotation, or a consumed stage's row), or the label a meta's binding
-- added when row unification extended that meta. Each such binding holds
-- one label (Features.Check.Binding `extendRow`), so the meta identifies
-- it. Occurrences are never merged by effect key: two entries of one key
-- are two occurrences.
data OccurrenceId = Written Span Int | Extended Int

derive instance eqOccurrenceId ∷ Eq OccurrenceId
derive instance ordOccurrenceId ∷ Ord OccurrenceId
