module Features.Resolve.HandlerType (resolve) where

import Prelude
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.Traversable (traverse)
import Domain.Problem (Problem(..))
import Domain.Resolved as Resolved
import Domain.Syntax as Syntax
import Features.Resolve.Row (label, resolveRow)

type Effects = Array { name ∷ String, arity ∷ Int }

resolve
  ∷ Effects
  → Array String
  → Maybe Resolved.VarId
  → (Syntax.TypeRef → Either Syntax.Diagnostic (Resolved.Ty Resolved.VarId))
  → Syntax.Span
  → Array Syntax.TypeArgument
  → Either Syntax.Diagnostic (Resolved.Ty Resolved.VarId)
resolve effects variables ambient resolveType span arguments = case arguments of
  [ Syntax.TypeArgument
      (Syntax.NamedRef effectSpan effectName effectArguments)
  ] → withArguments effectSpan effectName effectArguments
  _ → Left (Syntax.problemAt (TypeArguments "Handler") span)
  where
  withArguments effectSpan effectName effectArguments = do
    argumentRefs ← traverse typeReference effectArguments
    Resolved.THandler
      <$> label effects resolveType
        { name: effectName, arguments: argumentRefs, span: effectSpan }
      <*> resolveRow effects variables ambient resolveType Nothing
  typeReference = case _ of
    Syntax.TypeArgument reference → Right reference
    Syntax.RowArgument (Syntax.RowRef rowSpan _ _) → Left
      (Syntax.problemAt (RowSort false) rowSpan)
