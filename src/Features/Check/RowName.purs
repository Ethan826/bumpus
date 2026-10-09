module Features.Check.RowName (labelName, rowName, rowConflict) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (maybe, maybe')
import Data.String (joinWith)
import Data.Traversable (traverse)
import Domain.Ids (EffectId(..))
import Domain.Problem (Problem(..), TypeName(..))
import Domain.Resolved (EffectInfo, TypeInfo)
import Domain.Row (EffectRef(..), Label(..), Row(..))
import Domain.Syntax (Diagnostic, Span, problemAt)
import Domain.Type (Ty, TyRow, VarId(..))
import Features.Check.Scheme (opened)
import Features.Check.Subst (Flex(..))
import Features.Check.TypeName (typeName)

labelName
  ∷ ∀ r
  . { effects ∷ Array EffectInfo
    , types ∷ Array TypeInfo
    , variables ∷ Array String
    | r
    }
  → Span
  → Label (Ty Flex)
  → Either Diagnostic String
labelName env span (Label effect arguments) = do
  name ← effectName effect
  parts ← traverse (typeName env span <<< opened) arguments
  pure (name <> listed (map rendered parts))
  where
  effectName ConsoleEffect = Right "Console"
  effectName FailEffect = Right "Fail"
  effectName (UserEffect (EffectId index)) = maybe' missing named
    (Array.index env.effects index)
  named info = Right info.name
  missing _ = Left (problemAt (Internal "Invalid effect id") span)

rowName
  ∷ ∀ r
  . { effects ∷ Array EffectInfo
    , types ∷ Array TypeInfo
    , variables ∷ Array String
    | r
    }
  → Span
  → TyRow Flex
  → Either Diagnostic String
rowName env span (Row labels tail) = joined <$> traverse
  (labelName env span)
  labels
  where
  ending variable = "..." <> tailName env variable
  suffix = maybe [] (Array.singleton <<< ending) tail
  joined parts = case parts <> suffix of
    [] → "pure"
    found → joinWith " + " found

rowConflict
  ∷ ∀ r a
  . { effects ∷ Array EffectInfo
    , types ∷ Array TypeInfo
    , variables ∷ Array String
    | r
    }
  → Span
  → TyRow Flex
  → TyRow Flex
  → Either Diagnostic a
rowConflict env span left@(Row _ tail) right = do
  first ← rowName env span left
  second ← rowName env span right
  Left
    ( problemAt
        ( RowEquality first second
            (maybe "" (tailName env) tail)
        )
        span
    )

tailName ∷ ∀ r. { variables ∷ Array String | r } → Flex → String
tailName env = case _ of
  Rigid (VarId index) → maybe "" identity (Array.index env.variables index)
  Meta _ → ""

listed ∷ Array String → String
listed parts =
  if Array.null parts then "" else "(" <> joinWith ", " parts <> ")"

rendered ∷ TypeName → String
rendered = case _ of
  IntName → "Int"
  BoolName → "Bool"
  UnitName → "Unit"
  DataName name → name
  AppliedName name arguments → name <> listed (map rendered arguments)
  VariableName name → name
  HoleName → "_"
  FunctionName parameter result → rendered parameter <> " -> " <> rendered
    result
