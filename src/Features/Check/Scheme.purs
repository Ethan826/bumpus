module Features.Check.Scheme
  ( State
  , Threaded
  , Scheme
  , start
  , threadAll
  , instantiate
  , at
  , flexible
  , opened
  , resolved
  , holes
  ) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Foldable (foldl)
import Data.Map (Map)
import Data.Map as Map
import Data.Maybe (maybe)
import Data.Traversable (traverse)
import Domain.Checked.Internal (Open(..))
import Domain.Checked.Internal as Checked
import Domain.Syntax (Diagnostic)
import Domain.Type (Ty(..), VarId(..))
import Features.Check.Unify (Flex, Subst, resolve)
import Features.Check.Unify as Unify
import Features.Check.Walk (foldTypes, retype)

-- One function's checking state: its substitution and next fresh meta.
-- While a function is checked, a checked-IR type's `Hole m` is the meta m;
-- `holes` renumbers the ones still unsolved once the function is done.
type State = { subst ∷ Subst, next ∷ Int }

type Threaded a = { value ∷ a, state ∷ State }

-- One use of a scheme: its variable `VarId i` became meta `base + i`.
type Scheme = { arguments ∷ Array (Ty Open), base ∷ Int }

-- Threads the state through an array, left to right. Array's traverse
-- nests its applies in a balanced tree, so long arrays (thousands of arms
-- or arguments) neither copy per item nor nest one frame per item.
newtype Thread a = Thread (State → Either Diagnostic (Threaded a))

instance functorThread ∷ Functor Thread where
  map change (Thread run) = Thread (map changed <<< run)
    where
    changed threaded = threaded { value = change threaded.value }

instance applyThread ∷ Apply Thread where
  apply (Thread runChange) (Thread run) = Thread applied
    where
    applied state = runChange state >>= continue
    continue changing = map (changed changing.value) (run changing.state)
    changed change threaded = threaded { value = change threaded.value }

instance applicativeThread ∷ Applicative Thread where
  pure value = Thread threaded
    where
    threaded state = Right { value, state }

start ∷ State
start = { subst: Unify.empty, next: 0 }

threadAll
  ∷ ∀ a b
  . (State → a → Either Diagnostic (Threaded b))
  → State
  → Array a
  → Either Diagnostic (Threaded (Array b))
threadAll step state items = running (traverse threaded items)
  where
  threaded item = Thread (flip step item)
  running (Thread run) = run state

-- Fresh metas for a scheme's variables, in their VarId order.
instantiate ∷ ∀ a. Array a → State → Threaded Scheme
instantiate variables state =
  { value: { arguments: Array.mapWithIndex meta variables, base: state.next }
  , state: state { next = state.next + Array.length variables }
  }
  where
  meta index _ = TVar (Hole (state.next + index))

-- A scheme's type at one use.
at ∷ Scheme → Ty VarId → Ty Open
at scheme = map shifted
  where
  shifted (VarId index) = Hole (scheme.base + index)

flexible ∷ Ty Open → Ty Flex
flexible = map toFlex
  where
  toFlex = case _ of
    Checked.Rigid id → Unify.Rigid id
    Hole meta → Unify.Meta meta

opened ∷ Ty Flex → Ty Open
opened = map toOpen
  where
  toOpen = case _ of
    Unify.Rigid id → Checked.Rigid id
    Unify.Meta meta → Hole meta

resolved ∷ Subst → Ty Open → Ty Open
resolved subst ty = opened (resolve subst (flexible ty))

-- Renumbers a finished body's unsolved metas as holes 0, 1, …, in the
-- order `foldTypes` first meets them.
holes ∷ Checked.Expr → Checked.Expr
holes body = retype renamed body
  where
  numbering = (foldTypes number { next: 0, seen: Map.empty } body).seen
  number found ty = foldHoles numberHole found ty
  renamed ty = map renumber ty
  renumber = case _ of
    Hole meta → Hole (maybe meta identity (Map.lookup meta numbering))
    rigid → rigid

type Numbering = { next ∷ Int, seen ∷ Map Int Int }

numberHole ∷ Numbering → Int → Numbering
numberHole found meta =
  if Map.member meta found.seen then found
  else { next: found.next + 1, seen: Map.insert meta found.next found.seen }

foldHoles ∷ ∀ b. (b → Int → b) → b → Ty Open → b
foldHoles step found = case _ of
  TVar (Hole meta) → step found meta
  TData _ arguments → foldl (foldHoles step) found arguments
  _ → found
