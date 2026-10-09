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
import Domain.Checked.Internal (Open)
import Domain.Checked.Internal as Checked
import Domain.Problem (Problem(..))
import Domain.Resolved (Ty(..))
import Features.Check.Signature (Head(..), Signature, arity, candidates)
import Features.Check.Tables (Lookup)

-- Binders and wildcards are indistinguishable to coverage.
data Pat = Any | Headed Head (Array Pat)

type Vector = Array Pat

type Column =
  { ty ∷ Ty Open, tys ∷ Array (Ty Open), pat ∷ Pat, rest ∷ Vector }

-- Types and patterns advance together; unequal lengths are a compiler bug.
column ∷ Array (Ty Open) → Vector → Lookup (Maybe Column)
column tys q = maybe' noTypes withTypes (Array.uncons tys)
  where
  noTypes _ = if Array.null q then Right Nothing else mismatch
  withTypes types = maybe mismatch (Right <<< Just <<< split types)
    (Array.uncons q)
  mismatch = Left (Internal "Coverage vector length mismatch")
  split types patterns =
    { ty: types.head, tys: types.tail, pat: patterns.head, rest: patterns.tail }

-- Int has unboundedly many heads, and a rigid variable, a hole or an arrow
-- is abstract (design §5), so none of them is ever complete. Unit has no
-- pattern but `_` and binders (FX001), so it is abstract too.
complete ∷ Signature → Ty Open → Array Head → Lookup Boolean
complete signature ty heads =
  if open ty then Right false
  else Array.all present <$> candidates signature ty
  where
  present head = Array.elem head heads
  open = case _ of
    TInt → true
    TUnit → true
    TVar _ → true
    TFun _ _ → true
    _ → false

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
  specializeRow count row = Array.head row >>= specializeFirst count row
  specializeFirst count row = case _ of
    Any → Just (wildcards count <> afterFirst row)
    Headed found fields
      | found == head → Just (fields <> afterFirst row)
      | otherwise → Nothing

-- Rows are judged by their first pattern before the rest is copied: an
-- `uncons` per row copied every row a specialization or default drops,
-- and a match's redundancy check drops nearly all of them (T003).
defaults ∷ Array Vector → Array Vector
defaults = Array.mapMaybe defaultRow
  where
  defaultRow row = Array.head row >>= defaultFirst row
  defaultFirst row = case _ of
    Any → Just (afterFirst row)
    Headed _ _ → Nothing

afterFirst ∷ Vector → Vector
afterFirst = Array.drop 1

headsOf ∷ Array Vector → Array Head
headsOf = Array.mapMaybe firstHead
  where
  firstHead row = Array.head row >>= headOf
  headOf = case _ of
    Any → Nothing
    Headed head _ → Just head

wildcards ∷ Int → Vector
wildcards count = Array.replicate count Any

simplifyRow ∷ Array Checked.Pattern → Vector
simplifyRow = map simplify

simplify ∷ Checked.Pattern → Pat
simplify (Checked.Pattern pattern) = case pattern.shape of
  Checked.Wildcard → Any
  Checked.Bind _ → Any
  Checked.IntLit value → Headed (HInt value) []
  Checked.BoolLit value → Headed (HBool value) []
  Checked.Ctor id fields → Headed (HCtor id) (map simplify fields)

patternType ∷ Checked.Pattern → Ty Open
patternType (Checked.Pattern pattern) = pattern.ty
