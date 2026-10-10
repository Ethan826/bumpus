module Features.Resolve.HandlerExpression
  ( handlerExpression
  , failureHandler
  ) where

import Prelude
import Data.Array as Array
import Data.Foldable (foldl)
import Data.Map as Map
import Data.Maybe (Maybe(..), maybe')
import Data.Traversable (traverse)
import Domain.Resolved as Resolved
import Domain.Row (EffectRef(..), Label(..))
import Domain.Syntax as Syntax
import Features.Resolve.Fresh (Fresh, fresh, liftEither)
import Features.Resolve.Handler as Handler
import Features.Resolve.Scope (Scope)
import Features.Resolve.Types as Types

type ResolveExpression = Scope → Syntax.Expr → Fresh Resolved.Expr

handlerExpression
  ∷ ResolveExpression
  → Scope
  → Syntax.Span
  → Syntax.LabelRef
  → Array Syntax.Clause
  → Fresh Resolved.Expr
handlerExpression resolveExpression scope span reference clauses = do
  resolved ← liftEither
    ( Handler.resolveHandler scope.types scope.effectInfos scope.effects
        scope.variables
        span
        reference
        clauses
    )
  checked ← traverse (handlerClause resolveExpression scope) resolved.clauses
  pure (Resolved.Handler span resolved.label checked)

handlerClause
  ∷ ResolveExpression
  → Scope
  → Handler.Clause
  → Fresh Resolved.HandlerClause
handlerClause resolveExpression scope clause = do
  parameters ← traverse handlerParameter clause.parameters
  let locals = Array.mapMaybe namedLocal parameters
  body ← resolveExpression
    ( scope
        { locals = foldl insertLocal
            scope.locals
            locals
        }
    )
    clause.body
  pure
    { operation: clause.operation
    , result: clause.result
    , parameters: map checkedParameter parameters
    , body
    , span: clause.span
    }
  where
  handlerParameter parameter = do
    id ← allocate parameter.name
    pure { name: parameter.name, id, ty: parameter.ty }
  allocate name = maybe' noName allocateNamed name
  noName _ = pure Nothing
  allocateNamed _ = Just <$> fresh
  namedLocal parameter = do
    name ← parameter.name
    id ← parameter.id
    Just { name, id }
  insertLocal locals local = Map.insert local.name local.id locals
  checkedParameter parameter = { local: parameter.id, ty: parameter.ty }

failureHandler
  ∷ ResolveExpression
  → Scope
  → Syntax.Span
  → Syntax.Expr
  → Array Syntax.FailClause
  → Fresh Resolved.Expr
failureHandler resolveExpression scope span body clauses = do
  checkedBody ← resolveExpression scope body
  checkedClauses ← traverse (failureClause resolveExpression scope) clauses
  pure (Resolved.Handle span checkedBody checkedClauses)

failureClause
  ∷ ResolveExpression
  → Scope
  → Syntax.FailClause
  → Fresh Resolved.FailClause
failureClause resolveExpression scope clause = do
  payload ← liftEither
    ( Types.resolveTypeWith scope.types
        scope.effects
        scope.variables
        Nothing
        clause.ty
    )
  local ← fresh
  let locals = Map.insert clause.name local scope.locals
  body ← resolveExpression (scope { locals = locals }) clause.body
  pure
    { label: Label FailEffect [ payload ]
    , local: Just local
    , body
    , span: clause.span
    }
