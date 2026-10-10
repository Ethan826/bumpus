module Features.Check.Occurrence
  ( OccurrenceId(..)
  , Sides
  , anonymous
  , nowhere
  ) where

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

-- Where each operand's own labels were written.
type Sides = { left ∷ Span, right ∷ Span }

-- A label of a row nobody wrote at a known place (the sides of an
-- untraced unification, line 0): no origin or link may be kept for it, as
-- every such row would share the one id.
anonymous ∷ OccurrenceId → Boolean
anonymous = case _ of
  Written span _ → span.start.line == 0
  Extended _ → false

-- The span of a row nobody wrote anywhere.
nowhere ∷ Span
nowhere = { start: start, end: start }
  where
  start = { offset: 0, line: 0, column: 0 }
