module Features.Check.Require
  ( module Features.Check.TypeName
  , Requiring
  , require
  , expectType
  , bounded
  , tooDeepAt
  ) where

import Prelude
import Data.Either (Either(..), either)
import Data.Maybe (Maybe(..))
import Domain.Checked.Internal (Open(..))
import Domain.Checked.Internal as Checked
import Domain.Problem (Problem(..))
import Domain.Resolved (EffectInfo)
import Domain.Row (Row(..), isPure)
import Features.Check.RowName (labelName, rowConflict)
import Features.Check.TypeName (Names, typeName)
import Domain.Syntax (Diagnostic, Span, problemAt)
import Domain.Type (Ty(..))
import Features.Check.Hint (Declared, hinted)
import Features.Check.Scheme (State, flexible, opened, resolved, tooDeep)
import Features.Check.Unify (Failure(..), inferredTypeLimit, unify)

-- What a diagnostic needs to name a type: the declared types, and the
-- enclosing function's variables (`VarId i` is the i-th).

-- What `require` needs: names for its message, declarations for its hint.
type Requiring r = Names (effects ∷ Array EffectInfo | Declared r)

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
-- the unifier's own pair is only the innermost one that differs. A row
-- failure is reported so too until rows are written (FX001 Task 4).
expectType
  ∷ ∀ r
  . Names (effects ∷ Array EffectInfo | r)
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
    Occurs meta whole → reported InfiniteType (TVar (Hole meta)) (opened whole)
    TooDeep → tooDeepAt span
    Mismatch _ _ → mismatched unit
    RowMissing label row → rowFailure label row
    RowExtra label → rowFailure label (Row [] Nothing)
    RowSharedTail left right → rowConflict env span left right
    RowMismatch _ _ → mismatched unit
    RowOccurs _ _ → mismatched unit
  rowFailure label row = do
    name ← labelName env span label
    if isPure row then Left (problemAt (MustBePure name) span)
    else Left (problemAt (EffectNotAllowed "This function" name) span)
  -- A function: `where` bindings are strict, and this resolves both types.
  mismatched _ = reported TypeMismatch (resolved state.subst expected)
    (resolved state.subst actual)
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
