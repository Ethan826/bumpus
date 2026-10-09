module Features.Resolve.Expression (expression) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Foldable (foldl)
import Data.Map as Map
import Data.Maybe (Maybe, maybe')
import Data.String as String
import Data.Traversable (traverse)
import Domain.Problem (Problem(..), UnboundKind(..))
import Domain.Syntax as Syntax
import Domain.Resolved (Global)
import Features.Resolve.Block (block)
import Features.Resolve.Fresh (Fresh, failure, liftEither)
import Features.Resolve.HandlerExpression as HandlerExpression
import Features.Resolve.Lambda (lambda)
import Features.Resolve.Pattern (resolvePattern)
import Features.Resolve.Scope (Scope)
import Domain.Resolved as Resolved

-- Binders are numbered in source pre-order: scrutinee before arms, each
-- arm's pattern before its body, a lambda's parameters before its body,
-- a block's items in order, each `let` before its expression.
-- A flat exhaustive dispatch (BACKLOG E003).
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
  Syntax.HandlerExpr span reference clauses →
    HandlerExpression.handlerExpression expression scope span reference clauses
  Syntax.With span handler body → Resolved.With span <$> nested handler
    <*> nested body
  Syntax.Handle span body clauses → HandlerExpression.failureHandler expression
    scope
    span
    body
    clauses
  Syntax.Fail span value → Resolved.Fail span <$> nested value
  Syntax.UnitValue span → pure (Resolved.UnitValue span)
  Syntax.Block span items value → block expression scope span items value
  where
  -- Eta-expanded: a point-free `expression scope` would recurse at once.
  nested syntax = expression scope syntax

-- A binder is in scope only in its own arm body, where it may shadow.
resolveArm ∷ Scope → Syntax.Arm → Fresh Resolved.Arm
resolveArm scope arm = do
  matched ← resolvePattern scope.globals scope.ctors arm.pattern
  body ← withLocals scope arm.body matched.binders
  pure { pattern: matched.pattern, body, span: arm.span }

-- Later locals shadow earlier ones.
withLocals
  ∷ Scope → Syntax.Expr → Array Resolved.Local → Fresh Resolved.Expr
withLocals scope body locals =
  expression (scope { locals = foldl inserted scope.locals locals }) body
  where
  inserted found local = Map.insert local.name local.id found

-- Design §2: a local wins; then a function, a value if it has parameters
-- and E_ARITY without its call if it has none; then a constructor.
bareName
  ∷ Scope
  → Syntax.Span
  → String
  → Either Syntax.Diagnostic Resolved.Expr
bareName scope span name = maybe' otherwise found (findLocal scope name)
  where
  found id = pure (Resolved.Local span id)
  otherwise _ = maybe' unbound global (findGlobal scope name)
  unbound _ = Left
    (Syntax.problemAt (Unbound UnboundLocal name) span)
  global entry = case entry.ref of
    Resolved.GlobalCtor id → bareConstructor scope span id
    Resolved.GlobalFunction id arity → bareFunction span name id arity
    Resolved.Operation effect index arity →
      if arity == 0 then Left
        (Syntax.problemAt (FunctionNeedsCall name) span)
      else pure (Resolved.OperationRef span effect index)
    Resolved.BuiltinPrint → pure (Resolved.PrintRef span)
    Resolved.BuiltinCrash → pure (Resolved.CrashRef span)

bareFunction
  ∷ Syntax.Span
  → String
  → Resolved.FunctionId
  → Int
  → Either Syntax.Diagnostic Resolved.Expr
bareFunction span name id arity =
  if arity == 0 then Left (Syntax.problemAt (FunctionNeedsCall name) span)
  else pure (Resolved.FunctionRef span id)

-- A constructor with fields is a value; a nullary one is its construction.
bareConstructor
  ∷ Scope
  → Syntax.Span
  → Resolved.CtorId
  → Either Syntax.Diagnostic Resolved.Expr
bareConstructor scope span id = do
  count ← fieldCount scope span id
  if count == 0 then pure (Resolved.Construct span id [])
  else pure (Resolved.CtorRef span id)

callName
  ∷ Scope
  → Syntax.Span
  → String
  → Array Syntax.Expr
  → Fresh Resolved.Expr
callName scope span name arguments = maybe' globalCall localCall
  (findLocal scope name)
  where
  -- Applying a local needs at least one argument (design §4).
  localCall id
    | Array.null arguments = failure
        (Syntax.problemAt (NotCallable name) span)
    | otherwise = Resolved.Apply span (Resolved.Local (nameSpan span name) id)
        <$> resolved
  globalCall _ = maybe' unbound dispatch (findGlobal scope name)
  unbound _ = failure
    (Syntax.problemAt (Unbound UnboundFunction name) span)
  dispatch global = case global.ref of
    Resolved.GlobalFunction id _ → Resolved.Call span id <$> resolved
    Resolved.GlobalCtor id → constructorCall scope span name id resolved
    Resolved.Operation effect index _ → Resolved.Perform span effect index
      <$> resolved
    Resolved.BuiltinPrint → Resolved.Print span <$> resolved
    Resolved.BuiltinCrash → Resolved.Crash span <$> resolved
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

-- A call's name starts its span and never crosses a line.
nameSpan ∷ Syntax.Span → String → Syntax.Span
nameSpan span name = { start: span.start, end }
  where
  width = String.length name
  end = span.start
    { offset = span.start.offset + width
    , column = span.start.column + width
    }

findLocal ∷ Scope → String → Maybe Resolved.LocalId
findLocal scope name = Map.lookup name scope.locals

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
