module Features.Check.Matrix
  ( Pat(..)
  , Vector
  , Column
  , column
  , complete
  , specialize
  , defaults
  , headsOf
  , wildcards
  , simplifyRow
  , patternType
  ) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (Maybe(..), maybe, maybe')
import Domain.IR.Internal as IR
import Domain.Problem (Problem(..))
import Domain.Resolved (Ty(..))
import Features.Check.Signature (Head(..), Signature, arity, candidates)
import Features.Check.Tables (Lookup)

-- Binders and wildcards are indistinguishable to coverage.
data Pat = Any | Headed Head (Array Pat)

type Vector = Array Pat

type Column = { ty ∷ Ty, tys ∷ Array Ty, pat ∷ Pat, rest ∷ Vector }

-- Types and patterns advance together; unequal lengths are a compiler bug.
column ∷ Array Ty → Vector → Lookup (Maybe Column)
column tys q = maybe' noTypes withTypes (Array.uncons tys)
  where
  noTypes _ = if Array.null q then Right Nothing else mismatch
  withTypes types = maybe mismatch (Right <<< Just <<< split types)
    (Array.uncons q)
  mismatch = Left (Internal "Coverage vector length mismatch")
  split types patterns =
    { ty: types.head, tys: types.tail, pat: patterns.head, rest: patterns.tail }

-- Int has unboundedly many heads, so it is never complete.
complete ∷ Signature → Ty → Array Head → Lookup Boolean
complete signature ty heads =
  if ty == TInt then Right false
  else Array.all present <$> candidates signature ty
  where
  present head = Array.elem head heads

-- Resolution enforces constructor arity, so a head whose field count
-- disagrees with the signature is a compiler bug, never a non-match. The
-- check precedes a plain mapMaybe: a per-row `traverse` over Either was most
-- of a wide match's time (G001 Task 4b).
specialize ∷ Signature → Head → Array Vector → Lookup (Array Vector)
specialize signature head rows = do
  count ← arity signature head
  when (Array.any (malformed count) rows)
    (Left (Internal "Coverage field count mismatch"))
  pure (Array.mapMaybe (specializeRow count) rows)
  where
  malformed count row = maybe false (mismatched count) (Array.head row)
  mismatched count = case _ of
    Any → false
    Headed found fields → found == head && Array.length fields /= count
  specializeRow count row = Array.uncons row >>= specializeSplit count
  specializeSplit count split = case split.head of
    Any → Just (wildcards count <> split.tail)
    Headed found fields
      | found == head → Just (fields <> split.tail)
      | otherwise → Nothing

defaults ∷ Array Vector → Array Vector
defaults = Array.mapMaybe defaultRow
  where
  defaultRow row = Array.uncons row >>= defaultSplit
  defaultSplit split = case split.head of
    Any → Just split.tail
    Headed _ _ → Nothing

headsOf ∷ Array Vector → Array Head
headsOf = Array.mapMaybe firstHead
  where
  firstHead row = Array.head row >>= headOf
  headOf = case _ of
    Any → Nothing
    Headed head _ → Just head

wildcards ∷ Int → Vector
wildcards count = Array.replicate count Any

simplifyRow ∷ Array IR.Pattern → Vector
simplifyRow = map simplify

simplify ∷ IR.Pattern → Pat
simplify (IR.Pattern pattern) = case pattern.shape of
  IR.Wildcard → Any
  IR.Bind _ → Any
  IR.IntLit value → Headed (HInt value) []
  IR.BoolLit value → Headed (HBool value) []
  IR.Ctor id fields → Headed (HCtor id) (map simplify fields)

patternType ∷ IR.Pattern → Ty
patternType (IR.Pattern pattern) = pattern.ty
