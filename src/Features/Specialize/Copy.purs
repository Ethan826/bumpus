module Features.Specialize.Copy
  ( Copy
  , Copied
  , run
  , get
  , modify
  , failWith
  ) where

import Prelude
import Data.Either (Either(..))
import Domain.Syntax (Diagnostic)

type Copied s a = { value ∷ a, state ∷ s }

-- A computation over specialization's tables that may fail. Apply runs
-- its two sides in sequence without Bind, so Array's balanced `traverse`
-- copies thousands of arguments or arms in shallow stack.
newtype Copy s a = Copy (s → Either Diagnostic (Copied s a))

instance functorCopy ∷ Functor (Copy s) where
  map change (Copy step) = Copy (map changed <<< step)
    where
    changed copied = copied { value = change copied.value }

instance applyCopy ∷ Apply (Copy s) where
  apply (Copy stepChange) (Copy step) = Copy applied
    where
    applied state = stepChange state >>= continue
    continue changing = map (changed changing.value) (step changing.state)
    changed change copied = copied { value = change copied.value }

instance applicativeCopy ∷ Applicative (Copy s) where
  pure value = Copy copied
    where
    copied state = Right { value, state }

instance bindCopy ∷ Bind (Copy s) where
  bind (Copy step) next = Copy bound
    where
    bound state = step state >>= continue
    continue copied = running (next copied.value) copied.state
    running (Copy following) = following

instance monadCopy ∷ Monad (Copy s)

run ∷ ∀ s a. Copy s a → s → Either Diagnostic (Copied s a)
run (Copy step) = step

get ∷ ∀ s. Copy s s
get = Copy copied
  where
  copied state = Right { value: state, state }

modify ∷ ∀ s. (s → s) → Copy s Unit
modify change = Copy copied
  where
  copied state = Right { value: unit, state: change state }

failWith ∷ ∀ s a. Diagnostic → Copy s a
failWith diagnostic = Copy failed
  where
  failed _ = Left diagnostic
