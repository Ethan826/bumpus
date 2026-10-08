module Features.Check.Functional
  ( Functional
  , functional
  , containsFunction
  ) where

import Prelude
import Control.Monad.Rec.Class (Step(..), tailRec)
import Data.Array as Array
import Data.Array.NonEmpty as NonEmpty
import Data.Foldable (foldl)
import Data.Map (Map)
import Data.Map as Map
import Data.Maybe (maybe)
import Data.Set (Set)
import Data.Set as Set
import Data.Tuple (Tuple(..), fst, snd)
import Domain.Resolved (CtorInfo)
import Domain.Type (Ty(..), TypeId(..))
import Features.Check.Nested (referenced)

-- The declared types a value of which can hold a function: one of their
-- constructors has a field that mentions an arrow, or mentions a declared
-- type that can (FN001 design §3: `Box(Int)` with `type Box(a) =
-- Box(a -> a)` is not comparable). An arrow anywhere in a type counts,
-- even as the argument of a type that never stores it: comparison is
-- refused by what the type says, not by how it is laid out.
type Functional = Set TypeId

-- `frontier` holds the types found functional last round.
type Spread = { found ∷ Functional, frontier ∷ Array TypeId }

-- Settled once per program. A program with no arrow in any field (every
-- program before FN001's syntax) builds no reference graph at all.
functional ∷ Array CtorInfo → Functional
functional ctors =
  if Array.null seeds then Set.empty else spread ctors seeds
  where
  seeds = map owner (Array.filter direct ctors)
  direct ctor = Array.any (containsFunction Set.empty) ctor.fields
  owner ctor = ctor.owner

-- Whether `ty` mentions an arrow, directly or through a functional type.
containsFunction ∷ ∀ v. Functional → Ty v → Boolean
containsFunction found = case _ of
  TFun _ _ → true
  TData id arguments → Set.member id found
    || Array.any (containsFunction found) arguments
  _ → false

-- The least fixed point over the reverse reference graph, one loop step
-- per round, so a chain of thousands of types costs no stack.
spread ∷ Array CtorInfo → Array TypeId → Functional
spread ctors seeds = tailRec (round (usersOf ctors))
  { found: Set.empty, frontier: seeds }

round ∷ Map TypeId (Array TypeId) → Spread → Step Spread Functional
round users state =
  if Array.null fresh then Done state.found
  else Loop
    { found: foldl insert state.found fresh
    , frontier: Array.concatMap using fresh
    }
  where
  fresh = Array.filter unseen (Array.nub state.frontier)
  unseen id = not (Set.member id state.found)
  insert found id = Set.insert id found
  using id = maybe [] identity (Map.lookup id users)

-- Each declared type with the owners of the constructors that mention it,
-- grouped by sorting rather than by appending per edge.
usersOf ∷ Array CtorInfo → Map TypeId (Array TypeId)
usersOf ctors = Map.fromFoldable (map group grouped)
  where
  grouped = Array.groupAllBy byUsed (Array.concatMap edges ctors)
  edges ctor = map (edge ctor) (Array.concatMap referenced ctor.fields)
  edge ctor index = Tuple (TypeId index) ctor.owner
  byUsed left right = compare (fst left) (fst right)
  group members = Tuple (fst (NonEmpty.head members))
    (map snd (NonEmpty.toArray members))
