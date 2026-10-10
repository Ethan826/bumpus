module Features.Check.Lambda (checkLambda) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (maybe')
import Domain.Checked.Internal (Open(..))
import Domain.Checked.Internal as Checked
import Domain.Resolved as Resolved
import Domain.Syntax (Diagnostic, Span)
import Domain.Type (Ty(..), TyRow, substitute)
import Domain.Row (openRow)
import Features.Check.Stages (arrowType, stages)
import Features.Check.Context (CheckEnv, Infer, Locals, bindAll)
import Features.Check.Match (Typed)
import Features.Check.Scheme (State, Threaded, threadAll)

type LambdaEnv r = CheckEnv (locals ∷ Locals | r)

-- FN001 design §3: each parameter has its annotation, whose variables are
-- the enclosing signature's and rigid, or a fresh meta; the body is
-- inferred with the named parameters in scope; `fn(x, y) => e` has type
-- `X -> Y -> E`. Lambdas are monomorphic: nothing is generalized.
checkLambda
  ∷ ∀ r
  . Infer (locals ∷ Locals | r)
  → LambdaEnv r
  → State
  → Span
  → Array Resolved.Param
  → Resolved.Expr
  → Either Diagnostic (Threaded Checked.Expr)
checkLambda infer env state span parameters body = do
  let row = openRow (Hole state.next)
  typed ← threadAll (parameterType env.variables row)
    (state { next = state.next + 1 })
    parameters
  let
    staged = stages typed.state
      (Array.length typed.value)
      row
  checked ← infer
    ( env
        { locals = bindAll (bound typed.value) env.locals
        , current = row
        , sites = []
        }
    )
    staged.state
    body
  pure
    { value: Checked.Expr
        { ty: arrowType (map typeOf typed.value) staged.value
            (Checked.typeOf checked.value)
        , span
        , node: Checked.Lambda typed.value checked.value
        }
    , state: checked.state
    }
  where
  typeOf parameter = parameter.ty

parameterType
  ∷ Array String
  → TyRow Open
  → State
  → Resolved.Param
  → Either Diagnostic (Threaded Checked.Param)
parameterType variables row state parameter = Right
  (maybe' fresh annotated parameter.ty)
  where
  annotated ty =
    { value:
        { local: parameter.local
        , ty: substitute { types: rigidType, rows: annotationRow } ty
        }
    , state
    }
  rigidType id = TVar (Rigid id)
  annotationRow id
    | id == Resolved.VarId (Array.length variables - 1) = row
    | otherwise = openRow (Rigid id)
  fresh _ =
    { value: { local: parameter.local, ty: TVar (Hole state.next) }
    , state: state { next = state.next + 1 }
    }

-- The named parameters as locals; `_` binds nothing.
bound ∷ Array Checked.Param → Array Typed
bound = Array.mapMaybe local
  where
  local parameter = withType parameter.ty <$> parameter.local
  withType ty id = { id, ty }
