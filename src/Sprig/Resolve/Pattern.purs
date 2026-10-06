module Sprig.Resolve.Pattern (resolvePattern) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (maybe, maybe')
import Sprig.Model as Syntax
import Sprig.Resolved
  ( CtorId
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

-- Binders take the next LocalIds in source pre-order. Constructor arity is
-- checked with the expected type, since only checking has the field types.
resolvePattern
  ∷ Array Global
  → Int
  → Syntax.Pattern
  → Either Syntax.Diagnostic (Numbered Resolution)
resolvePattern globals next syntax = do
  resolved ← walk globals next syntax
  uniqueBinders (binders syntax)
  pure resolved

walk
  ∷ Array Global
  → Int
  → Syntax.Pattern
  → Either Syntax.Diagnostic (Numbered Resolution)
walk globals next = case _ of
  Syntax.PWildcard span → leaf (Wildcard span)
  Syntax.PBind span name → pure (bound span name)
  Syntax.PInt span value → leaf (IntLit span value)
  Syntax.PBool span value → leaf (BoolLit span value)
  Syntax.PCtor span name fields → ctorPattern globals next span name fields
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
  ∷ Array Global
  → Int
  → Syntax.Span
  → String
  → Array Syntax.Pattern
  → Either Syntax.Diagnostic (Numbered Resolution)
ctorPattern globals next span name fields = do
  id ← constructor globals span name
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
  field acc syntax = appendField acc <$> walk globals acc.next syntax

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
