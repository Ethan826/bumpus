module Features.Specialize.Unlowered (reject) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (Maybe(..), maybe')
import Domain.IR.Internal as IR
import Domain.Problem (Problem(..))
import Domain.Syntax (Diagnostic, Span, problemAt)

-- Temporary, FN001 Task 5 only (Task 6 deletes it with its CLI test):
-- Specialize copies function values and types, which Format.Go cannot
-- lower yet, so the CLI stops every program that holds one with
-- E_INTERNAL `unlowered function`. Reported at the first constructor with
-- an arrow field, else in output order at the first function whose
-- signature holds an arrow (its declaration) or whose body holds a new node
-- or an arrow-typed expression (that expression, in pre-order). A program
-- that holds none passes unchanged.
reject ∷ IR.Program → Either Diagnostic IR.Program
reject program@(IR.Program tables) = maybe' accepted rejected
  (maybe' inFunctions Just (Array.findMap ctorSpan tables.ctors))
  where
  inFunctions _ = Array.findMap functionSpan tables.functions
  accepted _ = Right program
  rejected span = Left (problemAt (Internal "unlowered function") span)

ctorSpan ∷ IR.CtorInfo → Maybe Span
ctorSpan ctor
  | Array.any isArrow ctor.fields = Just ctor.span
  | otherwise = Nothing

functionSpan ∷ IR.FunctionDecl → Maybe Span
functionSpan function
  | Array.any isArrow (Array.snoc function.parameters function.result) =
      Just function.span
  | otherwise = expressionSpan function.body

expressionSpan ∷ IR.Expr → Maybe Span
expressionSpan (IR.Expr expression)
  | isArrow expression.ty || isNew expression.node = Just expression.span
  | otherwise = Array.findMap expressionSpan (parts expression.node)

isArrow ∷ IR.Ty → Boolean
isArrow = case _ of
  IR.TFun _ → true
  _ → false

isNew ∷ IR.Node → Boolean
isNew = case _ of
  IR.FunctionRef _ → true
  IR.CtorRef _ → true
  IR.Apply _ _ → true
  IR.Lambda _ _ → true
  IR.Pipe _ _ → true
  _ → false

-- The subexpressions of a node that is not new, in pre-order.
parts ∷ IR.Node → Array IR.Expr
parts = case _ of
  IR.Call _ arguments → arguments
  IR.Construct _ arguments → arguments
  IR.Add left right → [ left, right ]
  IR.Compare _ left right → [ left, right ]
  IR.If condition yes no → [ condition, yes, no ]
  IR.Match scrutinee arms → Array.cons scrutinee (map armBody arms)
  _ → []
  where
  armBody arm = arm.body
