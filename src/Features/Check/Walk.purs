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
-- the span of the expression or pattern holding it.
foldTypes ∷ ∀ b. (b → Span → Ty Open → b) → b → Checked.Expr → b
foldTypes step found (Checked.Expr expression) = case expression.node of
  Checked.Call _ instantiation arguments → applied instantiation arguments
  Checked.Construct _ instantiation arguments → applied instantiation
    arguments
  Checked.Add left right → foldl recur own [ left, right ]
  Checked.Compare _ left right → foldl recur own [ left, right ]
  Checked.If condition yes no → foldl recur own [ condition, yes, no ]
  Checked.Match scrutinee arms → foldl arm (recur own scrutinee) arms
  _ → own
  where
  own = step found expression.span expression.ty
  recur = foldTypes step
  applied instantiation arguments =
    foldl recur (foldl (flip step expression.span) own instantiation)
      arguments
  arm reached checked = recur (foldPattern step reached checked.pattern)
    checked.body

-- The same body with `change` applied to every type `foldTypes` visits.
retype ∷ (Ty Open → Ty Open) → Checked.Expr → Checked.Expr
retype change (Checked.Expr expression) = Checked.Expr
  (expression { ty = change expression.ty, node = node expression.node })
  where
  recur = retype change
  node = case _ of
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
    leaf → leaf
  arm checked = checked
    { pattern = retypePattern change checked.pattern
    , body = recur checked.body
    }

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
