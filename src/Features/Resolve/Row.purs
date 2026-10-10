module Features.Resolve.Row (resolveRow, label, failFamily) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (Maybe(..), maybe, maybe')
import Data.Traversable (traverse)
import Domain.Ids (EffectId(..))
import Domain.Problem (Problem(..), UnboundKind(..))
import Domain.Row (EffectRef(..), Label(..), Row(..))
import Domain.Syntax as Syntax
import Domain.Type (Ty(..), TyRow, VarId(..))

type Effects = Array { name ∷ String, arity ∷ Int }

resolveRow
  ∷ Effects
  → Array String
  → Maybe VarId
  → (Syntax.TypeRef → Either Syntax.Diagnostic (Ty VarId))
  → Maybe Syntax.RowRef
  → Either Syntax.Diagnostic (TyRow VarId)
resolveRow effects variables ambient resolve = maybe
  (Right (Row [] ambient))
  written
  where
  written (Syntax.RowRef _ labels tail) = Row
    <$> traverse (label effects resolve) labels
    <*> maybe (Right ambient) ending tail
  ending Syntax.Pure = Right Nothing
  ending (Syntax.Spread name) = maybe' missing found
    (Array.elemIndex name variables)
  found index = Right (Just (VarId index))
  missing _ = Left (Syntax.problemAt (Internal "Missing row variable") nowhere)
  nowhere = { start: Syntax.origin, end: Syntax.origin }

label
  ∷ Effects
  → (Syntax.TypeRef → Either Syntax.Diagnostic (Ty VarId))
  → Syntax.LabelRef
  → Either Syntax.Diagnostic (Label (Ty VarId))
label effects resolve reference = do
  effect ← lookupEffect effects reference
  if effect.arity /= Array.length reference.arguments then
    Left (Syntax.problemAt (TypeArguments reference.name) reference.span)
  else traverse resolve reference.arguments >>= concrete effect.ref reference

concrete
  ∷ EffectRef
  → Syntax.LabelRef
  → Array (Ty VarId)
  → Either Syntax.Diagnostic (Label (Ty VarId))
concrete effect reference arguments = case effect, arguments of
  FailEffect, [ payload ] → toLabel <$> failFamily reference.span payload
  _, _ → Right (Label effect arguments)
  where
  toLabel payload = Label effect [ payload ]

-- A Fail payload needs a family key: Int, Bool, Unit or a declared type.
-- A type variable, a function or a handler type has none, so nothing it is
-- matched against could ever be decided: it is refused where it is written
-- (design §2, FX009).
failFamily ∷ Syntax.Span → Ty VarId → Either Syntax.Diagnostic (Ty VarId)
failFamily span payload =
  if keyless payload then Left
    { problem: FailNeedsConcrete
    , span
    , related: [ { span, reason: Syntax.FailAlternatives } ]
    }
  else Right payload
  where
  keyless = case _ of
    TVar _ → true
    TFun _ _ _ → true
    THandler _ _ → true
    _ → false

lookupEffect
  ∷ Effects
  → Syntax.LabelRef
  → Either Syntax.Diagnostic { ref ∷ EffectRef, arity ∷ Int }
lookupEffect effects reference = case reference.name of
  "Console" → Right { ref: ConsoleEffect, arity: 0 }
  "Fail" → Right { ref: FailEffect, arity: 1 }
  name → maybe' missing found (Array.findIndex (named name) effects)
  where
  named name effect = effect.name == name
  found index = Right
    { ref: UserEffect (EffectId index)
    , arity: maybe 0 arityOf (Array.index effects index)
    }
  arityOf effect = effect.arity
  missing _ = Left
    (Syntax.problemAt (Unbound UnboundType reference.name) reference.span)
