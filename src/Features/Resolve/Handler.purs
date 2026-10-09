module Features.Resolve.Handler
  ( Handler
  , Clause
  , Parameter
  , resolveHandler
  ) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Foldable (traverse_)
import Data.Maybe (Maybe(..), maybe, maybe')
import Data.Traversable (traverse)
import Domain.Ids (EffectId(..))
import Domain.Problem (DuplicateKind(..), Problem(..))
import Domain.Resolved as Resolved
import Domain.Row (EffectRef(..), Label(..))
import Domain.Syntax as Syntax
import Domain.Type (Ty, VarId)
import Features.Resolve.Row (label)
import Features.Resolve.Repeated (laterRepeat)
import Features.Resolve.Types (resolveTypeWith)

type Handler =
  { effect ∷ EffectId
  , label ∷ Label (Ty VarId)
  , clauses ∷ Array Clause
  }

type Clause =
  { operation ∷ Int
  , result ∷ Ty VarId
  , parameters ∷ Array Parameter
  , body ∷ Syntax.Expr
  , span ∷ Syntax.Span
  }

type Parameter = { name ∷ Maybe String, ty ∷ Ty VarId, span ∷ Syntax.Span }

resolveHandler
  ∷ Array Resolved.TypeInfo
  → Array Resolved.EffectInfo
  → Array { name ∷ String, arity ∷ Int }
  → Array String
  → Syntax.Span
  → Syntax.LabelRef
  → Array Syntax.Clause
  → Either Syntax.Diagnostic Handler
resolveHandler types effects summaries variables span reference clauses = do
  labelValue ← label summaries
    (resolveTypeWith types summaries variables Nothing)
    reference
  effectId ← effectIdOf labelValue
  effect ← atEffect effects effectId span
  validateClauseParameters clauses
  resolved ← traverse (resolveClause effect) clauses
  validateDuplicates clauses
  validateComplete effect span clauses
  pure { effect: effectId, label: labelValue, clauses: resolved }

effectIdOf ∷ Label (Ty VarId) → Either Syntax.Diagnostic EffectId
effectIdOf (Label (UserEffect id) _) = Right id
effectIdOf _ = Left
  (Syntax.problemAt (Internal "Invalid handler effect") originSpan)
  where
  originSpan = { start: Syntax.origin, end: Syntax.origin }

atEffect
  ∷ Array Resolved.EffectInfo
  → EffectId
  → Syntax.Span
  → Either Syntax.Diagnostic Resolved.EffectInfo
atEffect effects (EffectId index) span = maybe' missing Right
  (Array.index effects index)
  where
  missing _ = Left (Syntax.problemAt (Internal "Invalid effect id") span)

resolveClause
  ∷ Resolved.EffectInfo
  → Syntax.Clause
  → Either Syntax.Diagnostic Clause
resolveClause effect clause = maybe' unknown found
  (Array.findIndex (operationNamed clause.name) effect.operations)
  where
  operationNamed name operation = name == operation.name
  unknown _ = Left
    ( Syntax.problemAt
        (HandlerOperation clause.name effect.name)
        clause.span
    )
  found index = maybe' invalid resolved (Array.index effect.operations index)
    where
    invalid _ = Left
      ( Syntax.problemAt (Internal "Invalid operation index")
          clause.span
      )
    resolved operation
      | Array.length clause.parameters /= Array.length operation.parameters =
          Left (Syntax.problemAt Arity clause.span)
      | otherwise = Right
          { operation: index
          , result: operation.result
          , parameters: Array.zipWith typed clause.parameters
              operation.parameters
          , body: clause.body
          , span: clause.span
          }
    typed parameter argument =
      { name: parameter.name, ty: argument.ty, span: parameter.span }

validateClauseParameters ∷ Array Syntax.Clause → Either Syntax.Diagnostic Unit
validateClauseParameters = traverse_ validateClause
  where
  validateClause clause = traverse_ duplicate
    ( maybe [] Array.singleton
        ( laterRepeat (map parameterName namedParameters)
            >>= Array.index namedParameters
        )
    )
    where
    namedParameters = Array.mapMaybe named clause.parameters
    named parameter = map (withSpan parameter.span) parameter.name
    parameterName parameter = parameter.name
    withSpan span name = { name, span }
    duplicate parameter = Left
      ( Syntax.problemAt
          (Duplicate DuplicateParameter parameter.name)
          parameter.span
      )

validateDuplicates
  ∷ Array Syntax.Clause
  → Either Syntax.Diagnostic Unit
validateDuplicates clauses = traverse_ unique indexed
  where
  indexed = Array.mapWithIndex numbered clauses
  numbered index clause = { index, clause }
  unique entry =
    if hasEarlier entry then Left
      (Syntax.problemAt (HandlerDuplicate entry.clause.name) entry.clause.span)
    else Right unit
  hasEarlier entry = Array.any (sameName entry.clause.name)
    (Array.take entry.index clauses)
  sameName name clause = clause.name == name

validateComplete
  ∷ Resolved.EffectInfo
  → Syntax.Span
  → Array Syntax.Clause
  → Either Syntax.Diagnostic Unit
validateComplete effect span clauses = maybe' complete missing absent
  where
  complete _ = Right unit
  absent = Array.find (notProvided clauses) effect.operations
  notProvided found operation = not (Array.any (sameName operation.name) found)
  sameName name clause = clause.name == name
  missing operation = Left
    ( Syntax.problemAt
        (HandlerMissing operation.name)
        span
    )
