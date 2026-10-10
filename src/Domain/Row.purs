module Domain.Row
  ( Row(..)
  , Label(..)
  , EffectRef(..)
  , LabelKey(..)
  , TypeHead(..)
  , closedRow
  , openRow
  , isPure
  , labelKey
  ) where

import Prelude
import Prim hiding (Row)
import Data.Array as Array
import Data.Maybe (Maybe(..), isNothing)
import Domain.Ids (EffectId, TypeId)

-- An effect row (FX001 design §2): labels in order, with multiplicity,
-- and a tail variable, or `Nothing` when the row is closed. Rows are a
-- sort of their own, parameterized over the argument type `t` so that
-- Domain.Type can import this module rather than the other way round.
data Row t v = Row (Array (Label t)) (Maybe v)

-- An effect applied to its type arguments: `State(Int)`, `Fail(DbError)`.
data Label t = Label EffectRef (Array t)

data EffectRef = UserEffect EffectId | FailEffect | ConsoleEffect

-- What scoped labels match by (design §2 "Label keys"): the effect, except
-- that `Fail` is keyed by the declared identity of its payload's head, so
-- `Fail(Error(Int))` and `Fail(Error(Bool))` share a key.
data LabelKey = EffectKey EffectRef | FailKey TypeHead

data TypeHead = HeadInt | HeadBool | HeadUnit | HeadData TypeId

derive instance eqEffectRef ∷ Eq EffectRef
derive instance ordEffectRef ∷ Ord EffectRef
derive instance eqTypeHead ∷ Eq TypeHead
derive instance ordTypeHead ∷ Ord TypeHead
derive instance eqLabelKey ∷ Eq LabelKey
derive instance ordLabelKey ∷ Ord LabelKey
derive instance eqLabel ∷ Eq t ⇒ Eq (Label t)
derive instance ordLabel ∷ Ord t ⇒ Ord (Label t)
derive instance eqRow ∷ (Eq t, Eq v) ⇒ Eq (Row t v)
derive instance ordRow ∷ (Ord t, Ord v) ⇒ Ord (Row t v)

-- `pure`: no label and no tail.
closedRow ∷ ∀ t v. Row t v
closedRow = Row [] Nothing

-- Just the tail `v`, which substitution replaces by a whole row.
openRow ∷ ∀ t v. v → Row t v
openRow tail = Row [] (Just tail)

-- No label and no tail: every row until row syntax (FX001 Task 4), so the
-- passes over types test it first and skip the rest.
isPure ∷ ∀ t v. Row t v → Boolean
isPure (Row labels tail) = Array.null labels && isNothing tail

-- `Nothing` while a Fail payload's head is not a declared type (a
-- variable): the key is deferred until the head is known.
labelKey ∷ ∀ t. (t → Maybe TypeHead) → Label t → Maybe LabelKey
labelKey headOf (Label effect arguments) = case effect of
  FailEffect → FailKey <$> (headOf =<< Array.head arguments)
  other → Just (EffectKey other)
