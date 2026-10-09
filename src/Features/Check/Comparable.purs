module Features.Check.Comparable (comparable) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Foldable (traverse_)
import Domain.Checked.Internal (Open(..))
import Domain.Checked.Internal as Checked
import Domain.Problem (Problem(..), TypeName)
import Domain.Syntax (Diagnostic, Span, problemAt)
import Domain.Type (Ty(..), children)
import Features.Check.Functional (Functional, containsFunction)
import Features.Check.Require (Names, typeName)

-- Comparison is defined only at a ground type. Run on a finished body, whose
-- types are fully substituted, so a remaining variable is one the function
-- never fixes: a rigid one is not comparable; a meta (a hole) is ambiguous,
-- which keeps C001's later Ord use additive. A ground type that can hold
-- a function is not comparable either (FN001 design §3), judged last.
-- Comparisons are judged in source order (pre-order), each at its left
-- operand.
comparable
  ∷ ∀ r. Functional → Names r → Checked.Expr → Either Diagnostic Unit
comparable functions env (Checked.Expr expression) = case expression.node of
  Checked.Call _ _ arguments → traverse_ recur arguments
  Checked.Construct _ _ arguments → traverse_ recur arguments
  Checked.Add left right → traverse_ recur [ left, right ]
  Checked.Compare _ left right → judge functions env left *> traverse_ recur
    [ left, right ]
  Checked.If condition yes no → traverse_ recur [ condition, yes, no ]
  Checked.Match scrutinee arms → traverse_ recur
    (Array.cons scrutinee (map armBody arms))
  Checked.Apply callee arguments → traverse_ recur
    (Array.cons callee arguments)
  Checked.Lambda _ body → recur body
  Checked.Pipe left right → traverse_ recur [ left, right ]
  Checked.Block items value → traverse_ recur (Checked.blockParts items value)
  _ → pure unit
  where
  recur = comparable functions env
  armBody arm = arm.body

judge ∷ ∀ r. Functional → Names r → Checked.Expr → Either Diagnostic Unit
judge functions env operand =
  if Array.any rigid variables then reject NotComparable
  else if not (Array.null variables) then reject AmbiguousType
  else if containsFunction functions ty then reject NotComparable
  else pure unit
  where
  ty = Checked.typeOf operand
  span = Checked.spanOf operand
  variables = variablesOf ty
  reject problem = rejected env span ty problem

rejected
  ∷ ∀ r
  . Names r
  → Span
  → Ty Open
  → (TypeName → Problem)
  → Either Diagnostic Unit
rejected env span ty problem = do
  name ← typeName env span ty
  Left (problemAt (problem name) span)

rigid ∷ Open → Boolean
rigid = case _ of
  Rigid _ → true
  Hole _ → false

variablesOf ∷ Ty Open → Array Open
variablesOf = case _ of
  TVar variable → [ variable ]
  ty → Array.concatMap variablesOf (children ty)
