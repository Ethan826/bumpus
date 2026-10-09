module Features.Check.Unify
  ( module Features.Check.Subst
  , module Features.Check.Binding
  , unify
  ) where

import Prelude hiding (compose)
import Control.Monad.Rec.Class (Step(..), tailRec)
import Data.Array as Array
import Data.Either (Either(..), either)
import Data.Foldable (foldM)
import Data.Tuple (Tuple(..))
import Domain.Row (Label(..))
import Domain.Type (Ty(..), TyRow)
import Features.Check.Binding (exceedsLimit, inferredTypeLimit)
import Features.Check.Binding as Binding
import Features.Check.Subst
  ( Failure(..)
  , Flex(..)
  , Subst(..)
  , compose
  , empty
  , isEmpty
  , resolve
  , resolveRow
  , substitute
  , walk
  , walkRow
  )
import Features.Check.UnifyRow (unifyRows)

-- Rigid matches only the same rigid; a meta binds to any type that does not
-- properly contain it; applied types unify argument-wise, left to right,
-- then row argument-wise, stopping at the first failure; arrows unify
-- parameter, then row, then result. The recursion is bounded by level (one
-- per applied type, arrow parameter or label argument entered, so a level
-- is a resolved depth; an arrow's result stays at the arrow's level,
-- design §1): metas bound earlier in the same unification can chain into
-- types deeper than either operand was, so past `inferredTypeLimit` it
-- fails with TooDeep instead of recursing further (ruling R7, fix round 2).
-- Rows unify by scoped labels (Features.Check.UnifyRow, FX001).
unify ∷ Subst → Ty Flex → Ty Flex → Either Failure Subst
unify = unifyAt 1

unifyAt ∷ Int → Subst → Ty Flex → Ty Flex → Either Failure Subst
unifyAt level subst left right =
  if level > inferredTypeLimit then Left TooDeep
  else unifyHeads level subst (walk subst left) (walk subst right)

-- Two arrows' spines in step, by a loop: each pair of parameters one level
-- deeper, each pair of rows (their label arguments one level deeper), each
-- pair of results at this level, until one side is no arrow. Only two
-- arrows enter the loop, so an applied type's levels cost the frames they
-- did before (stack headroom after unifying 1,000 levels was unchanged
-- when measured; through the loop for each level, every level of 1,000
-- nested parameters left more headroom than nested lists do).
unifyArrows ∷ Int → Subst → Ty Flex → Ty Flex → Either Failure Subst
unifyArrows level subst left right = tailRec (unifySpines level)
  { subst, left, right }

unifySpines
  ∷ Int
  → { subst ∷ Subst, left ∷ Ty Flex, right ∷ Ty Flex }
  → Step { subst ∷ Subst, left ∷ Ty Flex, right ∷ Ty Flex }
      (Either Failure Subst)
unifySpines level pending =
  case walk pending.subst pending.left, walk pending.subst pending.right of
    TFun first firstRow rest, TFun second secondRow more →
      either (Done <<< Left) (next rest more)
        ( unifyAt (level + 1) pending.subst first second
            >>= unifyRowAt level firstRow secondRow
        )
    left, right → Done (unifyHeads level pending.subst left right)
  where
  next rest more subst = Loop { subst, left: rest, right: more }

-- Both sides are walked, so a meta here is unbound. Of two metas, the
-- newer (larger) is bound to the older, so siblings joined one after
-- another all point at the oldest: binding the older to the newer built a
-- chain as long as the siblings, which every later walk followed (P001
-- final review: 5,000 `Nothing` arms took 15.9 s).
unifyHeads ∷ Int → Subst → Ty Flex → Ty Flex → Either Failure Subst
unifyHeads level subst left right = case left, right of
  TVar (Meta older), TVar (Meta newer) | older < newer →
    Binding.bindType subst newer (TVar (Meta older))
  TVar (Meta meta), _ → Binding.bindType subst meta right
  _, TVar (Meta meta) → Binding.bindType subst meta left
  TVar (Rigid one), TVar (Rigid other) | one == other → Right subst
  TInt, TInt → Right subst
  TBool, TBool → Right subst
  TUnit, TUnit → Right subst
  TData one lefts leftRows, TData other rights rightRows
    | one == other && sameLength lefts rights
        && sameLength leftRows rightRows →
        foldM unifyPair subst (Array.zip lefts rights)
          >>= unifyRowsAt level leftRows rightRows
  THandler (Label one lefts) leftRow, THandler (Label other rights) rightRow
    | one == other && sameLength lefts rights →
        foldM unifyPair subst (Array.zip lefts rights)
          >>= unifyRowAt level leftRow rightRow
  TFun _ _ _, TFun _ _ _ → unifyArrows level subst left right
  _, _ → mismatch subst left right
  where
  -- Arguments pairwise, one level deeper, left to right. Folded here,
  -- not in a helper: each level of a deeply applied type then costs the
  -- frames it did before rows (a helper's one more frame per level
  -- overflowed test/unify-arrow at 1,000 levels).
  unifyPair reached (Tuple leftArgument rightArgument) =
    unifyAt (level + 1) reached leftArgument rightArgument

-- Two rows at this level: their label arguments one level deeper.
unifyRowAt
  ∷ Int → TyRow Flex → TyRow Flex → Subst → Either Failure Subst
unifyRowAt level left right subst = unifyRows (unifyAt (level + 1)) subst
  left
  right

unifyRowsAt
  ∷ Int
  → Array (TyRow Flex)
  → Array (TyRow Flex)
  → Subst
  → Either Failure Subst
unifyRowsAt level lefts rights subst = foldM unifyPair subst
  (Array.zip lefts rights)
  where
  unifyPair reached (Tuple left right) = unifyRowAt level left right reached

sameLength ∷ ∀ a b. Array a → Array b → Boolean
sameLength one other = Array.length one == Array.length other

-- The differing pair is resolved for the message only when that is safe.
mismatch ∷ Subst → Ty Flex → Ty Flex → Either Failure Subst
mismatch subst left right =
  if exceedsLimit subst left || exceedsLimit subst right then Left TooDeep
  else Left (Mismatch (resolve subst left) (resolve subst right))
