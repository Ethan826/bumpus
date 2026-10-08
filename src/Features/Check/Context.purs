module Features.Check.Context (CheckEnv, Infer) where

import Data.Either (Either)
import Domain.Checked.Internal as Checked
import Domain.Resolved as Resolved
import Domain.Syntax (Diagnostic)
import Features.Check.Scheme (State, Threaded)

-- What checking a call, an application or a lambda needs: the
-- declarations, and the enclosing function's variables' names. The row is
-- open so Features.Check.Infer can pass its own environment through.
type CheckEnv r =
  { functions ∷ Array Resolved.FunctionDecl
  , types ∷ Array Resolved.TypeInfo
  , ctors ∷ Array Resolved.CtorInfo
  , variables ∷ Array String
  | r
  }

-- Features.Check.Infer's `infer`, passed in by the modules it imports
-- (none may import Infer, which imports them).
type Infer r =
  CheckEnv r
  → State
  → Resolved.Expr
  → Either Diagnostic (Threaded Checked.Expr)
