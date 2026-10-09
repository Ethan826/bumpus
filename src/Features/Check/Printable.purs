module Features.Check.Printable (printable) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Foldable (traverse_)
import Domain.Checked.Internal as Checked
import Domain.Problem (Problem(..))
import Domain.Syntax (Diagnostic, problemAt)
import Features.Check.Functional (Functional, containsFunction)
import Features.Check.Require (Names, typeName)

printable
  ∷ ∀ r. Functional → Names r → Checked.Expr → Either Diagnostic Unit
printable holders env (Checked.Expr expression) = case expression.node of
  Checked.Print value → judge value *> recur value
  Checked.Call _ _ arguments → each arguments
  Checked.Perform _ _ _ arguments → each arguments
  Checked.Construct _ _ arguments → each arguments
  Checked.Add left right → each [ left, right ]
  Checked.Compare _ left right → each [ left, right ]
  Checked.If condition yes no → each [ condition, yes, no ]
  Checked.Match scrutinee arms → each (Array.cons scrutinee (map armBody arms))
  Checked.Apply callee arguments → each (Array.cons callee arguments)
  Checked.Lambda _ body → recur body
  Checked.Pipe left right → each [ left, right ]
  Checked.Block items value → each (Checked.blockParts items value)
  _ → Right unit
  where
  recur = printable holders env
  each = traverse_ recur
  armBody arm = arm.body
  judge value
    | containsFunction holders (Checked.typeOf value) = do
        name ← typeName env (Checked.spanOf value) (Checked.typeOf value)
        Left (problemAt (NotPrintable name) (Checked.spanOf value))
    | otherwise = Right unit
