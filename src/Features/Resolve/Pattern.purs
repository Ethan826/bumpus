module Features.Resolve.Pattern (resolvePattern) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (maybe, maybe')
import Data.Traversable (traverse)
import Domain.Problem (DuplicateKind(..), Problem(..), UnboundKind(..))
import Domain.Syntax as Syntax
import Domain.Resolved
  ( CtorId(..)
  , CtorInfo
  , Global
  , GlobalRef(..)
  , Local
  , LocalId
  , Pattern(..)
  )
import Features.Resolve.Fresh (Fresh, fresh, liftEither)

type Resolution = { pattern ∷ Pattern, binders ∷ Array Local }
type Binder = { name ∷ String, span ∷ Syntax.Span }

type Tables = { globals ∷ Array Global, ctors ∷ Array CtorInfo }

-- Binders take the next LocalIds in source pre-order. Constructor existence
-- and arity are checked here, in pattern pre-order.
resolvePattern
  ∷ Array Global
  → Array CtorInfo
  → Syntax.Pattern
  → Fresh Resolution
resolvePattern globals ctors syntax = do
  resolved ← walk { globals, ctors } syntax
  liftEither (uniqueBinders (binders syntax))
  pure resolved

walk ∷ Tables → Syntax.Pattern → Fresh Resolution
walk tables = case _ of
  Syntax.PWildcard span → leaf (Wildcard span)
  Syntax.PBind span name → bound span name <$> fresh
  Syntax.PInt span value → leaf (IntLit span value)
  Syntax.PBool span value → leaf (BoolLit span value)
  Syntax.PCtor span name fields → ctorPattern tables span name fields
  where
  leaf pattern = pure { pattern, binders: [] }

bound ∷ Syntax.Span → String → LocalId → Resolution
bound span name id = { pattern: Bind span id, binders: [ { name, id } ] }

ctorPattern
  ∷ Tables
  → Syntax.Span
  → String
  → Array Syntax.Pattern
  → Fresh Resolution
ctorPattern tables span name fields = do
  id ← liftEither (constructor tables.globals span name)
  liftEither (arity tables.ctors span id fields)
  resolved ← traverse (walk tables) fields
  pure
    { pattern: Ctor span id (map patternOf resolved)
    , binders: Array.concatMap bindersOf resolved
    }
  where
  patternOf resolution = resolution.pattern
  bindersOf resolution = resolution.binders

arity
  ∷ Array CtorInfo
  → Syntax.Span
  → CtorId
  → Array Syntax.Pattern
  → Either Syntax.Diagnostic Unit
arity ctors span (CtorId index) fields = maybe' missing counted
  (Array.index ctors index)
  where
  missing _ = Left
    (Syntax.problemAt (Internal "Invalid constructor id") span)
  counted info =
    when (Array.length info.fields /= Array.length fields)
      (Left (Syntax.problemAt FieldArity span))

constructor
  ∷ Array Global
  → Syntax.Span
  → String
  → Either Syntax.Diagnostic CtorId
constructor globals span name = maybe' unbound fromGlobal
  (Array.find named globals)
  where
  named global = global.name == name
  unbound _ = Left
    (Syntax.problemAt (Unbound UnboundConstructor name) span)
  fromGlobal global = case global.ref of
    CtorRef id → Right id
    FunctionRef _ → unbound unit

-- A repeated binder is never an equality test; report its first occurrence.
uniqueBinders ∷ Array Binder → Either Syntax.Diagnostic Unit
uniqueBinders found = maybe (Right unit) duplicate (Array.find repeated found)
  where
  repeated binder = Array.length (Array.filter (sameName binder) found) > 1
  sameName binder other = other.name == binder.name
  duplicate binder = Left
    (Syntax.problemAt (Duplicate DuplicateBinder binder.name) binder.span)

binders ∷ Syntax.Pattern → Array Binder
binders = case _ of
  Syntax.PBind span name → [ { name, span } ]
  Syntax.PCtor _ _ fields → Array.concatMap binders fields
  _ → []
