module Domain.Ids (TypeId(..), EffectId(..)) where

import Prelude

-- A declared type, numbered by Resolve in declaration order.
newtype TypeId = TypeId Int

-- A declared effect, numbered by Resolve in declaration order (FX001).
newtype EffectId = EffectId Int

derive instance eqTypeId ∷ Eq TypeId
derive instance ordTypeId ∷ Ord TypeId
derive instance eqEffectId ∷ Eq EffectId
derive instance ordEffectId ∷ Ord EffectId
