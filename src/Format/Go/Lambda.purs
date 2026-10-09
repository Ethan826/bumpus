-- Lambdas (FN001 design §5, §13 rule 5). Each lambda is lifted, as a
-- match is (E005), to a top-level n-ary function of its free locals
-- (ascending LocalId, Format.Go.Capture) followed by its parameters; its
-- value is that function's staged wrapper applied to the free locals when
-- the lambda is evaluated, so its body runs exactly when its last
-- parameter is applied. With no free local and one parameter the value is
-- the lifted function itself. The k-th lifted function of waxwingFn{f},
-- numbered in pre-order with the lambda before its body, is
-- waxwingFn{f}Lambda{k}; a discarded parameter is Go's `_`.
module Format.Go.Lambda (lowerLambda) where

import Prelude
import Data.Array as Array
import Data.Maybe (maybe)
import Data.String.Common (joinWith)
import Domain.IR.Internal as IR
import Domain.IR.Internal (Ty)
import Format.Go.Apply (applied)
import Format.Go.Capture (Captured, Free, lambdaFree, none)
import Format.Go.Data (functionName, goType, localName)
import Format.Go.Lowered (Lowered, Lowering, Scope, Wrapper)
import Format.Go.Stage (stageTypes, valueName)

lowerLambda
  ∷ Scope → Lowering → Int → IR.Expr → Array IR.Param → IR.Expr → Lowered
lowerLambda scope lower next lambda parameters body =
  if Array.null captured && Array.length parameters == 1 then
    head { code = name, wrappers = inner.wrappers }
  else applied scope lower { head, types } (map local captured)
  where
  inner = lower (next + 1) body
  captured = lambdaFree parameters inner.free
  name = functionName scope.owner <> "Lambda" <> show next
  lifted = liftedFunction name captured parameters body inner.code
  wrapper = wrapperOf name captured parameters (IR.typeOf body)
  head =
    { code: valueName wrapper
    , next: inner.next
    , lifted: [ lifted ] <> inner.lifted
    , free: none
    , wrappers: [ wrapper ] <> inner.wrappers
    }
  ty = IR.typeOf lambda
  types _ = stageTypes scope.shape name (map capturedType captured) ty
    <> [ goType ty ]
  local found = IR.Expr
    { ty: found.ty, span: IR.spanOf lambda, node: IR.Local found.id }

wrapperOf ∷ String → Free → Array IR.Param → Ty → Wrapper
wrapperOf name captured parameters result =
  { name
  , parameters: map capturedType captured <> map parameterType parameters
  , result
  }
  where
  parameterType parameter = parameter.ty

liftedFunction
  ∷ String → Free → Array IR.Param → IR.Expr → String → String
liftedFunction name captured parameters body code =
  "func " <> name <> "("
    <> joinWith ", "
      (map capturedParameter captured <> map parameter parameters)
    <> ") "
    <> goType (IR.typeOf body)
    <> " {\nreturn "
    <> code
    <> "\n}\n"
  where
  capturedParameter local = localName local.id <> " " <> goType local.ty
  parameter found = maybe "_" localName found.local <> " " <> goType found.ty

capturedType ∷ Captured → Ty
capturedType local = local.ty
