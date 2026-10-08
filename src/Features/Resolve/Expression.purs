module Features.Resolve.Expression (Scope, expression) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (Maybe, maybe')
import Data.Traversable (traverse)
import Domain.Problem (Problem(..), UnboundKind(..))
import Domain.Syntax as Syntax
import Features.Resolve.Fresh (Fresh, failure, liftEither)
import Features.Resolve.Lambda (lambda)
import Features.Resolve.Pattern (resolvePattern)
import Domain.Resolved (Global)
import Domain.Resolved as Resolved

-- `types` and `variables` (the enclosing signature's) are what a lambda
-- annotation may name.
type Scope =
  { globals ∷ Array Global
  , ctors ∷ Array Resolved.CtorInfo
  , locals ∷ Array Resolved.Local
  , types ∷ Array Resolved.TypeInfo
  , variables ∷ Array String
  }

-- Binders are numbered in source pre-order: scrutinee before arms, each
-- arm's pattern before its body, a lambda's parameters before its body.
-- Bare names and calls of locals keep their P001 resolution until FN001
-- Task 4. A flat exhaustive dispatch (BACKLOG E003).
expression ∷ Scope → Syntax.Expr → Fresh Resolved.Expr
expression scope = case _ of
  Syntax.Integer span value → pure (Resolved.Integer span value)
  Syntax.Boolean span value → pure (Resolved.Boolean span value)
  Syntax.Variable span name → liftEither (bareName scope span name)
  Syntax.Call span name arguments → callName scope span name arguments
  Syntax.Add span left right → Resolved.Add span <$> nested left
    <*> nested right
  Syntax.Compare span operator left right → Resolved.Compare span operator
    <$> nested left
    <*> nested right
  Syntax.If span condition yes no → Resolved.If span <$> nested condition
    <*> nested yes
    <*> nested no
  Syntax.Match span scrutinee arms → Resolved.Match span
    <$> nested scrutinee
    <*> traverse (resolveArm scope) arms
  Syntax.Lambda span parameters body → lambda scope span parameters
    (withLocals scope body)
  Syntax.Apply span callee arguments → Resolved.Apply span <$> nested callee
    <*> traverse nested arguments
  Syntax.Pipe span left right → Resolved.Pipe span <$> nested left
    <*> nested right
  where
  -- Eta-expanded: a point-free `expression scope` would recurse at once.
  nested syntax = expression scope syntax

-- A binder is in scope only in its own arm body, where it may shadow.
resolveArm ∷ Scope → Syntax.Arm → Fresh Resolved.Arm
resolveArm scope arm = do
  matched ← resolvePattern scope.globals scope.ctors arm.pattern
  body ← withLocals scope arm.body matched.binders
  pure { pattern: matched.pattern, body, span: arm.span }

-- Later locals shadow earlier ones (findLocal searches from the end).
withLocals
  ∷ Scope → Syntax.Expr → Array Resolved.Local → Fresh Resolved.Expr
withLocals scope body locals =
  expression (scope { locals = scope.locals <> locals }) body

-- A local wins, then a nullary constructor. Functions are not values.
bareName
  ∷ Scope
  → Syntax.Span
  → String
  → Either Syntax.Diagnostic Resolved.Expr
bareName scope span name = maybe' otherwise found (findLocal scope name)
  where
  found id = pure (Resolved.Local span id)
  otherwise _ = maybe' unbound constructorOnly (findGlobal scope name)
  unbound _ = Left
    (Syntax.problemAt (Unbound UnboundLocal name) span)
  constructorOnly global = case global.ref of
    Resolved.CtorRef id → bareConstructor scope span name id
    Resolved.FunctionRef _ → unbound unit

bareConstructor
  ∷ Scope
  → Syntax.Span
  → String
  → Resolved.CtorId
  → Either Syntax.Diagnostic Resolved.Expr
bareConstructor scope span name id = do
  count ← fieldCount scope span id
  if count == 0 then pure (Resolved.Construct span id [])
  else Left (Syntax.problemAt (CtorNeedsArguments name) span)

callName
  ∷ Scope
  → Syntax.Span
  → String
  → Array Syntax.Expr
  → Fresh Resolved.Expr
callName scope span name arguments = maybe' globalCall localCall
  (findLocal scope name)
  where
  localCall _ = failure (Syntax.problemAt (NotCallable name) span)
  globalCall _ = maybe' unbound dispatch (findGlobal scope name)
  unbound _ = failure
    (Syntax.problemAt (Unbound UnboundFunction name) span)
  dispatch global = case global.ref of
    Resolved.FunctionRef id → Resolved.Call span id <$> resolved
    Resolved.CtorRef id → constructorCall scope span name id resolved
  resolved = traverse (expression scope) arguments

constructorCall
  ∷ Scope
  → Syntax.Span
  → String
  → Resolved.CtorId
  → Fresh (Array Resolved.Expr)
  → Fresh Resolved.Expr
constructorCall scope span name id resolved = do
  count ← liftEither (fieldCount scope span id)
  if count == 0 then failure (Syntax.problemAt (CtorNotCallable name) span)
  else Resolved.Construct span id <$> resolved

findLocal ∷ Scope → String → Maybe Resolved.LocalId
findLocal scope name = entryId <$> Array.find named
  (Array.reverse scope.locals)
  where
  named local = local.name == name
  entryId local = local.id

findGlobal ∷ Scope → String → Maybe Global
findGlobal scope name = Array.find named scope.globals
  where
  named global = global.name == name

-- A global's CtorId always indexes the table; a miss is a compiler bug.
fieldCount
  ∷ Scope → Syntax.Span → Resolved.CtorId → Either Syntax.Diagnostic Int
fieldCount scope span (Resolved.CtorId index) =
  maybe' missing count (Array.index scope.ctors index)
  where
  missing _ = Left
    (Syntax.problemAt (Internal "Invalid constructor id") span)
  count info = Right (Array.length info.fields)
