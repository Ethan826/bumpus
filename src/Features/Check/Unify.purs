module Features.Check.Unify
  ( Flex(..)
  , Subst(..)
  , Failure(..)
  , inferredTypeLimit
  , empty
  , substitute
  , compose
  , resolve
  , unify
  , exceedsLimit
  ) where

import Prelude
import Control.Monad.Rec.Class (Step(..), tailRec)
import Data.Array as Array
import Data.Either (Either(..))
import Data.Foldable (foldM, foldl)
import Data.Map (Map)
import Data.Map as Map
import Data.Maybe (maybe)
import Data.Tuple (Tuple(..))
import Domain.Type (Ty(..), VarId)
import Features.Check.Search (Stack(..))

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
-- `TooDeep`: the binding, resolved, would be deeper than the limit.
data Failure = Mismatch (Ty Flex) (Ty Flex) | Occurs Int (Ty Flex) | TooDeep

-- The deepest type checking may build (ruling R7, in the spirit of ADR 006).
-- Resolution and the occurs check recurse over a type's structure and
-- overflowed the default stack near 5,000 levels (BACKLOG E006); a program
-- within the source nesting limit can compose deeper types, so checking
-- rejects them first.
inferredTypeLimit ∷ Int
inferredTypeLimit = 1000

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
-- stopping at the first failure. The recursion is bounded by level (one per
-- applied type entered, so a level is a resolved depth): metas bound
-- earlier in the same unification can chain into types deeper than either
-- operand was, so past `inferredTypeLimit` it fails with TooDeep instead of
-- recursing further (ruling R7, fix round 2).
unify ∷ Subst → Ty Flex → Ty Flex → Either Failure Subst
unify = unifyAt 1

-- The type itself if it is not a bound meta, else the end of its chain.
walk ∷ Subst → Ty Flex → Ty Flex
walk (Subst bindings) start = tailRec step start
  where
  step ty = case ty of
    TVar (Meta meta) → maybe (Done ty) Loop (Map.lookup meta bindings)
    _ → Done ty

unifyAt ∷ Int → Subst → Ty Flex → Ty Flex → Either Failure Subst
unifyAt level subst left right =
  if level > inferredTypeLimit then Left TooDeep
  else unifyHeads level subst (walk subst left) (walk subst right)

-- Both sides are walked, so a meta here is unbound.
unifyHeads ∷ Int → Subst → Ty Flex → Ty Flex → Either Failure Subst
unifyHeads level subst left right = case left, right of
  TVar (Meta meta), _ → bindMeta subst meta right
  _, TVar (Meta meta) → bindMeta subst meta left
  TVar (Rigid one), TVar (Rigid other) | one == other → Right subst
  TInt, TInt → Right subst
  TBool, TBool → Right subst
  TData one lefts, TData other rights
    | one == other && Array.length lefts == Array.length rights →
        foldM unifyPair subst (Array.zip lefts rights)
  _, _ → mismatch subst left right
  where
  unifyPair reached (Tuple leftArgument rightArgument) =
    unifyAt (level + 1) reached leftArgument rightArgument

-- The differing pair is resolved for the message only when that is safe.
mismatch ∷ Subst → Ty Flex → Ty Flex → Either Failure Subst
mismatch subst left right =
  if exceedsLimit subst left || exceedsLimit subst right then Left TooDeep
  else Left (Mismatch (resolve subst left) (resolve subst right))

-- Whether `ty`, resolved, is deeper than `inferredTypeLimit`, decided
-- without resolving it: an explicit-stack walk that stops past the limit,
-- so it is itself stack-safe on a type of any depth.
exceedsLimit ∷ Subst → Ty Flex → Boolean
exceedsLimit subst ty = tailRec step (Push { ty, level: 1 } Bottom)
  where
  step = case _ of
    Bottom → Done false
    Push item rest
      | item.level > inferredTypeLimit → Done true
      | otherwise → Loop (pushArguments item rest)
  pushArguments item rest = case walk subst item.ty of
    TData _ arguments → foldl (pushAt (item.level + 1)) rest arguments
    _ → rest
  pushAt level rest argument = Push { ty: argument, level } rest

-- The occurs check runs on the resolved type, so it sees through bindings;
-- the stored binding stays unresolved, keeping the substitution triangular.
-- The depth bound is checked first, since resolving recurses.
bindMeta ∷ Subst → Int → Ty Flex → Either Failure Subst
bindMeta subst@(Subst bindings) meta ty =
  if ty == TVar (Meta meta) then Right subst
  else if exceedsLimit subst ty then Left TooDeep
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
