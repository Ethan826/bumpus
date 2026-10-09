module Features.Check.Walk (foldTypes, retype) where

import Prelude
import Data.Foldable (foldl)
import Domain.Checked.Internal (Open)
import Domain.Checked.Internal as Checked
import Domain.Syntax (Span)
import Domain.Type (Ty)

-- Every type a checked body carries, in pre-order: an expression's type,
-- then its instantiation, then its parts left to right; an arm's pattern
-- before its body; a pattern's type before its fields. Each type comes with
-- the span of the expression or pattern holding it. A lambda's parameter
-- types come before its body, with the lambda's span. A block's items come
-- in order, then its value. A flat exhaustive dispatch (BACKLOG E003).
foldTypes ∷ ∀ b. (b → Span → Ty Open → b) → b → Checked.Expr → b
foldTypes step found (Checked.Expr expression) = case expression.node of
  Checked.FunctionRef _ instantiation → applied instantiation []
  Checked.CtorRef _ instantiation → applied instantiation []
  Checked.Call _ instantiation arguments → applied instantiation arguments
  Checked.Construct _ instantiation arguments → applied instantiation
    arguments
  Checked.Apply callee arguments → foldl recur (recur own callee) arguments
  Checked.Lambda parameters body → recur (foldl parameter own parameters)
    body
  Checked.Pipe left right → foldl recur own [ left, right ]
  Checked.Add left right → foldl recur own [ left, right ]
  Checked.Compare _ left right → foldl recur own [ left, right ]
  Checked.If condition yes no → foldl recur own [ condition, yes, no ]
  Checked.Match scrutinee arms → foldl arm (recur own scrutinee) arms
  Checked.Print value → recur own value
  Checked.OperationRef _ _ instantiation → applied instantiation []
  Checked.Perform _ _ instantiation arguments → applied instantiation arguments
  Checked.Handler _ instantiation clauses → foldl handlerClause
    (foldl (flip step expression.span) own instantiation)
    clauses
  Checked.With handler body → foldl recur own [ handler, body ]
  Checked.Handle body clauses → foldl failureClause (recur own body) clauses
  Checked.Fail value → recur own value
  Checked.Block items value → foldl recur own (Checked.blockParts items value)
  _ → own
  where
  own = step found expression.span expression.ty
  recur = foldTypes step
  applied instantiation arguments =
    foldl recur (foldl (flip step expression.span) own instantiation)
      arguments
  parameter reached declared = step reached expression.span declared.ty
  arm reached checked = recur (foldPattern step reached checked.pattern)
    checked.body
  handlerClause reached clause = foldl parameter
    (recur reached clause.body)
    clause.parameters
  failureClause reached clause = recur
    (step reached clause.span clause.payload)
    clause.body

-- The same body with `change` applied to every type `foldTypes` visits.
retype ∷ (Ty Open → Ty Open) → Checked.Expr → Checked.Expr
retype change (Checked.Expr expression) = Checked.Expr
  (expression { ty = change expression.ty, node = node expression.node })
  where
  recur = retype change
  node = case _ of
    Checked.FunctionRef id instantiation → Checked.FunctionRef id
      (map change instantiation)
    Checked.CtorRef id instantiation → Checked.CtorRef id
      (map change instantiation)
    Checked.Call id instantiation arguments → Checked.Call id
      (map change instantiation)
      (map recur arguments)
    Checked.Construct id instantiation arguments → Checked.Construct id
      (map change instantiation)
      (map recur arguments)
    Checked.Add left right → Checked.Add (recur left) (recur right)
    Checked.Compare operator left right → Checked.Compare operator
      (recur left)
      (recur right)
    Checked.If condition yes no → Checked.If (recur condition) (recur yes)
      (recur no)
    Checked.Match scrutinee arms → Checked.Match (recur scrutinee)
      (map arm arms)
    Checked.Apply callee arguments → Checked.Apply (recur callee)
      (map recur arguments)
    Checked.Lambda parameters body → Checked.Lambda (map parameter parameters)
      (recur body)
    Checked.Pipe left right → Checked.Pipe (recur left) (recur right)
    Checked.Print value → Checked.Print (recur value)
    Checked.OperationRef effect index instantiation →
      Checked.OperationRef effect index (map change instantiation)
    Checked.Perform effect index instantiation arguments →
      Checked.Perform effect index (map change instantiation)
        (map recur arguments)
    Checked.Handler effect instantiation clauses → Checked.Handler effect
      (map change instantiation)
      (map handlerClause clauses)
    Checked.With handler body → Checked.With (recur handler) (recur body)
    Checked.Handle body clauses → Checked.Handle (recur body)
      (map failureClause clauses)
    Checked.Fail value → Checked.Fail (recur value)
    Checked.Block items value → Checked.Block (map item items) (recur value)
    leaf → leaf
  parameter declared = declared { ty = change declared.ty }
  item = case _ of
    Checked.Let local value → Checked.Let local (recur value)
    Checked.Discard value → Checked.Discard (recur value)
  arm checked = checked
    { pattern = retypePattern change checked.pattern
    , body = recur checked.body
    }
  handlerClause clause = clause
    { parameters = map parameter clause.parameters, body = recur clause.body }
  failureClause clause = clause
    { payload = change clause.payload, body = recur clause.body }

foldPattern ∷ ∀ b. (b → Span → Ty Open → b) → b → Checked.Pattern → b
foldPattern step found (Checked.Pattern pattern) = case pattern.shape of
  Checked.Ctor _ fields → foldl (foldPattern step) own fields
  _ → own
  where
  own = step found pattern.span pattern.ty

retypePattern ∷ (Ty Open → Ty Open) → Checked.Pattern → Checked.Pattern
retypePattern change (Checked.Pattern pattern) = Checked.Pattern
  (pattern { ty = change pattern.ty, shape = shape pattern.shape })
  where
  shape = case _ of
    Checked.Ctor id fields → Checked.Ctor id
      (map (retypePattern change) fields)
    leaf → leaf
