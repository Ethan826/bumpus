module Format.Go.Usage (needsBoolHelper) where

import Prelude
import Data.Array as Array
import Domain.IR.Internal as IR
import Domain.Resolved (Ty(..))
import Format.Go.Compare (isBoolOrdering)

-- Helpers are emitted only when some expression needs them, so programs
-- without such comparisons keep their previous output byte for byte. A Bool
-- field makes the declared type's compare helper call bumpusCmpBool.
needsBoolHelper ∷ IR.Program → Boolean
needsBoolHelper (IR.Program program) =
  Array.any hasBoolField program.ctors
    || Array.any inFunction program.functions
  where
  hasBoolField ctor = Array.elem TBool ctor.fields
  inFunction function = usesBoolOrdering function.body

usesBoolOrdering ∷ IR.Expr → Boolean
usesBoolOrdering (IR.Expr expression) = case expression.node of
  IR.Integer _ → false
  IR.Boolean _ → false
  IR.Local _ → false
  IR.Call _ arguments → anyOf arguments
  IR.Construct _ arguments → anyOf arguments
  IR.Add left right → anyOf [ left, right ]
  IR.Compare operator left right →
    isBoolOrdering operator left || anyOf [ left, right ]
  IR.If condition yes no → anyOf [ condition, yes, no ]
  IR.Match scrutinee arms → usesBoolOrdering scrutinee
    || Array.any armUses arms
  where
  anyOf = Array.any usesBoolOrdering
  armUses arm = usesBoolOrdering arm.body
