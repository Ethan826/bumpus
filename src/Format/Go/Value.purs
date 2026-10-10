-- Named callees and values (FN001 design §4, §7, §13 rules 1, 3, 6). A
-- saturated call or construction is today's n-ary Go call (rule 1). A
-- partial one applies the staged wrapper's first stage to its arguments,
-- left to right, so they are evaluated now and once (rule 6). A bare
-- reference of arity 1 is the Go function itself; of arity n ≥ 2, its
-- wrapper's first stage. Over-application and any other application are
-- the value applied in a chain (Format.Go.Apply).
module Format.Go.Value (named, reference, applyValue) where

import Prelude
import Data.Array as Array
import Data.String.Common (joinWith)
import Domain.IR.Internal as IR
import Format.Go.Apply (applied, walked)
import Format.Go.Capture (none, union)
import Format.Go.Context (passed)
import Format.Go.Lowered (Lowered, Lowering, Scope, Wrapper, several)
import Format.Go.Stage (stageTypes, valueName)
import Format.Go.Data (goType)

-- `Call` or `Construct` of `wrapper`'s function with `arguments`, of type
-- `ty`.
named
  ∷ Scope → Lowering → Int → Wrapper → IR.Expr → Array IR.Expr → Lowered
named scope lower next wrapper expression arguments =
  if Array.length arguments < Array.length wrapper.parameters then
    applied scope lower { head: staged next wrapper, types } arguments
  else call (several lower next arguments)
  where
  call parts =
    { code: wrapper.name <> "("
        <> joinWith ", " (passed scope.shape.context parts.codes)
        <> ")"
    , next: parts.next
    , lifted: parts.lifted
    , free: union parts.frees
    , wrappers: parts.wrappers
    }
  ty = IR.typeOf expression
  types _ =
    stageTypes scope.shape wrapper.name
      (Array.take (Array.length arguments) wrapper.parameters)
      ty
      <> [ goType ty ]

reference ∷ Int → Wrapper → Lowered
reference next wrapper
  | Array.length wrapper.parameters <= 1 =
      { code: wrapper.name, next, lifted: [], free: none, wrappers: [] }
  | otherwise = staged next wrapper

-- `h(a1…aj)` for any value `h`, over-application's saturated call
-- included: the types come from `h`'s interned arrow.
applyValue ∷ Scope → Lowering → Int → IR.Expr → Array IR.Expr → Lowered
applyValue scope lower next callee arguments =
  applied scope lower { head: lower next callee, types } arguments
  where
  types _ = walked scope.shape.funTypes (IR.typeOf callee)
    (Array.length arguments)

staged ∷ Int → Wrapper → Lowered
staged next wrapper =
  { code: valueName wrapper
  , next
  , lifted: []
  , free: none
  , wrappers: [ wrapper ]
  }
