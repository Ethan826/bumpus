module Features.Check.Entry (check, resolvedRow) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (Maybe(..), maybe)
import Data.Foldable (traverse_)
import Domain.Checked.Internal (Open)
import Domain.Checked.Internal as Checked
import Domain.Problem (Problem(..))
import Domain.Resolved as Resolved
import Domain.Row (EffectRef(..), Label(..), Row(..))
import Domain.Syntax (Diagnostic, problemAt)
import Domain.Type (Ty(..), TyRow)
import Features.Check.Context (CheckEnv)
import Features.Check.RowName (labelName)
import Features.Check.Scheme (flexible, opened)
import Features.Check.Subst (Subst, resolve)

resolvedRow ∷ Subst → TyRow Open → TyRow Open
resolvedRow subst row =
  case opened (resolve subst (flexible (TFun TUnit row TUnit))) of
    TFun _ found _ → found
    _ → row

check
  ∷ ∀ r
  . CheckEnv r
  → Subst
  → Resolved.FunctionDecl
  → Checked.Expr
  → Either Diagnostic Unit
check env subst definition body
  | definition.name /= "main" = Right unit
  | otherwise = traverse_ allowed labels
      where
      Row labels _ =
        case resolve subst (flexible (TFun TUnit env.current TUnit)) of
          TFun _ row _ → row
          _ → Row [] Nothing
      allowed (Label ConsoleEffect _) = Right unit
      allowed label@(Label effect _) = do
        name ← labelName env definition.span label
        Left
          ( problemAt (UnhandledEffect name)
              (maybe definition.span Checked.spanOf (origin effect body))
          )

-- Task 9 adds full occurrence provenance. Direct operations already point
-- at their execution site instead of the entry declaration.
origin ∷ EffectRef → Checked.Expr → Maybe Checked.Expr
origin effect whole@(Checked.Expr expression) = case expression.node of
  Checked.Perform owner _ _ _ | effect == UserEffect owner → Just whole
  Checked.Block items value → first (Checked.blockParts items value)
  Checked.Call _ _ arguments → first arguments
  Checked.Apply callee arguments → first (Array.cons callee arguments)
  Checked.Lambda _ body → origin effect body
  _ → Nothing
  where
  first parts = Array.head (Array.mapMaybe (origin effect) parts)
