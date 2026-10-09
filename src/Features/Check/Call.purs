module Features.Check.Call
  ( checkCall
  , checkConstruct
  , saturatedResult
  , named
  , fixedResult
  ) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Domain.Checked.Internal as Checked
import Domain.Problem (Problem(..))
import Domain.Resolved (CtorId(..), FunctionId(..), Ty(..), VarId)
import Domain.Resolved as Resolved
import Domain.Syntax (Diagnostic, Span, problemAt)
import Features.Check.Stages (arrowType)
import Features.Check.Consume (consumeAt)
import Features.Check.Apply (applyAll, functionLike)
import Features.Check.Context (CheckEnv, Infer)
import Features.Check.Require (require)
import Features.Check.Scheme (State, Threaded, threadAll)
import Features.Check.Use (Use, ctorUse, functionUse)

type Checked = Either Diagnostic (Threaded Checked.Expr)

-- How a named callee's checked node is built from its instantiation and
-- arguments.
type Node = Checked.Instantiation → Array Checked.Expr → Checked.Node

-- Each use instantiates the callee's variables afresh.
checkCall
  ∷ ∀ r
  . Infer r
  → CheckEnv r
  → State
  → Span
  → FunctionId
  → Array Resolved.Expr
  → Checked
checkCall infer env state span id arguments = do
  use ← functionUse env state span id
  named infer env span (Checked.Call id) use arguments

checkConstruct
  ∷ ∀ r
  . Infer r
  → CheckEnv r
  → State
  → Span
  → CtorId
  → Array Resolved.Expr
  → Checked
checkConstruct infer env state span id arguments = do
  use ← ctorUse env state span id
  named infer env span (Checked.Construct id) use arguments

-- The declared result of a resolved named call or construction written
-- with exactly its declared count of arguments (a bare nullary
-- constructor is a value, not a call); only its head is meaningful.
saturatedResult ∷ ∀ r. CheckEnv r → Resolved.Expr → Maybe (Ty VarId)
saturatedResult env = case _ of
  Resolved.Call _ (FunctionId index) arguments →
    Array.index env.functions index >>= function arguments
  Resolved.Construct _ (CtorId index) arguments
    | not (Array.null arguments) →
        Array.index env.ctors index >>= ctor arguments
  _ → Nothing
  where
  function arguments declared = counted arguments
    (Array.length declared.parameters)
    declared.result
  ctor arguments info = counted arguments (Array.length info.fields)
    (TData info.owner [] [])
  counted arguments count result =
    if Array.length arguments == count then Just result else Nothing

-- A declared result that can never be a function: Int, Bool or a declared
-- type, whatever the instantiation.
fixedResult ∷ Ty VarId → Boolean
fixedResult = case _ of
  TFun _ _ _ → false
  TVar _ → false
  _ → true

-- FN001 design §4: the declared arity n decides. With n arguments, or
-- 0 < j < n, the arguments meet the fields (`supplied`); none for a callee
-- with parameters is today's E_ARITY, checked before any argument; more
-- than n is an over-application.
named
  ∷ ∀ r
  . Infer r
  → CheckEnv r
  → Span
  → Node
  → Threaded Use
  → Array Resolved.Expr
  → Checked
named infer env span node use arguments =
  if count > arity then overApplied infer env span node use arguments
  else if count == 0 && arity > 0 then arityAt span
  else supplied infer env span node use arguments
  where
  arity = Array.length use.value.fields
  count = Array.length arguments

-- `f(a1…an)` runs, then its result is applied to the rest (design §3).
-- A declared result that can never be a function is E_ARITY before any
-- argument, as every wrong count was before FN001; so is an instantiated
-- result that turns out not to be one once the n arguments are checked.
overApplied
  ∷ ∀ r
  . Infer r
  → CheckEnv r
  → Span
  → Node
  → Threaded Use
  → Array Resolved.Expr
  → Checked
overApplied infer env span node use arguments = do
  unless (functionLike use.state use.value.result) (arityAt span)
  called ← supplied infer env span node use (Array.take arity arguments)
  unless (functionLike called.state (Checked.typeOf called.value))
    (arityAt span)
  applyAll infer env span called (Array.drop arity arguments)
  where
  arity = Array.length use.value.fields

-- Every argument is inferred, then each is unified with its field, left to
-- right. Fewer arguments than fields is a partial application, typed as
-- the arrow of the remaining fields to the result; a saturated call drops
-- none and builds no arrow.
supplied
  ∷ ∀ r
  . Infer r
  → CheckEnv r
  → Span
  → Node
  → Threaded Use
  → Array Resolved.Expr
  → Checked
supplied infer env span node use arguments = do
  checked ← threadAll (infer env) use.state arguments
  unified ← threadAll checkArgument checked.state
    (Array.zipWith argumentPair use.value.fields checked.value)
  consumed ←
    if count == Array.length use.value.fields then
      consumeAt env unified.state span use.value.row
    else pure unified.state
  pure
    { value: Checked.Expr
        { ty: resultType
        , span
        , node: node use.value.scheme.arguments checked.value
        }
    , state: consumed
    }
  where
  count = Array.length arguments
  -- A saturated call (every call before FN001) builds no arrow.
  resultType
    | count == Array.length use.value.fields = use.value.result
    | otherwise = arrowType (Array.drop count use.value.fields)
        (Array.drop count use.value.rows)
        use.value.result
  argumentPair ty actual = { ty, actual }
  checkArgument reached pair = threadedUnit <$> require env reached pair.ty
    pair.actual
  threadedUnit reached = { value: unit, state: reached }

arityAt ∷ ∀ a. Span → Either Diagnostic a
arityAt span = Left (problemAt Arity span)
