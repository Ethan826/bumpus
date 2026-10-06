module Sprig.Resolve.Pattern (resolvePattern) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (maybe, maybe')
import Sprig.Model as Syntax
import Sprig.Resolved
  ( CtorId(..)
  , CtorInfo
  , Global
  , GlobalRef(..)
  , Local
  , LocalId(..)
  , Numbered
  , Pattern(..)
  )

type Resolution = { pattern ∷ Pattern, binders ∷ Array Local }
type Fields = { patterns ∷ Array Pattern, binders ∷ Array Local }
type Binder = { name ∷ String, span ∷ Syntax.Span }

type Tables = { globals ∷ Array Global, ctors ∷ Array CtorInfo }

-- Binders take the next LocalIds in source pre-order. Constructor existence
-- and arity are checked here, in pattern pre-order.
resolvePattern
  ∷ Array Global
  → Array CtorInfo
  → Int
  → Syntax.Pattern
  → Either Syntax.Diagnostic (Numbered Resolution)
resolvePattern globals ctors next syntax = do
  resolved ← walk { globals, ctors } next syntax
  uniqueBinders (binders syntax)
  pure resolved

walk
  ∷ Tables
  → Int
  → Syntax.Pattern
  → Either Syntax.Diagnostic (Numbered Resolution)
walk tables next = case _ of
  Syntax.PWildcard span → leaf (Wildcard span)
  Syntax.PBind span name → pure (bound span name)
  Syntax.PInt span value → leaf (IntLit span value)
  Syntax.PBool span value → leaf (BoolLit span value)
  Syntax.PCtor span name fields → ctorPattern tables next span name fields
  where
  leaf pattern = pure { value: { pattern, binders: [] }, next }
  bound span name =
    { value:
        { pattern: Bind span (LocalId next)
        , binders: [ { name, id: LocalId next } ]
        }
    , next: next + 1
    }

ctorPattern
  ∷ Tables
  → Int
  → Syntax.Span
  → String
  → Array Syntax.Pattern
  → Either Syntax.Diagnostic (Numbered Resolution)
ctorPattern tables next span name fields = do
  id ← constructor tables.globals span name
  arity tables.ctors span id fields
  resolved ← Array.foldM field start fields
  pure
    { value:
        { pattern: Ctor span id resolved.value.patterns
        , binders: resolved.value.binders
        }
    , next: resolved.next
    }
  where
  start = { value: { patterns: [], binders: [] }, next }
  field acc syntax = appendField acc <$> walk tables acc.next syntax

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
    (Syntax.problem Syntax.InternalError span "Invalid constructor id")
  counted info =
    when (Array.length info.fields /= Array.length fields)
      ( Left
          (Syntax.problem Syntax.ArityMismatch span "Wrong number of fields")
      )

appendField ∷ Numbered Fields → Numbered Resolution → Numbered Fields
appendField acc resolved =
  { value:
      { patterns: Array.snoc acc.value.patterns resolved.value.pattern
      , binders: acc.value.binders <> resolved.value.binders
      }
  , next: resolved.next
  }

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
    (Syntax.problem Syntax.UnboundName span ("Unbound constructor " <> name))
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
    ( Syntax.problem Syntax.DuplicateName binder.span
        ("Duplicate binder " <> binder.name)
    )

binders ∷ Syntax.Pattern → Array Binder
binders = case _ of
  Syntax.PBind span name → [ { name, span } ]
  Syntax.PCtor _ _ fields → Array.concatMap binders fields
  _ → []
