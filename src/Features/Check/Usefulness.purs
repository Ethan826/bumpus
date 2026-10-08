module Features.Check.Usefulness (useful) where

import Prelude
import Control.Monad.Rec.Class (Step(..), tailRecM)
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (maybe, maybe')
import Domain.Checked.Internal (Open)
import Domain.Checked.Internal as Checked
import Domain.Resolved (Ty)
import Features.Check.Matrix
  ( Column
  , Pat(..)
  , Vector
  , column
  , complete
  , defaults
  , headsOf
  , patternType
  , simplifyRow
  , specialize
  , wildcards
  )
import Features.Check.Search (Stack(..))
import Features.Check.Signature
  ( Head
  , Signature
  , arity
  , candidates
  , fieldTypes
  )
import Features.Check.Tables (Lookup)

-- One U(P, q) instance; q and every row of P have the types `tys`.
type Problem = { tys ∷ Array (Ty Open), rows ∷ Array Vector, q ∷ Vector }

-- A complete wildcard column: the heads not yet tried, in order.
type Branch = { rows ∷ Array Vector, split ∷ Column, heads ∷ Array Head }

data Next = Settled Boolean | Continue Problem | Fork Branch

type State = { next ∷ Next, pending ∷ Stack Branch }

-- U(P, q): whether some value matches q and no row of P. Each column is one
-- loop step and untried heads wait on an explicit stack, so the JavaScript
-- stack no longer grows per column; recursion overflowed at about 1,600
-- columns (G001 final review I1). Heads are tried in declaration order and
-- the first useful one ends the search, as before.
useful
  ∷ Signature
  → Array (Array Checked.Pattern)
  → Array Checked.Pattern
  → Lookup Boolean
useful signature rows q = tailRecM (step signature)
  { next: Continue problem, pending: Bottom }
  where
  problem =
    { tys: map patternType q, rows: map simplifyRow rows, q: simplifyRow q }

step ∷ Signature → State → Lookup (Step State Boolean)
step signature state = case state.next of
  Continue problem → resume <$> advance signature problem
  Settled true → pure (Done true)
  Settled false → backtrack signature state.pending
  Fork branch → backtrack signature (Push branch state.pending)
  where
  resume next = Loop { next, pending: state.pending }

-- Tries the innermost branch's next head; false once no branch remains.
backtrack ∷ Signature → Stack Branch → Lookup (Step State Boolean)
backtrack signature = case _ of
  Bottom → pure (Done false)
  Push branch rest →
    maybe' (exhausted rest) (attempt signature branch rest)
      (Array.uncons branch.heads)
  where
  exhausted rest _ = pure (Loop { next: Settled false, pending: rest })

attempt
  ∷ Signature
  → Branch
  → Stack Branch
  → { head ∷ Head, tail ∷ Array Head }
  → Lookup (Step State Boolean)
attempt signature branch rest split = resume <$> expanded
  where
  expanded = arity signature split.head >>=
    specialized signature
      branch.rows
      branch.split
      split.head <<< wildcards
  remaining = Push (branch { heads = split.tail }) rest
  resume problem = Loop { next: Continue problem, pending: remaining }

advance ∷ Signature → Problem → Lookup Next
advance signature problem =
  if Array.null problem.rows then Right (Settled true)
  else column problem.tys problem.q >>= maybe (Right (Settled false))
    (judge signature problem.rows)

-- An explicit head specializes syntactically; a wildcard head splits only
-- when the column's heads are complete.
judge ∷ Signature → Array Vector → Column → Lookup Next
judge signature rows split = case split.pat of
  Headed head fields → Continue <$> specialized signature rows split head
    fields
  Any → complete signature split.ty (headsOf rows) >>= splitWildcard
  where
  splitWildcard whole =
    if whole then Fork <<< branch <$> candidates signature split.ty
    else Right (Continue { tys: split.tys, rows: defaults rows, q: split.rest })
  branch heads = { rows, split, heads }

specialized
  ∷ Signature → Array Vector → Column → Head → Vector → Lookup Problem
specialized signature rows split head fields = do
  types ← fieldTypes signature split.ty head
  specializedRows ← specialize signature head rows
  pure
    { tys: types <> split.tys, rows: specializedRows, q: fields <> split.rest }
