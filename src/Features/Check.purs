module Features.Check (check) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (maybe)
import Data.Traversable (traverse)
import Domain.Checked.Internal (rigid)
import Domain.Checked.Internal as Checked
import Domain.Resolved as Resolved
import Domain.Syntax (Diagnostic)
import Features.Check.Comparable (comparable)
import Features.Check.Coverage (coverage)
import Features.Check.Functional (Functional, functional)
import Features.Check.Infer (Env, infer)
import Features.Check.Instantiation (instantiationRule)
import Features.Check.Require (require, tooDeepAt)
import Features.Check.Scheme (firstTooDeep, holes, resolved, start)
import Features.Check.Walk (retype)

check ∷ Resolved.Program → Either Diagnostic Checked.Program
check program = do
  functions ← traverse checkDefinition program.functions
  let
    checked = Checked.Program
      { types: program.types
      , ctors: program.ctors
      , functions
      , entry: program.entry
      }
  -- The instantiation rule needs every body's final types; coverage runs
  -- last, on a program whose specialization is known to be finite.
  instantiationRule checked
  coverage checked
  pure checked
  where
  holders = functional program.ctors
  checkDefinition definition = checkFunction holders
    (environment program definition)
    definition

environment ∷ Resolved.Program → Resolved.FunctionDecl → Env
environment program function =
  { functions: program.functions
  , types: program.types
  , ctors: program.ctors
  , variables: function.variables
  , locals: Array.mapWithIndex parameterLocal function.parameters
  }
  where
  parameterLocal index parameter =
    { id: Resolved.LocalId index, ty: rigid parameter.ty }

-- Parameters bind rigid types; the body is inferred; then the result
-- unifies; then every type in the body is bounded again (a type bounded
-- when built deepens as its metas are bound); then the body's comparisons
-- must be ground; then the metas still unsolved become holes.
checkFunction
  ∷ Functional
  → Env
  → Resolved.FunctionDecl
  → Either Diagnostic Checked.FunctionDecl
checkFunction holders env function = do
  body ← infer env start function.body
  finished ← require env body.state (rigid function.result) body.value
  maybe (Right unit) tooDeepAt (firstTooDeep finished.subst body.value)
  let settled = retype (resolved finished.subst) body.value
  comparable holders env settled
  pure
    { id: function.id
    , name: function.name
    , parameters: map parameterType function.parameters
    , result: rigid function.result
    , body: holes settled
    , span: function.span
    }
  where
  parameterType parameter = rigid parameter.ty
