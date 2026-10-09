module Features.Check.TypeName (Names, typeName) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (maybe')
import Data.Traversable (traverse)
import Domain.Checked.Internal (Open(..))
import Domain.Problem (Problem(..), TypeName(..))
import Domain.Resolved (TypeInfo)
import Domain.Syntax (Diagnostic, Span, problemAt)
import Domain.Type (Ty(..), TypeId(..), VarId(..))
import Domain.Type.Parts (spine)

type Names r = { types ∷ Array TypeInfo, variables ∷ Array String | r }

-- Names appear only in diagnostics, never in generated Go. An arrow's
-- spine is named parameter by parameter, by a loop (Array.foldr).
typeName ∷ ∀ r. Names r → Span → Ty Open → Either Diagnostic TypeName
typeName env span = case _ of
  TInt → Right IntName
  TBool → Right BoolName
  TUnit → Right UnitName
  TData (TypeId index) arguments _ → maybe' missing (named arguments)
    (Array.index env.types index)
  TVar (Rigid (VarId index)) → maybe' unnamed (Right <<< VariableName)
    (Array.index env.variables index)
  TVar (Hole _) → Right HoleName
  arrow@(TFun _ _ _) → arrowName (spine arrow)
  THandler _ _ → Left (problemAt (Internal "Unnamed handler type") span)
  where
  missing _ = Left (problemAt (Internal "Invalid resolved type") span)
  unnamed _ = Left (problemAt (Internal "Unnamed type variable") span)
  named arguments info
    | Array.null arguments = Right (DataName info.name)
    | otherwise = AppliedName info.name <$> traverse (typeName env span)
        arguments
  arrowName found = curried <$> traverse (typeName env span) found.parameters
    <*> typeName env span found.result
  curried parameters result = Array.foldr FunctionName result parameters
