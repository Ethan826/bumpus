module Features.Check.Require
  ( Names
  , Requiring
  , typeName
  , require
  , expectType
  , bounded
  , tooDeepAt
  ) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..), either)
import Data.Maybe (maybe')
import Data.Traversable (traverse)
import Domain.Checked.Internal (Open(..))
import Domain.Checked.Internal as Checked
import Domain.Problem (Problem(..), TypeName(..))
import Domain.Resolved (TypeInfo)
import Domain.Syntax (Diagnostic, Span, problemAt)
import Domain.Type (Ty(..), TypeId(..), VarId(..), spine)
import Features.Check.Hint (Declared, hinted)
import Features.Check.Scheme (State, flexible, opened, resolved, tooDeep)
import Features.Check.Unify (Failure(..), inferredTypeLimit, unify)

-- What a diagnostic needs to name a type: the declared types, and the
-- enclosing function's variables (`VarId i` is the i-th).
type Names r = { types ∷ Array TypeInfo, variables ∷ Array String | r }

-- What `require` needs: names for its message, declarations for its hint.
type Requiring r = Names (Declared r)

-- The expression's type must unify with the expected one. A mismatch may
-- gain the under-application hint (Features.Check.Hint).
require
  ∷ ∀ r
  . Requiring r
  → State
  → Ty Open
  → Checked.Expr
  → Either Diagnostic State
require env state expected actual = either hint Right
  ( expectType env state expected (Checked.typeOf actual)
      (Checked.spanOf actual)
  )
  where
  hint = Left <<< hinted env state expected actual

-- A failure names the whole expected and found types, resolved under the
-- substitution before this comparison, as monomorphic checking always did;
-- the unifier's own pair is only the innermost one that differs.
expectType
  ∷ ∀ r
  . Names r
  → State
  → Ty Open
  → Ty Open
  → Span
  → Either Diagnostic State
-- Both operands are bounded first, since unifying recurses over them.
expectType env state expected actual span = do
  bounded state expected span
  bounded state actual span
  either failed bound (unify state.subst (flexible expected) (flexible actual))
  where
  bound subst = Right (state { subst = subst })
  failed = case _ of
    Mismatch _ _ → reported TypeMismatch (resolved state.subst expected)
      (resolved state.subst actual)
    Occurs meta whole → reported InfiniteType (TVar (Hole meta)) (opened whole)
    TooDeep → tooDeepAt span
  reported problem one other = do
    first ← typeName env span one
    second ← typeName env span other
    Left (problemAt (problem first second) span)

-- A type, resolved under the state, may be at most `inferredTypeLimit`
-- deep; past it is E_NESTING at `span`, before anything recurses on it.
bounded ∷ State → Ty Open → Span → Either Diagnostic Unit
bounded state ty span =
  if tooDeep state.subst ty then tooDeepAt span else Right unit

tooDeepAt ∷ ∀ a. Span → Either Diagnostic a
tooDeepAt span = Left (problemAt (TypeTooDeep inferredTypeLimit) span)

-- Names appear only in diagnostics, never in generated Go. An arrow's
-- spine is named parameter by parameter, by a loop (Array.foldr).
typeName ∷ ∀ r. Names r → Span → Ty Open → Either Diagnostic TypeName
typeName env span = case _ of
  TInt → Right IntName
  TBool → Right BoolName
  TData (TypeId index) arguments → maybe' missing (named arguments)
    (Array.index env.types index)
  TVar (Rigid (VarId index)) → maybe' unnamed (Right <<< VariableName)
    (Array.index env.variables index)
  TVar (Hole _) → Right HoleName
  arrow@(TFun _ _) → arrowName (spine arrow)
  where
  missing _ = Left (problemAt (Internal "Invalid resolved type") span)
  unnamed _ = Left (problemAt (Internal "Unnamed type variable") span)
  named arguments info
    | Array.null arguments = Right (DataName info.name)
    | otherwise = AppliedName info.name <$> traverse (typeName env span)
        arguments
  arrowName found = curried <$> traverse (typeName env span) found.parameters
    <*> typeName env span found.result
  curried parameters result = Array.foldr FunctionName result parameters
