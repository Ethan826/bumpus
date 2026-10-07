module Features.Resolve.Fresh
  ( Fresh
  , failure
  , fresh
  , liftEither
  , runFresh
  ) where

import Prelude
import Data.Either (Either(..))
import Domain.Resolved (LocalId(..))
import Domain.Syntax (Diagnostic)

-- A result plus the next free LocalId.
type Numbered a = { value ∷ a, next ∷ Int }

-- Resolution with LocalId numbering and the first diagnostic. Unlike the
-- applicative-only Parser it has Bind: a pattern's binders form the scope of
-- its arm body. Array `traverse` over it is balanced, so the call depth of
-- running a long argument list or match is logarithmic in its length.
newtype Fresh a = Fresh (Int → Either Diagnostic (Numbered a))

instance Functor Fresh where
  map transform (Fresh run) = Fresh (map (mapValue transform) <<< run)

instance Apply Fresh where
  apply = ap

instance Applicative Fresh where
  pure value = Fresh (unchanged value)

instance Bind Fresh where
  bind (Fresh run) continue = Fresh (resume <=< run)
    where
    resume numbered = step (continue numbered.value) numbered.next

instance Monad Fresh

-- The next LocalId; ids are handed out in the order `fresh` runs.
fresh ∷ Fresh LocalId
fresh = Fresh issue
  where
  issue next = Right { value: LocalId next, next: next + 1 }

failure ∷ ∀ a. Diagnostic → Fresh a
failure diagnostic = liftEither (Left diagnostic)

liftEither ∷ ∀ a. Either Diagnostic a → Fresh a
liftEither result = Fresh carry
  where
  carry next = numberedAt next <$> result
  numberedAt next value = { value, next }

-- Runs from `next`, the first LocalId after the parameters.
runFresh ∷ ∀ a. Int → Fresh a → Either Diagnostic a
runFresh next resolution = valueOf <$> step resolution next
  where
  valueOf numbered = numbered.value

step ∷ ∀ a. Fresh a → Int → Either Diagnostic (Numbered a)
step (Fresh run) = run

unchanged ∷ ∀ a. a → Int → Either Diagnostic (Numbered a)
unchanged value next = Right { value, next }

mapValue ∷ ∀ a b. (a → b) → Numbered a → Numbered b
mapValue transform numbered =
  { value: transform numbered.value, next: numbered.next }
