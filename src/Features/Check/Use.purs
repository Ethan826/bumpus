module Features.Check.Use
  ( Use
  , functionUse
  , ctorUse
  , checkFunctionRef
  , checkCtorRef
  ) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (maybe')
import Domain.Checked.Internal (Open)
import Domain.Checked.Internal as Checked
import Domain.Problem (Problem(..))
import Domain.Resolved (CtorId(..), FunctionId(..), Ty(..), TypeId(..))
import Domain.Syntax (Diagnostic, Span, problemAt)
import Domain.Type.Parts (arrows)
import Features.Check.Context (CheckEnv)
import Features.Check.Scheme (Scheme, State, Threaded, at, instantiate)

-- One use of a function's or constructor's scheme, its variables
-- instantiated afresh: the parameters (fields) and the result, kept apart
-- so a direct call never builds the curried arrow (plan, linear cost).
type Use = { fields ∷ Array (Ty Open), result ∷ Ty Open, scheme ∷ Scheme }

type Used = Either Diagnostic (Threaded Use)

functionUse ∷ ∀ r. CheckEnv r → State → Span → FunctionId → Used
functionUse env state span (FunctionId index) =
  maybe' missing found (Array.index env.functions index)
  where
  missing _ = Left (problemAt (Internal "Invalid resolved function") span)
  found function = Right (use function (instantiate function.variables state))
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
ctorUse ∷ ∀ r. CheckEnv r → State → Span → CtorId → Used
ctorUse env state span (CtorId index) =
  maybe' missing found (Array.index env.ctors index)
  where
  missing _ = Left
    (problemAt (Internal "Invalid resolved constructor") span)
  found ctor = maybe' missingType (owned ctor) (ownerOf ctor.owner)
  missingType _ = Left (problemAt (Internal "Invalid resolved type") span)
  ownerOf (TypeId owner) = Array.index env.types owner
  owned ctor info = Right (use ctor (instantiate info.parameters state))
  use ctor scheme =
    { value:
        { fields: map (at scheme.value) ctor.fields
        , result: TData ctor.owner scheme.value.arguments []
        , scheme: scheme.value
        }
    , state: scheme.state
    }

-- A bare reference is a value of the scheme's curried type (design §3).
checkFunctionRef
  ∷ ∀ r
  . CheckEnv r
  → State
  → Span
  → FunctionId
  → Either Diagnostic (Threaded Checked.Expr)
checkFunctionRef env state span id = reference span (Checked.FunctionRef id)
  <$> functionUse env state span id

checkCtorRef
  ∷ ∀ r
  . CheckEnv r
  → State
  → Span
  → CtorId
  → Either Diagnostic (Threaded Checked.Expr)
checkCtorRef env state span id = reference span (Checked.CtorRef id)
  <$> ctorUse env state span id

reference
  ∷ Span
  → (Checked.Instantiation → Checked.Node)
  → Threaded Use
  → Threaded Checked.Expr
reference span node use =
  { value: Checked.Expr
      { ty: arrows use.value.fields use.value.result
      , span
      , node: node use.value.scheme.arguments
      }
  , state: use.state
  }
