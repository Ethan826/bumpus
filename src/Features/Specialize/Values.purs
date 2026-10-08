module Features.Specialize.Values
  ( Scope
  , Copier
  , lowered
  , typed
  , callee
  , ownerCtor
  , lambda
  ) where

import Prelude
import Data.Traversable (traverse)
import Domain.Checked.Internal as Checked
import Domain.IR.Internal as IR
import Domain.Resolved (CtorId, FunctionId)
import Domain.Syntax (Span)
import Domain.Type (Ty)
import Features.Specialize.Intern (Lowered, loweredType)
import Features.Specialize.Keys (Env, Specializing, called, ctorAt)
import Features.Specialize.Lower (lowerType)

-- One key's copy of a function: the checked tables and the key's
-- arguments, each lowered beside its interned number.
type Scope = { env ∷ Env, arguments ∷ Array Lowered }

-- Copies one checked expression (Features.Specialize.Body).
type Copier = Checked.Expr → Specializing IR.Expr

lowered ∷ Scope → Span → Ty Checked.Open → Specializing Lowered
lowered scope = lowerType scope.env scope.arguments

typed ∷ Scope → Span → Ty Checked.Open → Specializing IR.Ty
typed scope span ty = loweredType <$> lowered scope span ty

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
  traverse (lowered scope span) instantiation >>= called scope.env span id

-- A construction, partial or not, and a constructor value name the
-- constructor of their owner's copy, which is the final result of their
-- type's spine (design §7); a full construction's type is the owner.
ownerCtor ∷ Scope → Span → IR.Ty → CtorId → Specializing CtorId
ownerCtor scope span ty = ctorAt scope.env span (IR.spine ty).result

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
