module Features.Check.Search (Stack(..), firstJust) where

import Prelude
import Control.Monad.Rec.Class (Step(..), tailRecM)
import Data.Array as Array
import Data.Either (Either)
import Data.Maybe (Maybe(..), maybe, maybe')

-- The pending work of an explicit-stack search, innermost first. Coverage
-- keeps its continuations here rather than on the JavaScript stack, which
-- one pattern column per frame overflowed (G001 final review I1).
data Stack a = Bottom | Push a (Stack a)

-- The first item, in order, that `judge` settles, judging none after it.
-- Array.foldM over Either nests one bind per item, so a match of about 1,930
-- arms overflowed the stack (G001 Task 4b); tailRecM loops in constant stack.
firstJust ∷ ∀ e a b. (a → Either e (Maybe b)) → Array a → Either e (Maybe b)
firstJust judge items = tailRecM step 0
  where
  step index = maybe' exhausted (visit index) (Array.index items index)
  exhausted _ = pure (Done Nothing)
  visit index item = advance index <$> judge item
  advance index = maybe (Loop (index + 1)) (Done <<< Just)
