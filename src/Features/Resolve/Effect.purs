module Features.Resolve.Effect (effects, globals, summaries) where

import Prelude
import Data.Array as Array
import Data.Either (Either)
import Data.Maybe (Maybe(..))
import Data.Traversable (traverse)
import Domain.Ids (EffectId(..))
import Domain.Resolved as Resolved
import Domain.Syntax as Syntax
import Features.Resolve.Types (resolveTypeWith)

summaries ∷ Array Syntax.EffectDecl → Array { name ∷ String, arity ∷ Int }
summaries = map summary
  where
  summary effect = { name: effect.name, arity: Array.length effect.parameters }

effects
  ∷ Array Resolved.TypeInfo
  → Array Syntax.EffectDecl
  → Either Syntax.Diagnostic (Array Resolved.EffectInfo)
effects types declarations = traverse resolved declarations
  where
  resolved effect = withOperations effect <$> traverse
    (operation (map parameterName effect.parameters))
    effect.operations
  parameterName entry = entry.name
  operation variables declaration = withSignature declaration
    <$> traverse (parameter variables) declaration.parameters
    <*> resolveTypeWith types (summaries declarations) variables Nothing
      declaration.result
  parameter variables declaration = withType declaration
    <$> resolveTypeWith types (summaries declarations) variables Nothing
      declaration.ty
  withType declaration ty =
    { name: declaration.name, ty, span: declaration.span }
  withSignature declaration parameters result =
    { name: declaration.name, parameters, result, span: declaration.span }
  withOperations effect operations =
    { name: effect.name
    , parameters: map parameterName effect.parameters
    , operations
    , span: effect.span
    }

globals ∷ Array Resolved.EffectInfo → Array Resolved.Global
globals found = Array.concat (Array.mapWithIndex owned found)
  where
  owned index effect = Array.mapWithIndex (operation (EffectId index))
    effect.operations
  operation effect index info =
    { name: info.name
    , ref: Resolved.Operation effect index
        (Array.length info.parameters)
    }
