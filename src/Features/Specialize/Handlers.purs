module Features.Specialize.Handlers
  ( operationRef
  , perform
  , handlerValue
  , handle
  , abort
  ) where

import Prelude
import Data.Maybe (maybe')
import Data.Traversable (traverse)
import Domain.Checked.Internal as Checked
import Domain.IR.Internal as IR
import Domain.Ids (EffectId)
import Domain.Row (EffectRef(..), TypeHead)
import Domain.Syntax (Span)
import Domain.Type (Ty)
import Domain.Type.Parts (typeHead)
import Features.Specialize.Effects (effectAt)
import Features.Specialize.Keys (Specializing, internal)
import Features.Specialize.Values (Copier, Scope, typed)

-- FX001's effect nodes at one key (design §4): rows are gone; what stays
-- is each operation's and handler's effect layout, the effect at its
-- instantiation lowered, created on first reference. Pre-order, as
-- Features.Specialize.Body: the layout, then the parts left to right.
operationRef
  ∷ Scope
  → Span
  → EffectId
  → Int
  → Checked.Instantiation
  → Specializing IR.Node
operationRef scope span effect index instantiation =
  operationNode <$> layoutOf scope span effect instantiation
  where
  operationNode key = IR.OperationRef key index

perform
  ∷ Scope
  → Copier
  → Span
  → EffectId
  → Int
  → Checked.Instantiation
  → Array Checked.Expr
  → Specializing IR.Node
perform scope copy span effect index instantiation arguments = IR.Perform
  <$> layoutOf scope span effect instantiation
  <*> pure index
  <*> traverse copy arguments

-- A clause's parameters take their types at the key, as a lambda's do.
handlerValue
  ∷ Scope
  → Copier
  → Span
  → EffectId
  → Checked.Instantiation
  → Array Checked.HandlerClause
  → Specializing IR.Node
handlerValue scope copy span effect instantiation clauses = IR.HandlerValue
  <$> layoutOf scope span effect instantiation
  <*> traverse clause clauses
  where
  clause checked = made checked <$> traverse parameter checked.parameters
    <*> copy checked.body
  made checked parameters body =
    { operation: checked.operation, parameters, body, span: checked.span }
  parameter checked = withType checked <$> typed scope span checked.ty
  withType checked ty = { local: checked.local, ty }

handle
  ∷ Scope
  → Copier
  → Checked.Expr
  → Array Checked.FailClause
  → Specializing IR.Node
handle scope copy body clauses = IR.Handle <$> copy body
  <*> traverse clause clauses
  where
  clause checked = made checked <$> familyOf checked.span checked.payload
    <*> typed scope checked.span checked.payload
    <*> copy checked.body
  made checked family payload copied =
    { family
    , payload
    , local: checked.local
    , body: copied
    , span: checked.span
    }

-- `fail(e)` aborts to its payload's family (design §2 "Label keys").
abort ∷ Copier → Span → Checked.Expr → Specializing IR.Node
abort copy span value = IR.Abort
  <$> familyOf span (Checked.typeOf value)
  <*> copy value

layoutOf
  ∷ Scope
  → Span
  → EffectId
  → Checked.Instantiation
  → Specializing IR.EffectKey
layoutOf scope span effect instantiation =
  traverse (typed scope span) instantiation
    >>= effectAt scope.env span (UserEffect effect)

-- Checking settled every family (Features.Check.Failure): a payload whose
-- head is still unknown was rejected there, so here it is a compiler bug.
familyOf ∷ ∀ v. Span → Ty v → Specializing TypeHead
familyOf span payload = maybe' (internal "Fail without a family" span) pure
  (typeHead payload)
