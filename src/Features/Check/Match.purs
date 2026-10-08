module Features.Check.Match
  ( Typed
  , Matched
  , PatternEnv
  , checkPattern
  , patternAgainst
  ) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (maybe')
import Domain.Checked.Internal (Open)
import Domain.Checked.Internal as Checked
import Domain.Problem (Problem(..))
import Domain.Syntax (Diagnostic, Span, problemAt)
import Domain.Resolved
  ( CtorId(..)
  , CtorInfo
  , LocalId
  , Tables
  , Ty(..)
  , TypeId(..)
  , TypeInfo
  )
import Domain.Resolved as Resolved
import Features.Check.Require (expectType)
import Features.Check.Scheme
  ( Scheme
  , State
  , Threaded
  , at
  , instantiate
  , start
  , threadAll
  )

type Typed = { id ∷ LocalId, ty ∷ Ty Open }

type Matched = { pattern ∷ Checked.Pattern, locals ∷ Array Typed }

type PatternEnv r =
  { types ∷ Array TypeInfo
  , ctors ∷ Array CtorInfo
  , variables ∷ Array String
  | r
  }

-- Test seam: test/diagnostics.test.mjs calls this with bare tables to pin
-- the constructor-arity guard. One pattern from a fresh state, outside any
-- function's variables; checking itself uses `patternAgainst`.
checkPattern
  ∷ Tables → Ty Open → Resolved.Pattern → Either Diagnostic Matched
checkPattern tables expected pattern = valueOf <$> patternAgainst env start
  expected
  pattern
  where
  env = { types: tables.types, ctors: tables.ctors, variables: [] }
  valueOf threaded = threaded.value

-- Patterns are checked top-down against the scrutinee's type. On a rigid
-- variable only `_` and binders fit: anything else fails to unify.
patternAgainst
  ∷ ∀ r
  . PatternEnv r
  → State
  → Ty Open
  → Resolved.Pattern
  → Either Diagnostic (Threaded Matched)
patternAgainst env state expected = case _ of
  Resolved.Wildcard span → leaf state span Checked.Wildcard []
  Resolved.Bind span id → leaf state span (Checked.Bind id)
    [ { id, ty: expected } ]
  Resolved.IntLit span value → literal TInt span (Checked.IntLit value)
  Resolved.BoolLit span value → literal TBool span (Checked.BoolLit value)
  Resolved.Ctor span id fields → checkCtor env state expected span id fields
  where
  leaf reached span shape locals = pure
    { value:
        { pattern: Checked.Pattern { ty: expected, span, shape }, locals }
    , state: reached
    }
  literal actual span shape = do
    reached ← expectType env state expected actual span
    leaf reached span shape []

-- Resolution has already checked the constructor's arity, so a field count
-- that disagrees with the table is a compiler bug, not a truncation.
checkCtor
  ∷ ∀ r
  . PatternEnv r
  → State
  → Ty Open
  → Span
  → CtorId
  → Array Resolved.Pattern
  → Either Diagnostic (Threaded Matched)
checkCtor env state expected span id@(CtorId index) fields = maybe' missing
  found
  (Array.index env.ctors index)
  where
  missing _ = Left
    (problemAt (Internal "Invalid resolved constructor") span)
  found ctor = do
    when (Array.length ctor.fields /= Array.length fields) (Left arityBug)
    owner ← ownerOf env span ctor.owner
    matchCtor env (instantiate owner.parameters state) expected span id
      { ctor, fields }
  arityBug = problemAt (Internal "Resolved constructor arity mismatch") span

matchCtor
  ∷ ∀ r
  . PatternEnv r
  → Threaded Scheme
  → Ty Open
  → Span
  → CtorId
  → { ctor ∷ CtorInfo, fields ∷ Array Resolved.Pattern }
  → Either Diagnostic (Threaded Matched)
matchCtor env scheme expected span id use = do
  reached ← expectType env scheme.state expected
    (TData use.ctor.owner scheme.value.arguments)
    span
  checked ← fieldsAgainst env reached
    (map (at scheme.value) use.ctor.fields)
    use.fields
  pure
    { value:
        { pattern: Checked.Pattern
            { ty: expected
            , span
            , shape: Checked.Ctor id (map patternOf checked.value)
            }
        , locals: Array.concatMap localsOf checked.value
        }
    , state: checked.state
    }
  where
  patternOf matched = matched.pattern
  localsOf matched = matched.locals

-- Each field pattern against its instantiated field type, left to right.
fieldsAgainst
  ∷ ∀ r
  . PatternEnv r
  → State
  → Array (Ty Open)
  → Array Resolved.Pattern
  → Either Diagnostic (Threaded (Array Matched))
fieldsAgainst env state types patterns = threadAll checkField state
  (Array.zipWith fieldPair types patterns)
  where
  fieldPair ty pattern = { ty, pattern }
  checkField reached field = patternAgainst env reached field.ty field.pattern

ownerOf
  ∷ ∀ r. PatternEnv r → Span → TypeId → Either Diagnostic TypeInfo
ownerOf env span (TypeId index) = maybe' missing Right
  (Array.index env.types index)
  where
  missing _ = Left (problemAt (Internal "Invalid resolved type") span)
