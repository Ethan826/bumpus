module Sprig.Resolve.Expression (Global, Scope, expression) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (Maybe, maybe')
import Data.Traversable (traverse)
import Sprig.Model as Syntax
import Sprig.Resolved as Resolved

type Global = { name ∷ String, ref ∷ Resolved.GlobalRef }

type Scope =
  { globals ∷ Array Global
  , ctors ∷ Array Resolved.CtorInfo
  , locals ∷ Array Resolved.Local
  }

expression
  ∷ Scope → Syntax.Expr → Either Syntax.Diagnostic Resolved.Expr
expression scope = case _ of
  Syntax.Integer span value → pure (Resolved.Integer span value)
  Syntax.Boolean span value → pure (Resolved.Boolean span value)
  Syntax.Variable span name → bareName scope span name
  Syntax.Call span name arguments → callName scope span name arguments
  Syntax.Add span left right → resolveAddition span left right
  Syntax.If span condition yes no → resolveConditional span condition yes no
  where
  resolveAddition span left right = Resolved.Add span
    <$> expression scope left
    <*> expression scope right
  resolveConditional span condition yes no = Resolved.If span
    <$> expression scope condition
    <*> expression scope yes
    <*> expression scope no

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
    (Syntax.problem Syntax.UnboundName span ("Unbound local " <> name))
  constructorOnly global = case global.ref of
    Resolved.CtorRef id → bareConstructor scope span name id
    Resolved.FunctionRef _ → unbound unit

bareConstructor
  ∷ Scope
  → Syntax.Span
  → String
  → Resolved.CtorId
  → Either Syntax.Diagnostic Resolved.Expr
bareConstructor scope span name id =
  if fieldCount scope id == 0 then pure (Resolved.Construct span id [])
  else Left
    ( Syntax.problem Syntax.ArityMismatch span
        ("Constructor " <> name <> " needs arguments")
    )

callName
  ∷ Scope
  → Syntax.Span
  → String
  → Array Syntax.Expr
  → Either Syntax.Diagnostic Resolved.Expr
callName scope span name arguments = maybe' globalCall localCall
  (findLocal scope name)
  where
  localCall _ = Left
    ( Syntax.problem Syntax.NotCallable span
        ("Local is not callable: " <> name)
    )
  globalCall _ = maybe' unbound dispatch (findGlobal scope name)
  unbound _ = Left
    (Syntax.problem Syntax.UnboundName span ("Unbound function " <> name))
  dispatch global = case global.ref of
    Resolved.FunctionRef id → Resolved.Call span id <$> resolved
    Resolved.CtorRef id → constructorCall scope span name id resolved
  resolved = traverse resolveArgument arguments
  resolveArgument argument = expression scope argument

constructorCall
  ∷ Scope
  → Syntax.Span
  → String
  → Resolved.CtorId
  → Either Syntax.Diagnostic (Array Resolved.Expr)
  → Either Syntax.Diagnostic Resolved.Expr
constructorCall scope span name id resolved =
  if fieldCount scope id == 0 then Left
    ( Syntax.problem Syntax.NotCallable span
        ("Constructor is not callable: " <> name)
    )
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

fieldCount ∷ Scope → Resolved.CtorId → Int
fieldCount scope (Resolved.CtorId index) =
  maybe' noFields count (Array.index scope.ctors index)
  where
  noFields _ = 0
  count info = Array.length info.fields
