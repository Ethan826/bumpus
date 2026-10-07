module Format.Stack (Stack, empty, push) where

import Prelude
import Data.Foldable (class Foldable, foldMapDefaultR)

-- An accumulator for long scans. Array.snoc copies the whole array on every
-- call, so building n items costs O(n²); pushing here is O(1), and
-- Array.fromFoldable rebuilds the items in push order in linear time. The
-- folds are self tail calls, which purs compiles to loops, so they are
-- stack-safe at any length (BACKLOG E002).
data Stack a = Bottom | Push (Stack a) a

-- Folds visit items in push order, oldest first.
instance Foldable Stack where
  foldr step initial stack = foldNewestFirst step initial stack
  foldl step initial stack =
    foldNewestFirst (flip step) initial (reverse Bottom stack)
  foldMap transform stack = foldMapDefaultR transform stack

empty ∷ ∀ a. Stack a
empty = Bottom

push ∷ ∀ a. a → Stack a → Stack a
push item stack = Push stack item

foldNewestFirst ∷ ∀ a b. (a → b → b) → b → Stack a → b
foldNewestFirst _ result Bottom = result
foldNewestFirst step result (Push below item) =
  foldNewestFirst step (step item result) below

reverse ∷ ∀ a. Stack a → Stack a → Stack a
reverse result Bottom = result
reverse result (Push below item) = reverse (Push result item) below
