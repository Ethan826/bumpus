module Features.Specialize.Values
  ( Scope
  , Copier
  , typed
  , callee
  , ownerCtor
  , lambda
  ) where

import Prelude
import Data.Array as Array
import Data.Maybe (maybe')
import Data.Traversable (traverse)
import Domain.Checked.Internal as Checked
import Domain.IR.Internal as IR
import Domain.Resolved (CtorId(..), FunctionId)
import Domain.Syntax (Span)
import Domain.Type (Ty)
import Features.Specialize.Keys
  ( Env
  , Specializing
  , applied
  , called
  , ctorAt
  , internal
  )
import Features.Specialize.Lower (lowerType)

-- One key's copy of a function: the checked tables and the key's
-- arguments, each a number or a builtin.
type Scope = { env ∷ Env, arguments ∷ Array IR.Ty }

-- Copies one checked expression (Features.Specialize.Body).
type Copier = Checked.Expr → Specializing IR.Expr

typed ∷ Scope → Span → Ty Checked.Open → Specializing IR.Ty
typed scope = lowerType scope.env scope.arguments

-- The copy of a named function that a call or a bare reference reaches:
-- its instantiation lowered, then the callee's key. Either is an edge to
-- that copy (design §6).
callee
  ∷ Scope
  → Span
  → FunctionId
  → Checked.Instantiation
  → Specializing FunctionId
callee scope span id instantiation =
  traverse (typed scope span) instantiation >>= called scope.env span id

-- A construction, partial or not, and a constructor value name the
-- constructor of their owner's copy: the owner type at the reference's
-- instantiation, which is in the owner's variable order (design §7). The
-- reference's own type, lowered first, already created that key.
ownerCtor
  ∷ Scope
  → Span
  → CtorId
  → Checked.Instantiation
  → Specializing CtorId
ownerCtor scope span id@(CtorId index) instantiation = do
  arguments ← traverse (typed scope span) instantiation
  owner ← maybe' (internal "Invalid constructor id" span)
    (ownerType arguments)
    (Array.index scope.env.ctors index)
  ctorAt scope.env span owner id
  where
  ownerType arguments ctor = applied scope.env span ctor.owner arguments

-- A lambda's parameters keep their locals and take their types at the key;
-- a parameter has no span of its own, so the lambda's stands for it.
lambda
  ∷ Scope
  → Copier
  → Span
  → Array Checked.Param
  → Checked.Expr
  → Specializing IR.Node
lambda scope copy span parameters body = IR.Lambda
  <$> traverse parameter parameters
  <*> copy body
  where
  parameter checked = withType checked <$> typed scope span checked.ty
  withType checked ty = { local: checked.local, ty }
