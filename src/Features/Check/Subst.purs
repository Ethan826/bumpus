module Features.Check.Subst
  ( Flex(..)
  , Subst(..)
  , Failure(..)
  , empty
  , isEmpty
  , substitute
  , substituteRow
  , compose
  , walk
  , walkRow
  , resolve
  , resolveRow
  , resolveLabel
  , boundRow
  , metaOf
  ) where

import Prelude
import Prim hiding (Row)
import Control.Monad.Rec.Class (Step(..), tailRec)
import Data.Array as Array
import Data.Map (Map)
import Data.Map as Map
import Data.Maybe (Maybe(..), maybe)
import Domain.Row (Label(..), Row(..), isPure, openRow)
import Domain.Type
  ( Substitution
  , Ty(..)
  , TyRow
  , VarId
  , foldStages
  , stagesThrough
  )
import Domain.Type as Type
import Features.Check.Search (Stack(..), stackItems)

-- A checker variable: a signature's own variable, which is fixed inside
-- its function and unifies only with itself, or a meta, which stands for
-- one use's still unknown type or row and may be bound to any. A variable
-- has one sort by construction, so a meta is looked up by its position:
-- a type's variable in `types`, a row's tail in `rows`.
data Flex = Rigid VarId | Meta Int

derive instance eqFlex ∷ Eq Flex
derive instance ordFlex ∷ Ord Flex

-- Triangular: a binding may mention other bound metas. Binding a meta then
-- never rewrites earlier bindings; `resolve` follows the links on demand.
-- Row unification extends a row meta with a fresh tail meta; `fresh` is
-- the next, counting down from -1, so it never meets a checker meta,
-- which counts up from 0 (Features.Check.Scheme).
newtype Subst = Subst
  { types ∷ Map Int (Ty Flex), rows ∷ Map Int (TyRow Flex), fresh ∷ Int }

-- Types and rows are resolved under the substitution reached at the
-- failure: a mismatch names the first pair of subterms that differ, left
-- to right; an occurs failure names the meta and the type that properly
-- contains it. `TooDeep`: the binding, resolved, would be deeper than the
-- limit. Rows (FX001): `RowMissing`, a label the other row, closed or
-- rigid, lacks; `RowExtra`, an entry left over against a closed or rigid
-- tail; `RowSharedTail`, the two rows (Leijen's side condition);
-- `RowMismatch`, two rows that differ in their tails alone.
data Failure
  = Mismatch (Ty Flex) (Ty Flex)
  | Occurs Int (Ty Flex)
  | TooDeep
  | RowMissing (Label (Ty Flex)) (TyRow Flex)
  | RowExtra (Label (Ty Flex))
  | RowSharedTail (TyRow Flex) (TyRow Flex)
  | RowMismatch (TyRow Flex) (TyRow Flex)

empty ∷ Subst
empty = Subst { types: Map.empty, rows: Map.empty, fresh: -1 }

-- No meta is bound, so resolving under it changes no type.
isEmpty ∷ Subst → Boolean
isEmpty (Subst bindings) = Map.isEmpty bindings.types
  && Map.isEmpty bindings.rows

-- One pass: each bound meta becomes its binding, which is not revisited.
-- Domain.Type's substitution is exactly this, and is defined even on
-- cyclic substitutions.
substitute ∷ Subst → Ty Flex → Ty Flex
substitute subst = Type.substitute (substitution subst)

substituteRow ∷ Subst → TyRow Flex → TyRow Flex
substituteRow subst = Type.substituteRow (substitution subst)

-- `substitute (compose later earlier)` is `substitute later` after
-- `substitute earlier`; Map.union keeps the earlier side's bindings.
compose ∷ Subst → Subst → Subst
compose later@(Subst laterBindings) (Subst earlierBindings) = Subst
  { types: Map.union (map (substitute later) earlierBindings.types)
      laterBindings.types
  , rows: Map.union (map (substituteRow later) earlierBindings.rows)
      laterBindings.rows
  , fresh: min laterBindings.fresh earlierBindings.fresh
  }

-- The type itself if it is not a bound meta, else the end of its chain.
-- Only a meta enters the loop: most types walked are not one, and the
-- loop's steps were a measurable share of checking a large body (T003).
walk ∷ Subst → Ty Flex → Ty Flex
walk (Subst bindings) start = case start of
  TVar (Meta _) → tailRec step start
  _ → start
  where
  step ty = case ty of
    TVar (Meta meta) → maybe (Done ty) Loop (Map.lookup meta bindings.types)
    _ → Done ty

-- The binding of a row's tail, if the tail is a bound meta.
boundRow ∷ Subst → Maybe Flex → Maybe (TyRow Flex)
boundRow (Subst bindings) tail = flip Map.lookup bindings.rows =<<
  (metaOf =<< tail)

-- The row with its tail's bindings spliced in, by a loop, until the tail
-- is closed, rigid or an unbound meta. Labels stay unresolved. Chunks are
-- gathered on a stack and joined once, so a chain of 1,000 one-label
-- bindings costs no copy per binding.
walkRow ∷ Subst → TyRow Flex → TyRow Flex
walkRow subst row@(Row labels tail) =
  maybe row spliced (boundRow subst tail)
  where
  spliced first = joined
    (tailRec step { chunks: Push labels Bottom, next: first })
  step pending = advance pending.chunks pending.next
  advance chunks (Row more rest) = maybe
    (Done { chunks: Push more chunks, tail: rest })
    (Loop <<< pushed chunks more)
    (boundRow subst rest)
  pushed chunks more next = { chunks: Push more chunks, next }
  joined done = Row (Array.concat (stackItems done.chunks)) done.tail

-- Follows bindings until no bound meta remains. Only for acyclic
-- substitutions, which are all `unify` makes. Recursion is over the type's
-- structure only; a chain of meta-to-meta links is followed by `walk`, a
-- loop, so long chains cost no stack. An arrow's spine is followed
-- through bound metas by a loop, and a row's tail by `walkRow`.
resolve ∷ Subst → Ty Flex → Ty Flex
resolve subst ty = case walk subst ty of
  TData id arguments rows → TData id (map resolved arguments)
    (map (resolveRow subst) rows)
  THandler label row → THandler (resolveLabel subst label)
    (resolveRow subst row)
  arrow@(TFun _ _ _) → resolvedStages (stagesThrough (walk subst) arrow)
  settled → settled
  where
  resolved argument = resolve subst argument
  resolvedStages found = foldStages stage (resolved found.result)
    found.arrows
  stage parameter row rest = TFun (resolved parameter)
    (resolveRow subst row)
    rest

resolveRow ∷ Subst → TyRow Flex → TyRow Flex
resolveRow subst row
  | isPure row = row
  | otherwise = resolvedLabels (walkRow subst row)
      where
      resolvedLabels (Row labels tail) = Row (map (resolveLabel subst) labels)
        tail

resolveLabel ∷ Subst → Label (Ty Flex) → Label (Ty Flex)
resolveLabel subst (Label effect arguments) =
  Label effect (map (resolve subst) arguments)

substitution ∷ Subst → Substitution Flex Flex
substitution (Subst bindings) = { types: replaced, rows: replacedRow }
  where
  replaced flex = maybe (TVar flex) identity (bound bindings.types flex)
  replacedRow flex = maybe (openRow flex) identity (bound bindings.rows flex)

-- The binding of a variable in one sort's table, if it is a bound meta.
bound ∷ ∀ a. Map Int a → Flex → Maybe a
bound table flex = flip Map.lookup table =<< metaOf flex

metaOf ∷ Flex → Maybe Int
metaOf = case _ of
  Meta meta → Just meta
  Rigid _ → Nothing
