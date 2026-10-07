module Features.Resolve.Expression (Scope, expression) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (Maybe, maybe')
import Domain.Problem (Problem(..), UnboundKind(..))
import Domain.Syntax as Syntax
import Features.Resolve.Pattern (resolvePattern)
import Domain.Resolved (Global, Numbered)
import Domain.Resolved as Resolved

type Scope =
  { globals ∷ Array Global
  , ctors ∷ Array Resolved.CtorInfo
  , locals ∷ Array Resolved.Local
  }

type Resolution a = Either Syntax.Diagnostic (Numbered a)

-- `next` is the next free LocalId; binders are numbered in source pre-order.
expression ∷ Scope → Int → Syntax.Expr → Resolution Resolved.Expr
expression scope next = case _ of
  Syntax.Integer span value → unchanged (Resolved.Integer span value)
  Syntax.Boolean span value → unchanged (Resolved.Boolean span value)
  Syntax.Variable span name → numbered <$> bareName scope span name
  Syntax.Call span name arguments → callName scope next span name arguments
  Syntax.Add span left right → resolveAddition span left right
  Syntax.Compare span operator left right → resolveComparison span operator
    left
    right
  Syntax.If span condition yes no → resolveConditional span condition yes no
  Syntax.Match span scrutinee arms → resolveMatch scope next span scrutinee
    arms
  where
  numbered value = { value, next }
  unchanged value = pure (numbered value)
  resolveAddition span left right = do
    first ← expression scope next left
    second ← expression scope first.next right
    pure (second { value = Resolved.Add span first.value second.value })
  resolveComparison span operator left right = do
    first ← expression scope next left
    second ← expression scope first.next right
    pure
      ( second
          { value = Resolved.Compare span operator first.value second.value }
      )
  resolveConditional span condition yes no = do
    predicate ← expression scope next condition
    first ← expression scope predicate.next yes
    second ← expression scope first.next no
    pure
      ( second
          { value = Resolved.If span predicate.value first.value second.value }
      )

resolveMatch
  ∷ Scope
  → Int
  → Syntax.Span
  → Syntax.Expr
  → Array Syntax.Arm
  → Resolution Resolved.Expr
resolveMatch scope next span scrutinee arms = do
  head ← expression scope next scrutinee
  resolved ← Array.foldM (resolveArm scope) { value: [], next: head.next } arms
  pure (resolved { value = Resolved.Match span head.value resolved.value })

-- A binder is in scope only in its own arm body, where it may shadow.
resolveArm
  ∷ Scope
  → Numbered (Array Resolved.Arm)
  → Syntax.Arm
  → Resolution (Array Resolved.Arm)
resolveArm scope acc arm = do
  matched ← resolvePattern scope.globals scope.ctors acc.next arm.pattern
  body ← expression (inner matched.value.binders) matched.next arm.body
  pure (body { value = Array.snoc acc.value (armOf matched body) })
  where
  inner binders = scope { locals = scope.locals <> binders }
  armOf matched body =
    { pattern: matched.value.pattern, body: body.value, span: arm.span }

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
  → Int
  → Syntax.Span
  → String
  → Array Syntax.Expr
  → Resolution Resolved.Expr
callName scope next span name arguments = maybe' globalCall localCall
  (findLocal scope name)
  where
  localCall _ = Left (Syntax.problemAt (NotCallable name) span)
  globalCall _ = maybe' unbound dispatch (findGlobal scope name)
  unbound _ = Left
    (Syntax.problemAt (Unbound UnboundFunction name) span)
  dispatch global = case global.ref of
    Resolved.FunctionRef id → withValue (Resolved.Call span id) <$> resolved
    Resolved.CtorRef id → constructorCall scope span name id resolved
  resolved = Array.foldM resolveArgument { value: [], next } arguments
  resolveArgument acc argument = appended acc <$> expression scope acc.next
    argument
  appended acc argument = argument
    { value = Array.snoc acc.value argument.value }

constructorCall
  ∷ Scope
  → Syntax.Span
  → String
  → Resolved.CtorId
  → Resolution (Array Resolved.Expr)
  → Resolution Resolved.Expr
constructorCall scope span name id resolved = do
  count ← fieldCount scope span id
  if count == 0 then Left (Syntax.problemAt (CtorNotCallable name) span)
  else withValue (Resolved.Construct span id) <$> resolved

withValue ∷ ∀ a b. (a → b) → Numbered a → Numbered b
withValue transform numbered =
  { value: transform numbered.value, next: numbered.next }

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
