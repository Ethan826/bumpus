module Features.Check.Use
  ( Use
  , Callee
  , withOrigin
  , functionUse
  , ctorUse
  , declarationUse
  , checkFunctionRef
  , checkCtorRef
  ) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (Maybe(..), fromMaybe, maybe')
import Domain.Row (closedRow)
import Domain.Type (TyRow)
import Domain.Syntax as Syntax
import Features.Check.Stages (arrowType, openedRow, stages)
import Domain.Checked.Internal (Open)
import Domain.Checked.Internal as Checked
import Domain.Problem (Problem(..))
import Domain.Resolved (CtorId(..), FunctionId(..), Ty(..), TypeId(..))
import Domain.Resolved as Resolved
import Domain.Syntax (Diagnostic, Span, problemAt)
import Features.Check.Context (CheckEnv)
import Features.Check.Provenance (Consumed(..))
import Features.Check.Scheme (Scheme, State, Threaded, at, instantiate)
import Features.Check.Tables (ownerType)

-- One use of a function's or constructor's scheme, its variables
-- instantiated afresh: the parameters (fields) and the result, kept apart
-- so a direct call never builds the curried arrow (plan, linear cost).
-- `consumed` names what a saturated use consumes (design §6); `callee`
-- is the named function it instantiates, for the notes of an argument's
-- rejection: its parameters' spans, and its declaration.
type Use =
  { fields ∷ Array (Ty Open)
  , result ∷ Ty Open
  , scheme ∷ Scheme
  , row ∷ TyRow Open
  , rows ∷ Array (TyRow Open)
  , consumed ∷ Consumed
  , callee ∷ Maybe Callee
  }

type Callee =
  { name ∷ String
  , span ∷ Span
  , parameters ∷ Array Span
  , variables ∷ Array String
  , sorts ∷ Array Syntax.Sort
  }

type Used = Either Diagnostic (Threaded Use)

functionUse ∷ ∀ r. CheckEnv r → State → Span → FunctionId → Used
functionUse env state span (FunctionId index) =
  maybe' missing found (Array.index env.functions index)
  where
  missing _ = Left (problemAt (Internal "Invalid resolved function") span)
  found function = Right
    ( withOrigin (CallOf function.name) (Just (calleeOf function))
        ( declarationUse state function.variables function.sorts
            (map parameterType function.parameters)
            function.result
            function.row
        )
    )
  parameterType parameter = parameter.ty
  calleeOf function =
    { name: function.name
    , span: function.span
    , parameters: map parameterSpan function.parameters
    , variables: function.variables
    , sorts: function.sorts
    }
  parameterSpan parameter = fromMaybe parameter.span parameter.rowSpan

-- A use that consumes `consumed`, of this callee, if it is a named one.
withOrigin ∷ Consumed → Maybe Callee → Threaded Use → Threaded Use
withOrigin consumed callee use = use
  { value = use.value { consumed = consumed, callee = callee } }

-- Type slots retain their ids; row slots never become type arguments.
declarationUse
  ∷ State
  → Array String
  → Array Syntax.Sort
  → Array (Ty Resolved.VarId)
  → Ty Resolved.VarId
  → TyRow Resolved.VarId
  → Threaded Use
declarationUse state variables sorts fields result row =
  { value:
      { fields: map (at scheme.value) fields
      , result: at scheme.value result
      , scheme: scheme.value { arguments = arguments }
      , row: opened.value
      , rows: staged.value
      , consumed: Application
      , callee: Nothing
      }
  , state: staged.state
  }
  where
  scheme = instantiate variables state
  instantiated = mapped (at scheme.value (TFun TUnit row TUnit))
  mapped (TFun _ found _) = found
  mapped _ = closedRow
  opened = openedRow scheme.state instantiated
  staged = stages opened.state (Array.length fields) opened.value
  arguments = Array.catMaybes
    (Array.zipWith argument sorts scheme.value.arguments)
  argument Syntax.TypeSort ty = Just ty
  argument Syntax.RowSort _ = Nothing

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
  owned ctor info = Right
    ( withOrigin (CallOf ctor.name) Nothing
        ( declarationUse state info.variables info.sorts
            ctor.fields
            (ownerType ctor.owner info)
            closedRow
        )
    )

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
      { ty: arrowType use.value.fields use.value.rows use.value.result
      , span
      , node: node use.value.scheme.arguments
      }
  , state: use.state
  }
