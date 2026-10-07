module Format.Go.Compare (goOperator, isOrdering, boolHelper, comparison) where

import Prelude
import Domain.IR.Internal as IR
import Domain.Resolved (Ty(..))
import Domain.Syntax (Operator(..))

goOperator ∷ Operator → String
goOperator = case _ of
  Equal → "=="
  NotEqual → "!="
  Less → "<"
  LessEqual → "<="
  Greater → ">"
  GreaterEqual → ">="

isOrdering ∷ Operator → Boolean
isOrdering = case _ of
  Equal → false
  NotEqual → false
  _ → true

-- Go has no ordering on bool; false < true is expressed through -1, 0, 1.
boolHelper ∷ String
boolHelper =
  "func sprigCmpBool(a bool, b bool) int { "
    <> "if a == b { return 0 }; if b { return -1 }; return 1 }\n\n"

-- Go evaluates call operands left to right, so both forms keep that order.
comparison
  ∷ (IR.Expr → String) → Operator → IR.Expr → IR.Expr → String
comparison lower operator left right =
  if isOrdering operator && IR.typeOf left == TBool then
    "(sprigCmpBool(" <> lower left <> ", " <> lower right <> ") " <> symbol
      <> " 0)"
  else "(" <> lower left <> " " <> symbol <> " " <> lower right <> ")"
  where
  symbol = goOperator operator
