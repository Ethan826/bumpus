module Features.Check.Unify
  ( Flex(..)
  , Subst(..)
  , Failure(..)
  , empty
  , substitute
  , compose
  , resolve
  , unify
  ) where

import Prelude
import Control.Monad.Rec.Class (Step(..), tailRec)
import Data.Array as Array
import Data.Either (Either(..))
import Data.Foldable (foldM)
import Data.Map (Map)
import Data.Map as Map
import Data.Maybe (maybe)
import Data.Tuple (Tuple(..))
import Domain.Type (Ty(..), VarId)

-- A checker type variable: a signature's own variable, which is fixed inside
-- its function and unifies only with itself, or a meta, which stands for
-- one use's still unknown type argument and may be bound to any type.
data Flex = Rigid VarId | Meta Int

derive instance eqFlex ∷ Eq Flex
derive instance ordFlex ∷ Ord Flex

-- Triangular: a binding may mention other bound metas. Binding a meta then
-- never rewrites earlier bindings; `resolve` follows the links on demand.
newtype Subst = Subst (Map Int (Ty Flex))

-- Both carry types resolved under the substitution reached at the failure:
-- a mismatch names the first pair of subterms that differ, left to right;
-- an occurs failure names the meta and the type that properly contains it.
data Failure = Mismatch (Ty Flex) (Ty Flex) | Occurs Int (Ty Flex)

empty ∷ Subst
empty = Subst Map.empty

-- One pass: each bound meta becomes its binding, which is not revisited.
-- Ty's bind is exactly this, and is defined even on cyclic substitutions.
substitute ∷ Subst → Ty Flex → Ty Flex
substitute (Subst bindings) ty = ty >>= replaced
  where
  replaced flex = case flex of
    Meta meta → maybe (TVar flex) identity (Map.lookup meta bindings)
    Rigid _ → TVar flex

-- `substitute (compose later earlier)` is `substitute later` after
-- `substitute earlier`; Map.union keeps the earlier side's bindings.
compose ∷ Subst → Subst → Subst
compose later@(Subst laterBindings) (Subst earlierBindings) =
  Subst (Map.union (map rewritten earlierBindings) laterBindings)
  where
  rewritten binding = substitute later binding

-- Follows bindings until no bound meta remains. Only for acyclic
-- substitutions, which are all `unify` makes. Recursion is over the type's
-- structure only; a chain of meta-to-meta links is followed by `walk`, a
-- loop, so long chains cost no stack.
resolve ∷ Subst → Ty Flex → Ty Flex
resolve subst ty = case walk subst ty of
  TData id arguments → TData id (map resolved arguments)
  settled → settled
  where
  resolved argument = resolve subst argument

-- Rigid matches only the same rigid; a meta binds to any type that does not
-- properly contain it; applied types unify argument-wise, left to right,
-- stopping at the first failure.
unify ∷ Subst → Ty Flex → Ty Flex → Either Failure Subst
unify subst left right = unifyHeads subst (walk subst left) (walk subst right)

-- The type itself if it is not a bound meta, else the end of its chain.
walk ∷ Subst → Ty Flex → Ty Flex
walk (Subst bindings) start = tailRec step start
  where
  step ty = case ty of
    TVar (Meta meta) → maybe (Done ty) Loop (Map.lookup meta bindings)
    _ → Done ty

-- Both sides are walked, so a meta here is unbound.
unifyHeads ∷ Subst → Ty Flex → Ty Flex → Either Failure Subst
unifyHeads subst left right = case left, right of
  TVar (Meta meta), _ → bindMeta subst meta right
  _, TVar (Meta meta) → bindMeta subst meta left
  TVar (Rigid one), TVar (Rigid other) | one == other → Right subst
  TInt, TInt → Right subst
  TBool, TBool → Right subst
  TData one lefts, TData other rights
    | one == other && Array.length lefts == Array.length rights →
        foldM unifyPair subst (Array.zip lefts rights)
  _, _ → Left (Mismatch (resolve subst left) (resolve subst right))
  where
  unifyPair reached (Tuple leftArgument rightArgument) =
    unify reached leftArgument rightArgument

-- The occurs check runs on the resolved type, so it sees through bindings;
-- the stored binding stays unresolved, keeping the substitution triangular.
bindMeta ∷ Subst → Int → Ty Flex → Either Failure Subst
bindMeta subst@(Subst bindings) meta ty =
  if ty == TVar (Meta meta) then Right subst
  else if mentions meta resolved then Left (Occurs meta resolved)
  else Right (Subst (Map.insert meta ty bindings))
  where
  resolved = resolve subst ty

mentions ∷ Int → Ty Flex → Boolean
mentions meta = case _ of
  TVar (Meta other) → other == meta
  TData _ arguments → Array.any mentioned arguments
  _ → false
  where
  mentioned argument = mentions meta argument
