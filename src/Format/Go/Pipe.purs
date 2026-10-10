-- Pipes (FN001 design §5, §13 rule 7). `a |> e` evaluates `a` first, then
-- `e`, then applies; with `e = g(b1…bk)` it is `g(b1…bk, a)` with that
-- call's stage boundaries, so the left operand joins the application as
-- its last argument (a saturated call stays a direct Go call). A literal
-- or a local is that argument itself: evaluating it has no effect. Any
-- other left operand is held in a temporary: the pipe is lifted, as a
-- match is (E005), to waxwingFn{f}Pipe{k}, taking the free locals of the
-- application and then the operand's value, `waxwingPipe`. The call site
-- evaluates only locals before the operand, so the operand runs first; no
-- closure is nested, however long a chain of pipes is.
module Format.Go.Pipe (lowerPipe) where

import Prelude
import Data.Array as Array
import Data.String.Common (joinWith)
import Domain.IR.Internal as IR
import Format.Go.Capture (union, without)
import Format.Go.Context (declared, passed)
import Format.Go.Data (functionName, goType, localName, pipeLocal)
import Format.Go.Lowered
  ( Lowered
  , Lowering
  , Scope
  , ctorWrapper
  , functionWrapper
  )

lowerPipe ∷ Scope → Lowering → Int → IR.Expr → IR.Expr → IR.Expr → Lowered
lowerPipe scope lower next pipe left right =
  if effectless left then lower next (spliced scope pipe right left)
  else held scope lower next pipe left right

-- Where-bindings are strict, so the temporary's lowering is its own
-- declaration: the effectless case never lowers the right side twice.
held ∷ Scope → Lowering → Int → IR.Expr → IR.Expr → IR.Expr → Lowered
held scope lower next pipe left right =
  { code: name <> "("
      <> joinWith ", "
        (passed context (map capturedName captured <> [ operand.code ]))
      <> ")"
  , next: application.next
  , lifted: [ lifted ] <> operand.lifted <> application.lifted
  , free: union [ captured, operand.free ]
  , wrappers: operand.wrappers <> application.wrappers
  }
  where
  context = scope.shape.context
  name = functionName scope.owner <> "Pipe" <> show next
  operand = lower (next + 1) left
  temporary = IR.Expr
    { ty: IR.typeOf left, span: IR.spanOf left, node: IR.Local pipeLocal }
  application = lower operand.next (spliced scope pipe right temporary)
  captured = without pipeLocal application.free
  capturedName local = localName local.id
  parameter local = localName local.id <> " " <> goType local.ty
  lifted = "func " <> name <> "("
    <> joinWith ", "
      ( declared context
          ( map parameter captured
              <> [ localName pipeLocal <> " " <> operandType ]
          )
      )
    <> ") "
    <> goType (IR.typeOf pipe)
    <> " {\nreturn "
    <> application.code
    <> "\n}\n"
  operandType = goType (IR.typeOf left)

effectless ∷ IR.Expr → Boolean
effectless (IR.Expr expression) = case expression.node of
  IR.Integer _ → true
  IR.Boolean _ → true
  IR.Local _ → true
  _ → false

-- `right` applied to `argument`, as one application node of the pipe's
-- type and span: a partial call or construction takes it as its next
-- argument, a bare reference as its first, an application as its last.
spliced ∷ Scope → IR.Expr → IR.Expr → IR.Expr → IR.Expr
spliced scope (IR.Expr pipe) (IR.Expr right) argument =
  IR.Expr { ty: pipe.ty, span: pipe.span, node }
  where
  node = case right.node of
    IR.Call id arguments
      | partial arguments (functionWrapper scope.shape id).parameters →
          IR.Call id (Array.snoc arguments argument)
    IR.Construct id arguments
      | partial arguments (ctorWrapper scope.shape id).parameters →
          IR.Construct id (Array.snoc arguments argument)
    IR.FunctionRef id → IR.Call id [ argument ]
    IR.CtorRef id → IR.Construct id [ argument ]
    IR.Apply callee arguments → IR.Apply callee (Array.snoc arguments argument)
    _ → IR.Apply (IR.Expr right) [ argument ]
  partial arguments parameters =
    Array.length arguments < Array.length parameters
