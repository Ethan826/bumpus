module Features.Check.Entry (check, resolvedRow) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Foldable (traverse_)
import Data.Maybe (Maybe(..), maybe)
import Data.Tuple (Tuple(..))
import Domain.Checked.Internal (Open)
import Domain.Problem (Problem(..))
import Domain.Resolved as Resolved
import Domain.Row (EffectRef(..), Label(..), Row(..))
import Domain.Syntax (Diagnostic)
import Domain.Type (Ty(..), TyRow)
import Features.Check.Context (CheckEnv)
import Features.Check.Provenance (Boundary(Main), occurrencesAt, trail)
import Features.Check.Report (boundaryNote, crossingNotes, originNotes)
import Features.Check.RowName (labelName)
import Features.Check.Scheme (State, flexible, flexibleRow, opened)
import Features.Check.Subst (Subst, resolve)

resolvedRow ∷ Subst → TyRow Open → TyRow Open
resolvedRow subst row =
  case opened (resolve subst (flexible (TFun TUnit row TUnit))) of
    TFun _ found _ → found
    _ → row

-- `main` may perform only Console. The first other label of its final row
-- is rejected at the expression whose consumption put it there, with
-- notes for where it arose and for `main` as the boundary (design §6).
check
  ∷ ∀ r
  . CheckEnv r
  → State
  → Resolved.FunctionDecl
  → Either Diagnostic Unit
check env state definition
  | definition.name /= "main" = Right unit
  | otherwise =
      traverse_ allowed
        (Array.zip labels (occurrences definition.span))
      where
      Row labels _ =
        case resolve state.subst (flexible (TFun TUnit env.current TUnit)) of
          TFun _ row _ → row
          _ → Row [] Nothing
      occurrences span = occurrencesAt span state.subst
        (flexibleRow env.current)
      allowed (Tuple (Label ConsoleEffect _) _) = Right unit
      allowed (Tuple label occurrence) = do
        name ← labelName env definition.span label
        rejection name (trail state.subst state.origins occurrence)
      rejection name hops = Left
        { problem: UnhandledEffect name
        , span: primary hops
        , related: originNotes (primary hops) name hops
            <> crossingNotes name hops
            <> [ boundaryNote definition.span name Main ]
        }
      primary hops = maybe definition.span _.span (firstOrigin hops)
      firstOrigin hops = Array.head (Array.mapMaybe originOf hops)
      originOf hop = hop.origin
