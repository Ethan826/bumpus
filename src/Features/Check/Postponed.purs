module Features.Check.Postponed (count, pairs, stampSince) where

import Prelude
import Data.Array as Array
import Features.Check.Occurrence (Sides, nowhere)
import Features.Check.Scheme (State)
import Features.Check.Subst (RowPair, Subst(..))

-- How many row pairs are set aside (design §2), in the order they were.
count ∷ Subst → Int
count (Subst bindings) = Array.length bindings.postponed

pairs ∷ Subst → Array RowPair
pairs (Subst bindings) = bindings.postponed

-- Plain type unification writes no spans (`untraced`), so a pair it set
-- aside has none. Those added since `before` take `sides`: where the
-- argument that caused them, and the parameter it met, were written.
stampSince ∷ Sides → State → State → State
stampSince sides before after = after { subst = Subst stamped }
  where
  Subst bindings = after.subst
  stamped = bindings { postponed = Array.mapWithIndex place bindings.postponed }
  place index pair =
    if index >= count before.subst && pair.sides.left == nowhere then
      pair { sides = sides }
    else pair
