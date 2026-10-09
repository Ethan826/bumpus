module Features.Specialize.Unlowered (reject) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (Maybe(..), maybe')
import Domain.IR.Internal as IR
import Domain.Problem (Problem(..))
import Domain.Syntax (Diagnostic, Span, problemAt)

-- The phase boundary of FX001 Task 6 (plan, "Phase boundaries"): Go
-- lowering of handlers, operations and failures is Task 7's. Until then a
-- program whose monomorphic IR has an effect layout (every handler type,
-- handler value and operation has one) or a `with`, `handle` or `fail`
-- stops here; `print` runs end to end. Declared effects nothing uses
-- leave no trace in the IR and reach Go unchanged.
reject ∷ IR.Program → Either Diagnostic Unit
reject (IR.Program program) = maybe' clean unlowered
  (Array.head (map layoutSpan program.effects <> bodies))
  where
  bodies = Array.mapMaybe body program.functions
  body definition = firstEffect definition.body
  layoutSpan info = info.span
  clean _ = Right unit
  unlowered span = Left (problemAt (Internal "unlowered effect") span)

-- In pre-order; the nesting limits bound the depth.
firstEffect ∷ IR.Expr → Maybe Span
firstEffect (IR.Expr expression) = case expression.node of
  IR.OperationRef _ _ → Just expression.span
  IR.Perform _ _ _ → Just expression.span
  IR.HandlerValue _ _ → Just expression.span
  IR.Install _ _ → Just expression.span
  IR.Handle _ _ → Just expression.span
  IR.Abort _ _ → Just expression.span
  node → Array.head (Array.mapMaybe firstEffect (children node))

children ∷ IR.Node → Array IR.Expr
children = case _ of
  IR.Call _ arguments → arguments
  IR.Construct _ arguments → arguments
  IR.Add left right → [ left, right ]
  IR.Compare _ left right → [ left, right ]
  IR.If condition yes no → [ condition, yes, no ]
  IR.Match scrutinee arms → Array.cons scrutinee (map armBody arms)
  IR.Apply applied arguments → Array.cons applied arguments
  IR.Lambda _ body → [ body ]
  IR.Pipe left right → [ left, right ]
  IR.Print value → [ value ]
  IR.Block items value → IR.blockParts items value
  _ → []
  where
  armBody arm = arm.body
