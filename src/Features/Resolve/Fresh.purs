module Features.Resolve.Fresh
  ( Fresh
  , failure
  , fresh
  , liftEither
  , runFresh
  , thread
  ) where

import Prelude
import Data.Either (Either(..))
import Data.Traversable (traverse)
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

-- A resolution that also threads a state `s` left to right: a block's
-- scope, which each `let` extends for the items after it (FX001).
newtype Threading s a =
  Threading (s → Int → Either Diagnostic (Carried s a))

type Carried s a = { value ∷ a, state ∷ s, next ∷ Int }

instance Functor (Threading s) where
  map transform (Threading run) = Threading (mapped <<< run)
    where
    mapped running next = map changed (running next)
    changed carried = carried { value = transform carried.value }

instance Apply (Threading s) where
  apply (Threading runChange) (Threading run) = Threading applied
    where
    applied state next = runChange state next >>= continue
    continue changing = map (changed changing.value)
      (run changing.state changing.next)
    changed change carried = carried { value = change carried.value }

instance Applicative (Threading s) where
  pure value = Threading carry
    where
    carry state next = Right { value, state, next }

-- `each` over the items in order, each seeing the state the one before it
-- left. Array's traverse nests its applies in a balanced tree (as
-- Features.Check.Scheme `threadAll` does), so a block of 20,000 items
-- neither copies per item nor nests one frame per item.
thread
  ∷ ∀ s a b
  . (s → a → Fresh { value ∷ b, state ∷ s })
  → s
  → Array a
  → Fresh { value ∷ Array b, state ∷ s }
thread each state items = Fresh (finish <<< running (traverse threaded items))
  where
  threaded item = Threading (stepped item)
  stepped item before next = map carry (step (each before item) next)
  carry stepResult =
    { value: stepResult.value.value
    , state: stepResult.value.state
    , next: stepResult.next
    }
  running (Threading run) = run state
  finish result = map numberedOf result
  numberedOf whole =
    { value: { value: whole.value, state: whole.state }, next: whole.next }

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
