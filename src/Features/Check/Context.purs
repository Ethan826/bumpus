module Features.Check.Context (CheckEnv, Infer, Locals, bindAll) where

import Data.Either (Either)
import Data.Foldable (foldl)
import Data.Map (Map)
import Data.Map as Map
import Domain.Checked.Internal (Open)
import Domain.Checked.Internal as Checked
import Domain.Resolved (LocalId)
import Domain.Resolved as Resolved
import Domain.Syntax (Diagnostic, Span)
import Domain.Type (Ty, TyRow)
import Features.Check.Scheme (Site, State, Threaded)

-- The type of each local in scope. LocalIds are unique per function, so
-- a map by id needs no shadowing rule, and a block of 20,000 lets costs
-- no scan per lookup (FX001).
type Locals = Map LocalId (Ty Open)

-- What checking a call, an application or a lambda needs: the
-- declarations, and the enclosing function's variables' names. The row is
-- open so Features.Check.Infer can pass its own environment through.
type CheckEnv r =
  { current ∷ TyRow Open
  , sites ∷ Array Site
  , functionName ∷ String
  , functionSpan ∷ Span
  , effects ∷ Array Resolved.EffectInfo
  , functions ∷ Array Resolved.FunctionDecl
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

-- The locals with these added.
bindAll ∷ Array { id ∷ LocalId, ty ∷ Ty Open } → Locals → Locals
bindAll added locals = foldl bound locals added
  where
  bound found local = Map.insert local.id local.ty found
