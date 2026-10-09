module Features.Resolve.Effect (effects, globals, summaries) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Foldable (traverse_)
import Data.Maybe (Maybe(..), maybe)
import Data.Traversable (traverse)
import Domain.Ids (EffectId(..))
import Domain.Problem (DuplicateKind(..), Problem(..))
import Domain.Resolved as Resolved
import Domain.Syntax as Syntax
import Features.Resolve.Types (resolveTypeWith)
import Features.Resolve.Repeated (laterRepeat)

summaries ∷ Array Syntax.EffectDecl → Array { name ∷ String, arity ∷ Int }
summaries = map summary
  where
  summary effect = { name: effect.name, arity: Array.length effect.parameters }

effects
  ∷ Array Resolved.TypeInfo
  → Array Syntax.EffectDecl
  → Either Syntax.Diagnostic (Array Resolved.EffectInfo)
effects types declarations = do
  uniqueEffects declarations
  traverse resolved declarations
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

uniqueEffects ∷ Array Syntax.EffectDecl → Either Syntax.Diagnostic Unit
uniqueEffects declarations = do
  duplicateEffect
  traverse_ duplicateOperations declarations
  traverse_ duplicateParameters declarations
  where
  effectsToCheck = laterRepeat (map effectName declarations)
  effectName effect = effect.name
  duplicateEffect = maybe (Right unit) effectAt effectsToCheck
  effectAt index = maybe (Right unit) duplicate
    (Array.index declarations index)
  duplicate declaration = Left
    ( Syntax.problemAt
        (Duplicate DuplicateEffect declaration.name)
        declaration.span
    )
  duplicateOperations effect = maybe (Right unit) (operationAt effect)
    (laterRepeat (map operationName effect.operations))
  operationAt effect index = maybe (Right unit) duplicateOperation
    (Array.index effect.operations index)
  duplicateOperation declaration = Left
    ( Syntax.problemAt
        (Duplicate DuplicateOperation declaration.name)
        declaration.span
    )
  operationName operation = operation.name
  duplicateParameters effect = do
    traverse_ duplicateEffectParameter
      ( laterRepeat (map effectParameterName effect.parameters)
          >>= Array.index effect.parameters
      )
    traverse_ duplicateOperationParameters effect.operations
  duplicateEffectParameter parameter = Left
    ( Syntax.problemAt
        (Duplicate DuplicateTypeParameter parameter.name)
        parameter.span
    )
  duplicateOperationParameters operation = traverse_ duplicateParameter
    ( laterRepeat (map operationParameterName operation.parameters)
        >>= Array.index operation.parameters
    )
  duplicateParameter parameter = Left
    ( Syntax.problemAt
        (Duplicate DuplicateParameter parameter.name)
        parameter.span
    )
  effectParameterName parameter = parameter.name
  operationParameterName parameter = parameter.name
