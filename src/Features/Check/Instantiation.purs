module Features.Check.Instantiation (instantiationRule) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Foldable (foldl, traverse_)
import Data.Maybe (maybe')
import Data.Set as Set
import Domain.Checked.Internal (Instantiation, Open(..))
import Domain.Checked.Internal as Checked
import Domain.Problem (Problem(..))
import Domain.Resolved (FunctionId(..))
import Domain.Syntax (Diagnostic, Span, problemAt)
import Features.Check.Components (components)
import Features.Check.Nested (admissible, nestedTypes)

-- Design §4.1: specialization stays finite when, at every reference
-- inside a strongly connected component, each type argument is a bare
-- variable of the referrer or ground. Types are judged first, in
-- declaration order; then each function's calls, in pre-order. A body's
-- types are fully substituted by now, so a hole is final and counts as
-- ground: specialization fixes it to one ground type.
instantiationRule ∷ Checked.Program → Either Diagnostic Unit
instantiationRule checked@(Checked.Program program) = do
  nestedTypes checked
  component ← components (map callees program.functions)
  traverse_ (judgeFunction component) program.functions
  where
  judgeFunction component function = foldCalls
    (judgeCall (context component function.id))
    (Right unit)
    function.body
  context component (FunctionId caller) =
    { functions: program.functions, component, caller }

-- Each callee once; edges need no multiplicity.
callees ∷ Checked.FunctionDecl → Array Int
callees function = Set.toUnfoldable
  (foldCalls insert Set.empty function.body)
  where
  insert found _ (FunctionId callee) _ = Set.insert callee found

-- What judging one function's calls needs: every function, each one's
-- component, and the caller's index.
type Context =
  { functions ∷ Array Checked.FunctionDecl
  , component ∷ Array Int
  , caller ∷ Int
  }

judgeCall
  ∷ Context
  → Either Diagnostic Unit
  → Span
  → FunctionId
  → Instantiation
  → Either Diagnostic Unit
judgeCall context judged span (FunctionId callee) instantiation =
  judged *> verdict
  where
  inside = Array.index context.component context.caller
    == Array.index context.component callee
  verdict
    | inside && not (Array.all (admissible rigid) instantiation) =
        maybe' missing reject (Array.index context.functions callee)
    | otherwise = Right unit
  reject function = Left (problemAt (PolymorphicRecursion function.name) span)
  missing _ = Left (problemAt (Internal "Invalid function id") span)

-- Every reference to a named function in a checked body, in pre-order: a
-- call before its arguments, a scrutinee before its arms, an applied
-- function before its arguments. A bare reference is an edge exactly as a
-- call is, and a lambda's body belongs to its enclosing function, so
-- references at any depth inside lambdas count (design §6, FN001 Task 5).
-- A constructor, called or bare, is no edge: it has no body, so it is in
-- no component with a function, as for calls in P001. Applying a local
-- creates no edge.
foldCalls
  ∷ ∀ b
  . (b → Span → FunctionId → Instantiation → b)
  → b
  → Checked.Expr
  → b
foldCalls step found (Checked.Expr expression) = case expression.node of
  Checked.Call id instantiation arguments → foldl recur
    (step found expression.span id instantiation)
    arguments
  Checked.Construct _ _ arguments → foldl recur found arguments
  Checked.Add left right → foldl recur found [ left, right ]
  Checked.Compare _ left right → foldl recur found [ left, right ]
  Checked.If condition yes no → foldl recur found [ condition, yes, no ]
  Checked.Match scrutinee arms → foldl recur found
    (Array.cons scrutinee (map armBody arms))
  Checked.Apply callee arguments → foldl recur found
    (Array.cons callee arguments)
  Checked.Pipe left right → foldl recur found [ left, right ]
  Checked.FunctionRef id instantiation →
    step found expression.span id instantiation
  Checked.Lambda _ body → recur found body
  Checked.Print value → recur found value
  Checked.Perform _ _ _ arguments → foldl recur found arguments
  Checked.Block items value → foldl recur found
    (Checked.blockParts items value)
  _ → found
  where
  recur = foldCalls step
  armBody arm = arm.body

rigid ∷ Open → Boolean
rigid = case _ of
  Rigid _ → true
  Hole _ → false
