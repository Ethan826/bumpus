module Format.Go.Usage (needsBoolHelper, needsPrint) where

import Prelude
import Data.Array as Array
import Domain.IR.Internal as IR
import Domain.IR.Internal (Ty(..))
import Format.Go.Compare (isBoolOrdering)

-- Helpers are emitted only when some expression needs them, so programs
-- without such comparisons keep their previous output byte for byte. A Bool
-- field makes the declared type's compare helper call waxwingCmpBool.
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
  IR.FunctionRef _ → false
  IR.CtorRef _ → false
  IR.Apply applied arguments → anyOf (Array.cons applied arguments)
  IR.Lambda _ body → usesBoolOrdering body
  IR.Pipe left right → anyOf [ left, right ]
  IR.UnitValue → false
  IR.Print value → usesBoolOrdering value
  IR.Block items value → anyOf (IR.blockParts items value)
  IR.OperationRef _ _ → false
  IR.Perform _ _ _ → effects
  IR.HandlerValue _ _ → effects
  IR.Install _ _ → effects
  IR.Handle _ _ → effects
  IR.Abort _ _ → effects
  where
  anyOf = Array.any usesBoolOrdering
  effects = anyOf (IR.effectParts expression.node)
  armUses arm = usesBoolOrdering arm.body

needsPrint ∷ IR.Program → Boolean
needsPrint (IR.Program program) = Array.any inFunction program.functions
  where
  inFunction function = prints function.body

prints ∷ IR.Expr → Boolean
prints (IR.Expr expression) = case expression.node of
  IR.Print _ → true
  IR.Integer _ → false
  IR.Boolean _ → false
  IR.Local _ → false
  IR.FunctionRef _ → false
  IR.CtorRef _ → false
  IR.UnitValue → false
  IR.Call _ arguments → anyOf arguments
  IR.Construct _ arguments → anyOf arguments
  IR.Add left right → anyOf [ left, right ]
  IR.Compare _ left right → anyOf [ left, right ]
  IR.If condition yes no → anyOf [ condition, yes, no ]
  IR.Match scrutinee arms → prints scrutinee || Array.any armPrints arms
  IR.Apply callee arguments → anyOf (Array.cons callee arguments)
  IR.Lambda _ body → prints body
  IR.Pipe left right → anyOf [ left, right ]
  IR.Block items value → anyOf (IR.blockParts items value)
  IR.OperationRef _ _ → false
  IR.Perform _ _ _ → effects
  IR.HandlerValue _ _ → effects
  IR.Install _ _ → effects
  IR.Handle _ _ → effects
  IR.Abort _ _ → effects
  where
  anyOf = Array.any prints
  effects = anyOf (IR.effectParts expression.node)
  armPrints arm = prints arm.body
