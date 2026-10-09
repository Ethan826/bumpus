module Features.Check.Binding
  ( inferredTypeLimit
  , exceedsLimit
  , bindType
  , bindTail
  , extendRow
  ) where

import Prelude
import Prim hiding (Row)
import Control.Monad.Rec.Class (Step(..), tailRec)
import Data.Array as Array
import Data.Either (Either(..))
import Data.Foldable (foldl)
import Data.Map as Map
import Data.Maybe (Maybe(..), maybe')
import Domain.Row (Label(..), Row(..), isPure)
import Domain.Type (Ty(..), TyRow)
import Domain.Type.Parts (children, rowArguments, rowsOf)
import Features.Check.Search (Stack(..))
import Features.Check.Subst
  ( Failure(..)
  , Flex(..)
  , Subst(..)
  , resolve
  , walk
  , walkRow
  )

-- The deepest type checking may build (ruling R7, in the spirit of ADR 006).
-- Unification, resolution and the occurs check recurse over a type's
-- structure. Unification is the binding limit: inside the checker it
-- overflowed the default stack between about 1,525 and 1,779 levels
-- (resolution near 5,000; BACKLOG E006). A program within the source
-- nesting limit can compose deeper types, so checking rejects them first.
inferredTypeLimit ∷ Int
inferredTypeLimit = 1000

-- Whether `ty`, resolved, is deeper than `inferredTypeLimit`, decided
-- without resolving it: an explicit-stack walk that stops past the limit,
-- so it is itself stack-safe on a type of any depth. A row counts through
-- its label arguments only, each one level deeper, like a parameter.
exceedsLimit ∷ Subst → Ty Flex → Boolean
exceedsLimit subst ty = tailRec step (Push { ty, level: 1 } Bottom)
  where
  step = case _ of
    Bottom → Done false
    Push item rest
      | item.level > inferredTypeLimit → Done true
      | otherwise → Loop (pushParts item.level rest (walk subst item.ty))
  pushParts level rest = case _ of
    TData _ arguments rows → foldl (pushRow (level + 1))
      (foldl (pushAt (level + 1)) rest arguments)
      rows
    TFun parameter row result → pushAt (level + 1)
      (pushRow (level + 1) (pushAt level rest result) row)
      parameter
    THandler (Label _ arguments) row → pushRow (level + 1)
      (foldl (pushAt (level + 1)) rest arguments)
      row
    _ → rest
  pushRow level rest row
    | isPure row = rest
    | otherwise = foldl (pushAt level) rest (rowArguments (walkRow subst row))
  pushAt level rest argument = Push { ty: argument, level } rest

-- The depth bound is decided first, by a loop. Only within it does
-- `bindBounded` resolve the binding, which recurses: bindings made earlier
-- in the same unification can make `ty` far deeper than the limit.
-- (`where` bindings are strict, so the resolve lives in that helper rather
-- than in a binding here, where it would run before the test.)
bindType ∷ Subst → Int → Ty Flex → Either Failure Subst
bindType subst meta ty =
  if ty == TVar (Meta meta) then Right subst
  else if exceedsLimit subst ty then Left TooDeep
  else bindBounded subst meta ty

-- A row meta bound to a row with no label: another tail, or closed.
bindTail ∷ Subst → Int → TyRow Flex → Subst
bindTail (Subst bindings) meta row =
  Subst bindings { rows = Map.insert meta row bindings.rows }

-- Leijen's extension `meta := label + fresh`: the label must be bounded
-- and must not hold `meta` in a row of its arguments (an infinite row).
-- Each binding made here holds one label, so a label reached through it
-- is identified by the meta alone (Features.Check.Occurrence).
extendRow
  ∷ Subst
  → Int
  → Label (Ty Flex)
  → Either Failure { subst ∷ Subst, fresh ∷ Int }
extendRow subst@(Subst bindings) meta label@(Label _ arguments) =
  if Array.any (exceedsLimit subst) arguments then Left TooDeep
  else extendBounded subst meta label (map (resolve subst) arguments)
    bindings.fresh

-- The occurs check runs on the resolved type, so it sees through bindings;
-- the stored binding stays unresolved, keeping the substitution triangular.
-- Only for a `ty` already within `inferredTypeLimit`.
bindBounded ∷ Subst → Int → Ty Flex → Either Failure Subst
bindBounded subst@(Subst bindings) meta ty =
  if mentions meta resolved then Left (Occurs meta resolved)
  else Right (Subst bindings { types = Map.insert meta ty bindings.types })
  where
  resolved = resolve subst ty

extendBounded
  ∷ Subst
  → Int
  → Label (Ty Flex)
  → Array (Ty Flex)
  → Int
  → Either Failure { subst ∷ Subst, fresh ∷ Int }
extendBounded (Subst bindings) meta label resolved fresh =
  maybe' extended (Left <<< RowOccurs meta)
    (Array.find (holdsRow meta) resolved)
  where
  extended _ = Right
    { subst: Subst
        { types: bindings.types
        , rows: Map.insert meta (Row [ label ] (Just (Meta fresh)))
            bindings.rows
        , fresh: fresh - 1
        , postponed: bindings.postponed
        }
    , fresh
    }

-- Whether a resolved type holds type meta `meta`, in its parts or in the
-- label arguments of its rows.
mentions ∷ Int → Ty Flex → Boolean
mentions meta = case _ of
  TVar (Meta other) → other == meta
  ty → Array.any mentioned (children ty)
    || Array.any (Array.any mentioned <<< rowArguments) (rowsOf ty)
  where
  mentioned argument = mentions meta argument

-- Whether a resolved type has row meta `meta` as the tail of a row.
holdsRow ∷ Int → Ty Flex → Boolean
holdsRow meta ty = Array.any held (children ty)
  || Array.any inRow (rowsOf ty)
  where
  held part = holdsRow meta part
  inRow row@(Row _ tail) = tail == Just (Meta meta)
    || Array.any held (rowArguments row)
