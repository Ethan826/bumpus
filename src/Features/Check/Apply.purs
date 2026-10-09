module Features.Check.Apply
  ( checkApply
  , applyAll
  , applyValue
  , functionLike
  ) where

import Prelude
import Data.Either (Either(..))
import Domain.Checked.Internal (Open(..))
import Domain.Checked.Internal as Checked
import Domain.Problem (Problem(..))
import Domain.Resolved as Resolved
import Domain.Syntax (Diagnostic, Span, problemAt)
import Domain.Row (openRow)
import Features.Check.Consume (consumeAt)
import Domain.Type (Ty(..), TyRow)
import Features.Check.Context (CheckEnv, Infer)
import Features.Check.Require (expectType, require, typeName)
import Features.Check.Scheme (State, Threaded, headOf, resolved, threadAll)

-- An application in progress: the checking state and the type still to
-- be applied.
type Applying = { ty ∷ Ty Open, state ∷ State }

-- A function type opened for one argument.
type Opened =
  { parameter ∷ Ty Open, result ∷ Ty Open, row ∷ TyRow Open }

-- FN001 design §3: `e(a1, …, aj)` is `e(a1)…(aj)`. The callee first.
checkApply
  ∷ ∀ r
  . Infer r
  → CheckEnv r
  → State
  → Span
  → Resolved.Expr
  → Array Resolved.Expr
  → Either Diagnostic (Threaded Checked.Expr)
checkApply infer env state span callee arguments = do
  head ← infer env state callee
  applyAll infer env span head arguments

-- A checked callee applied to each argument in turn, the type threaded
-- with the state (Scheme's `threadAll`, so no frame or copy per argument),
-- as one `Apply` spanning `span`.
applyAll
  ∷ ∀ r
  . Infer r
  → CheckEnv r
  → Span
  → Threaded Checked.Expr
  → Array Resolved.Expr
  → Either Diagnostic (Threaded Checked.Expr)
applyAll infer env span callee arguments = do
  applied ← threadAll (applyNext infer env) start arguments
  pure
    { value: Checked.Expr
        { ty: applied.state.ty
        , span
        , node: Checked.Apply callee.value applied.value
        }
    , state: applied.state.state
    }
  where
  start = { ty: Checked.typeOf callee.value, state: callee.state }

-- The current type is opened before its argument is inferred, so a value
-- that is not a function is reported at the first argument it cannot take.
applyNext
  ∷ ∀ r
  . Infer r
  → CheckEnv r
  → Applying
  → Resolved.Expr
  → Either Diagnostic { value ∷ Checked.Expr, state ∷ Applying }
applyNext infer env applying argument = do
  opened ← open env applying.state applying.ty (Resolved.exprSpan argument)
  checked ← infer env opened.state argument
  reached ← require env checked.state opened.value.parameter checked.value
  consumed ← consumeAt env reached (Resolved.exprSpan argument) opened.value.row
  pure
    { value: checked.value
    , state: { ty: opened.value.result, state: consumed }
    }

-- A value of type `ty` applied to an argument already checked: a pipe's
-- left operand. Returns the result type.
applyValue
  ∷ ∀ r
  . CheckEnv r
  → State
  → Ty Open
  → Checked.Expr
  → Either Diagnostic (Threaded (Ty Open))
applyValue env state ty argument = do
  opened ← open env state ty (Checked.spanOf argument)
  reached ← require env opened.state opened.value.parameter argument
  consumed ← consumeAt env reached (Checked.spanOf argument) opened.value.row
  pure { value: opened.value.result, state: consumed }

-- Whether `ty` may still be applied: an arrow, or a meta not yet bound.
functionLike ∷ State → Ty Open → Boolean
functionLike state ty = case headOf state ty of
  TFun _ _ _ → true
  TVar (Hole _) → true
  _ → false

-- An arrow opens as its parameter and result; an unbound meta is first
-- bound to a pure arrow of two fresh metas (no syntax writes a row yet);
-- anything else (Int, Bool, a declared type, a rigid variable) is not a
-- function, at `span`.
open
  ∷ ∀ r
  . CheckEnv r
  → State
  → Ty Open
  → Span
  → Either Diagnostic (Threaded Opened)
open env state ty span = case headOf state ty of
  TFun parameter row result → Right { value: { parameter, result, row }, state }
  meta@(TVar (Hole _)) → bindArrow env state meta span
  other → notAFunction env state other span

bindArrow
  ∷ ∀ r
  . CheckEnv r
  → State
  → Ty Open
  → Span
  → Either Diagnostic (Threaded Opened)
bindArrow env state meta span = do
  reached ← expectType env fresh meta (TFun parameter row result) span
  pure { value: { parameter, result, row }, state: reached }
  where
  parameter = TVar (Hole state.next)
  result = TVar (Hole (state.next + 1))
  row = openRow (Hole (state.next + 2))
  fresh = state { next = state.next + 2 + 1 }

notAFunction
  ∷ ∀ r a. CheckEnv r → State → Ty Open → Span → Either Diagnostic a
notAFunction env state ty span = do
  name ← typeName env span (resolved state.subst ty)
  Left (problemAt (NotAFunction name) span)
