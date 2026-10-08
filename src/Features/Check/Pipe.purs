module Features.Check.Pipe (checkPipe) where

import Prelude
import Data.Either (Either(..))
import Data.Maybe (isJust, maybe)
import Domain.Checked.Internal as Checked
import Domain.Problem (Problem(..))
import Domain.Resolved as Resolved
import Domain.Syntax (Diagnostic, Span, problemAt)
import Features.Check.Apply (applyValue, functionLike)
import Features.Check.Call (fixedResult, saturatedResult)
import Features.Check.Context (CheckEnv, Infer)
import Features.Check.Scheme (State, Threaded)

-- FN001 design §5: `a |> e` applies `e` to `a`, the left operand checked
-- first. A named call `g(b1…bk)` on the right makes this `g(b1…bk, a)`, so
-- with k = n it is an over-application, E_ARITY at that call unless g's
-- result is a function (design §4): as for the call, a declared result
-- that can never be one is reported before b1…bk are checked, an
-- instantiated one after (Task 4 review). Anything else on the right is a
-- value applied to `a`, reported at `a` if it does not take it.
checkPipe
  ∷ ∀ r
  . Infer r
  → CheckEnv r
  → State
  → Span
  → Resolved.Expr
  → Resolved.Expr
  → Either Diagnostic (Threaded Checked.Expr)
checkPipe infer env state span left right = do
  value ← infer env state left
  when (maybe false fixedResult saturated) arity
  callee ← infer env value.state right
  let calleeType = Checked.typeOf callee.value
  when (isJust saturated && not (functionLike callee.state calleeType)) arity
  applied ← applyValue env callee.state calleeType value.value
  pure
    { value: Checked.Expr
        { ty: applied.value
        , span
        , node: Checked.Pipe value.value callee.value
        }
    , state: applied.state
    }
  where
  saturated = saturatedResult env right
  arity = Left (problemAt Arity (Resolved.exprSpan right))
