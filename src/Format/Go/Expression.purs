module Format.Go.Expression (expression) where

import Prelude
import Data.Array as Array
import Data.String.Common (joinWith)
import Domain.IR.Internal as IR
import Domain.Resolved (Ty)
import Format.Go.Compare (comparison)
import Format.Go.Data
  ( boolean
  , ctorName
  , functionName
  , goType
  , integer
  , localName
  )
import Format.Go.Capture (union)
import Format.Go.Lowered
  ( Lowered
  , Scope
  , Several
  , both
  , leaf
  , several
  , variable
  )
import Format.Go.Match (lowerMatch)

-- `next` is the number the first match met in pre-order will take; each
-- match becomes its own top-level function (Format.Go.Match).
expression ∷ Scope → Int → IR.Expr → Lowered
expression scope next (IR.Expr term) = case term.node of
  IR.Integer value → leaf next (integer value)
  IR.Boolean value → leaf next (boolean value)
  IR.Local id → variable next (localName id) id term.ty
  IR.Call id arguments → joined (call (functionName id)) (each arguments)
  IR.Construct id arguments → joined (call (ctorName id)) (each arguments)
  IR.Add left right → pair addition left right
  IR.Compare operator left right →
    pair (comparison operator (IR.typeOf left)) left right
  IR.If condition yes no →
    joined (conditional term.ty) (each [ condition, yes, no ])
  IR.Match scrutinee arms → lowerMatch scope lower next term.ty scrutinee arms
  where
  lower = expression scope
  each = several lower next
  pair = both lower next

joined ∷ (Array String → String) → Several → Lowered
joined render parts =
  { code: render parts.codes
  , next: parts.next
  , lifted: parts.lifted
  , free: union parts.frees
  }

call ∷ String → Array String → String
call name arguments = name <> "(" <> joinWith ", " arguments <> ")"

addition ∷ String → String → String
addition left right = call "bumpusAdd" [ left, right ]

-- `if` keeps its immediately invoked closure; nested `if` branches build
-- at the nesting limit (test/depth.test.mjs), unlike nested match closures.
conditional ∷ Ty → Array String → String
conditional ty codes = joinWith "" (Array.zipWith append pieces codes)
  <> " }()"
  where
  pieces = [ "func() " <> goType ty <> " { if ", " { return ", " }; return " ]
