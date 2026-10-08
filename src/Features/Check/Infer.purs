module Features.Check.Infer (Env, infer) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (maybe')
import Domain.Checked.Internal (Open)
import Domain.Checked.Internal as Checked
import Domain.Problem (Problem(..))
import Domain.Resolved (Ty(..))
import Domain.Resolved as Resolved
import Domain.Syntax (Diagnostic, Operator, Span, problemAt)
import Features.Check.Arms (checkMatch)
import Features.Check.Call (checkCall, checkConstruct)
import Features.Check.Match (Typed)
import Features.Check.Require (bounded, require)
import Features.Check.Scheme (State, Threaded)

type Env =
  { functions ∷ Array Resolved.FunctionDecl
  , types ∷ Array Resolved.TypeInfo
  , ctors ∷ Array Resolved.CtorInfo
  , variables ∷ Array String
  , locals ∷ Array Typed
  }

type Inferred = Either Diagnostic (Threaded Checked.Expr)

-- Every expression's type is bounded once built (ruling R7), so the
-- expression reported is the first, in checking order, whose type would
-- exceed the limit.
infer ∷ Env → State → Resolved.Expr → Inferred
infer env state expression = do
  inferred ← inferNode env state expression
  bounded inferred.state (Checked.typeOf inferred.value)
    (Checked.spanOf inferred.value)
  pure inferred

-- Every type equality is a unification, in the order monomorphic checking
-- compared types, so a monomorphic program's first error is unchanged.
-- Functions, lambdas and pipes are typed from FN001 Task 4. A flat
-- exhaustive dispatch (BACKLOG E003).
inferNode ∷ Env → State → Resolved.Expr → Inferred
inferNode env state expression = case expression of
  Resolved.Integer span value → typed state span TInt (Checked.Integer value)
  Resolved.Boolean span value → typed state span TBool
    (Checked.Boolean value)
  Resolved.Local span id → checkLocal env state span id
  Resolved.Call span id arguments → checkCall infer env state span id
    arguments
  Resolved.Construct span id arguments → checkConstruct infer env state span
    id
    arguments
  Resolved.Add span left right → checkAddition env state span left right
  Resolved.Compare span operator left right → checkComparison env state
    { span, operator }
    left
    right
  Resolved.If span condition yes no → checkConditional env state span
    condition
    { yes, no }
  Resolved.Match span scrutinee arms → checkMatch infer env state span
    scrutinee
    arms
  Resolved.Lambda span _ _ → unchecked span
  Resolved.Apply span _ _ → unchecked span
  Resolved.Pipe span _ _ → unchecked span

unchecked ∷ Span → Inferred
unchecked = Left <<< problemAt (Internal "unchecked function")

typed ∷ State → Span → Ty Open → Checked.Node → Inferred
typed state span ty node = pure
  { value: Checked.Expr { ty, span, node }, state }

checkAddition
  ∷ Env → State → Span → Resolved.Expr → Resolved.Expr → Inferred
checkAddition env state span left right = do
  first ← infer env state left
  second ← infer env first.state right
  added ← require env second.state TInt first.value
  checked ← require env added TInt second.value
  typed checked span TInt (Checked.Add first.value second.value)

checkComparison
  ∷ Env
  → State
  → { span ∷ Span, operator ∷ Operator }
  → Resolved.Expr
  → Resolved.Expr
  → Inferred
checkComparison env state at left right = do
  first ← infer env state left
  second ← infer env first.state right
  checked ← require env second.state (Checked.typeOf first.value)
    second.value
  typed checked at.span TBool
    (Checked.Compare at.operator first.value second.value)

-- The else branch is checked against the then branch's type.
checkConditional
  ∷ Env
  → State
  → Span
  → Resolved.Expr
  → { yes ∷ Resolved.Expr, no ∷ Resolved.Expr }
  → Inferred
checkConditional env state span condition branches = do
  predicate ← infer env state condition
  tested ← require env predicate.state TBool predicate.value
  first ← infer env tested branches.yes
  second ← infer env first.state branches.no
  checked ← require env second.state (Checked.typeOf first.value)
    second.value
  typed checked span (Checked.typeOf first.value)
    (Checked.If predicate.value first.value second.value)

checkLocal ∷ Env → State → Span → Resolved.LocalId → Inferred
checkLocal env state span id = maybe' missing found
  (Array.find named env.locals)
  where
  missing _ = Left (problemAt (Internal "Invalid resolved local") span)
  found local = typed state span local.ty (Checked.Local id)
  named local = local.id == id
