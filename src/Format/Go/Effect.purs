-- Effect layouts and handler values (FX001 design §4). A layout is a Go
-- struct of the handler's clauses, one function field per operation, and
-- per operation a perform function that finds the innermost frame with the
-- effect's key, asserts that frame's handler to this layout (unreachable
-- when well typed, by the first-occurrence rule) and calls the clause with
-- the frame's `outer` context, so a clause never sees its own handler.
-- Each clause of a `handler` expression is lifted, as a lambda is, to a
-- top-level function of its free locals and parameters; the struct holds
-- it directly, or a closure over the free locals. The k-th lifted
-- function, numbered in pre-order with the clause before its body and
-- sharing the counter with matches and blocks, is waxwingFn{f}Lambda{k}.
module Format.Go.Effect (effectDeclarations, lowerHandlerValue) where

import Prelude
import Data.Array as Array
import Data.String.Common (joinWith)
import Data.Traversable (mapAccumL)
import Domain.IR.Internal as IR
import Domain.IR.Internal (EffectKey(..))
import Format.Go.Capture (Free, lambdaFree, union)
import Format.Go.Context (effectKey, parameterList)
import Format.Go.Data (effectName, functionName, goType, localName, performName)
import Format.Go.Lambda (liftedFunction)
import Format.Go.Lowered (Lowered, Lowering, Scope, Wrapper)

effectDeclarations ∷ Array IR.EffectInfo → String
effectDeclarations effects = joinWith "" (Array.mapWithIndex declared effects)
  where
  declared index info = structDeclaration key info
    <> joinWith "" (Array.mapWithIndex (perform key info) info.operations)
    where
    key = EffectKey index

structDeclaration ∷ EffectKey → IR.EffectInfo → String
structDeclaration key info = "type " <> effectName key <> " struct {\n"
  <> joinWith "" (Array.mapWithIndex field info.operations)
  <> "}\n\n"
  where
  field position operation = fieldName position <> " func("
    <> joinWith ", " ([ "*waxwingCtx" ] <> map goType operation.parameters)
    <> ") "
    <> goType operation.result
    <> "\n"

perform ∷ EffectKey → IR.EffectInfo → Int → IR.OperationInfo → String
perform key info position operation =
  "func " <> performName key position <> "("
    <> parameterList true (Array.mapWithIndex parameter operation.parameters)
    <> ") "
    <> goType operation.result
    <> " {\nframe := waxwingFind(ctx, "
    <> show (effectKey info.effect)
    <> ", \""
    <> info.name
    <> "\")\nreturn frame.handler.(*"
    <> effectName key
    <> ")."
    <> fieldName position
    <> "("
    <> joinWith ", "
      ([ "frame.outer" ] <> Array.mapWithIndex argument operation.parameters)
    <> ")\n}\n\n"
  where
  parameter index ty = argumentName index <> " " <> goType ty
  argument index _ = argumentName index

fieldName ∷ Int → String
fieldName position = "op" <> show position

argumentName ∷ Int → String
argumentName index = "waxwingArg" <> show index

-- What lowering one clause adds besides its place in the struct literal.
type Clause =
  { field ∷ String
  , lifted ∷ Array String
  , free ∷ Free
  , wrappers ∷ Array Wrapper
  }

lowerHandlerValue
  ∷ Scope → Lowering → Int → EffectKey → Array IR.Clause → Lowered
lowerHandlerValue scope lower next key clauses =
  { code: "&" <> effectName key <> "{"
      <> joinWith ", " (map fieldOf threaded.value)
      <> "}"
  , next: threaded.accum
  , lifted: Array.concatMap liftedOf threaded.value
  , free: union (map freeOf threaded.value)
  , wrappers: Array.concatMap wrappersOf threaded.value
  }
  where
  threaded = mapAccumL (clause scope lower) next clauses
  fieldOf found = found.field
  liftedOf found = found.lifted
  freeOf found = found.free
  wrappersOf found = found.wrappers

clause
  ∷ Scope → Lowering → Int → IR.Clause → { accum ∷ Int, value ∷ Clause }
clause scope lower number found =
  { accum: inner.next
  , value:
      { field: fieldName found.operation <> ": " <> value
      , lifted: [ lifted ] <> inner.lifted
      , free: captured
      , wrappers: inner.wrappers
      }
  }
  where
  inner = lower (number + 1) found.body
  captured = lambdaFree found.parameters inner.free
  name = functionName scope.owner <> "Lambda" <> show number
  result = IR.typeOf found.body
  lifted = liftedFunction true name captured found.parameters result inner.code
  value
    | Array.null captured = name
    | otherwise = closure name captured found.parameters result

-- The struct's field takes the clause's parameters alone, so the free
-- locals are closed over where the handler is built.
closure ∷ String → Free → Array IR.Param → IR.Ty → String
closure name captured parameters result =
  "func(" <> parameterList true (Array.mapWithIndex parameter parameters)
    <> ") "
    <> goType result
    <> " { return "
    <> name
    <> "("
    <> joinWith ", "
      ( [ "ctx" ] <> map capturedName captured
          <> Array.mapWithIndex argument parameters
      )
    <> ") }"
  where
  parameter index found = argumentName index <> " " <> goType found.ty
  argument index _ = argumentName index
  capturedName local = localName local.id
