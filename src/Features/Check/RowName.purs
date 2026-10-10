module Features.Check.RowName
  ( labelName
  , labelView
  , rowName
  , rowConflict
  , tailName
  ) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Foldable (foldl)
import Data.Map (Map)
import Data.Map as Map
import Data.Maybe (Maybe(..), maybe, maybe')
import Data.String (joinWith)
import Data.Traversable (traverse)
import Domain.Ids (EffectId(..))
import Domain.Problem (LabelName, Problem(..), RowText, TypeName(..))
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
labelName env span label = printed <$> labelView env span label
  where
  printed view = view.effect <> listed (map rendered view.arguments)

-- A label's effect and its arguments as names, for a diagnostic that
-- elides the arguments off the path to a difference.
labelView
  ∷ ∀ r
  . { effects ∷ Array EffectInfo
    , types ∷ Array TypeInfo
    , variables ∷ Array String
    | r
    }
  → Span
  → Label (Ty Flex)
  → Either Diagnostic LabelName
labelView env span (Label effect arguments) = do
  name ← effectName effect
  parts ← traverse (typeName env span <<< opened) arguments
  pure { effect: name, arguments: parts }
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

-- The side condition's failure (design §2): both rows, each label marked
-- when the other row lacks it, and the tail they share.
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
  first ← traverse (labelName env span) (labelsOf left)
  second ← traverse (labelName env span) (labelsOf right)
  Left
    ( problemAt
        ( RowEquality (rowText env left first second)
            (rowText env right second first)
            (maybe "" (tailName env) tail)
        )
        span
    )
  where
  labelsOf (Row labels _) = labels

-- One row's text against the other's: a label differs when the other row
-- has no label of the same text left to pair with it, counting
-- multiplicity.
rowText
  ∷ ∀ r
  . { variables ∷ Array String | r }
  → TyRow Flex
  → Array String
  → Array String
  → RowText
rowText env (Row _ tail) own other =
  { labels: marked.marked, tail: ending <$> tail }
  where
  ending variable = "..." <> tailName env variable
  marked = foldl pair { counts: counted other, marked: [] } own
  pair found text = maybe' (unmatched found text) (matched found text)
    (available found.counts text)
  available counts text = positive =<< Map.lookup text counts
  positive count = if count > 0 then Just count else Nothing
  matched found text count = found
    { counts = Map.insert text (count - 1) found.counts
    , marked = Array.snoc found.marked { text, differs: false }
    }
  unmatched found text _ = found
    { marked = Array.snoc found.marked { text, differs: true } }

counted ∷ Array String → Map String Int
counted = foldl count Map.empty
  where
  count found text = Map.insertWith (+) text 1 found

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
