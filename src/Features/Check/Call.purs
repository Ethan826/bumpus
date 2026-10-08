module Features.Check.Call (checkCall, checkConstruct) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (maybe')
import Domain.Checked.Internal (Open)
import Domain.Checked.Internal as Checked
import Domain.Problem (Problem(..))
import Domain.Resolved (Ty(..), TypeId(..))
import Domain.Resolved as Resolved
import Domain.Syntax (Diagnostic, Span, problemAt)
import Features.Check.Require (require)
import Features.Check.Scheme
  ( Scheme
  , State
  , Threaded
  , at
  , instantiate
  , threadAll
  )

-- Open rows let Features.Check.Infer pass its own environment through.
type CallEnv r =
  { functions ∷ Array Resolved.FunctionDecl
  , types ∷ Array Resolved.TypeInfo
  , ctors ∷ Array Resolved.CtorInfo
  , variables ∷ Array String
  | r
  }

type Infer r =
  CallEnv r
  → State
  → Resolved.Expr
  → Either Diagnostic (Threaded Checked.Expr)

-- What a use of a scheme checks its arguments against and produces.
type Use = { fields ∷ Array (Ty Open), result ∷ Ty Open, scheme ∷ Scheme }

-- Each use instantiates the callee's variables afresh.
checkCall
  ∷ ∀ r
  . Infer r
  → CallEnv r
  → State
  → Span
  → Resolved.FunctionId
  → Array Resolved.Expr
  → Either Diagnostic (Threaded Checked.Expr)
checkCall infer env state span id@(Resolved.FunctionId index) arguments =
  maybe' missing found (Array.index env.functions index)
  where
  missing _ = Left (problemAt (Internal "Invalid resolved function") span)
  found function = applied infer env span (Checked.Call id)
    (use function (instantiate function.variables state))
    arguments
  use function scheme =
    { value:
        { fields: map (parameterType scheme.value) function.parameters
        , result: at scheme.value function.result
        , scheme: scheme.value
        }
    , state: scheme.state
    }
  parameterType scheme parameter = at scheme parameter.ty

-- A constructor's scheme is its owner's parameters.
checkConstruct
  ∷ ∀ r
  . Infer r
  → CallEnv r
  → State
  → Span
  → Resolved.CtorId
  → Array Resolved.Expr
  → Either Diagnostic (Threaded Checked.Expr)
checkConstruct infer env state span id@(Resolved.CtorId index) arguments =
  maybe' missing found (Array.index env.ctors index)
  where
  missing _ = Left
    (problemAt (Internal "Invalid resolved constructor") span)
  found ctor = maybe' missingType (owned ctor) (ownerOf ctor.owner)
  missingType _ = Left (problemAt (Internal "Invalid resolved type") span)
  ownerOf (TypeId owner) = Array.index env.types owner
  owned ctor info = applied infer env span (Checked.Construct id)
    (use ctor (instantiate info.parameters state))
    arguments
  use ctor scheme =
    { value:
        { fields: map (at scheme.value) ctor.fields
        , result: TData ctor.owner scheme.value.arguments
        , scheme: scheme.value
        }
    , state: scheme.state
    }

-- Arity is checked before any argument, as Stage 0 calls always did; then
-- every argument is inferred, then each is unified with its field.
applied
  ∷ ∀ r
  . Infer r
  → CallEnv r
  → Span
  → (Checked.Instantiation → Array Checked.Expr → Checked.Node)
  → Threaded Use
  → Array Resolved.Expr
  → Either Diagnostic (Threaded Checked.Expr)
applied infer env span node use arguments = do
  when (Array.length arguments /= Array.length use.value.fields)
    (Left (problemAt Arity span))
  checked ← threadAll (infer env) use.state arguments
  unified ← threadAll checkArgument checked.state
    (Array.zipWith argumentPair use.value.fields checked.value)
  pure
    { value: Checked.Expr
        { ty: use.value.result
        , span
        , node: node use.value.scheme.arguments checked.value
        }
    , state: unified.state
    }
  where
  argumentPair ty actual = { ty, actual }
  checkArgument reached pair = threadedUnit <$> require env reached pair.ty
    pair.actual
  threadedUnit reached = { value: unit, state: reached }
