module Features.Check.Unlowered (reject) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (maybe)
import Domain.Checked.Internal as Checked
import Domain.Problem (Problem(..))
import Domain.Syntax (Diagnostic, origin, problemAt)

-- User effects check now; runtime evidence and handlers arrive in Task 7.
reject ∷ Checked.Program → Either Diagnostic Unit
reject (Checked.Program program)
  | Array.null program.effects = Right unit
  | otherwise = Left (problemAt (Internal "unlowered effect") span)
      where
      span = maybe { start: origin, end: origin } effectSpan
        (Array.head program.effects)
      effectSpan effect = effect.span
