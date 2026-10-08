module Format.Go.Lowered
  ( Scope
  , Lowered
  , Lowering
  , Several
  , leaf
  , variable
  , both
  , several
  ) where

import Prelude
import Data.Array as Array
import Data.Traversable (mapAccumL)
import Domain.IR.Internal as IR
import Domain.IR.Internal (Ty)
import Domain.Resolved (FunctionId, LocalId)
import Format.Go.Capture (Free, none, read, union)
import Format.Go.Layout (Layout)

-- What lowering one function body reads: the layout, and the function whose
-- matches are being numbered and lifted (E005).
type Scope = { tables ∷ Layout, owner ∷ FunctionId }

-- One expression's Go code, the number the next match in its function will
-- take, the top-level functions its matches were lifted to (in the
-- pre-order of their numbers), and its free locals (Format.Go.Capture).
type Lowered =
  { code ∷ String, next ∷ Int, lifted ∷ Array String, free ∷ Free }

-- Lowers an expression whose first match (if any) takes the given number.
type Lowering = Int → IR.Expr → Lowered

type Several =
  { codes ∷ Array String
  , next ∷ Int
  , lifted ∷ Array String
  , frees ∷ Array Free
  }

-- Code that contains no match and reads no local.
leaf ∷ Int → String → Lowered
leaf next code = { code, next, lifted: [], free: none }

variable ∷ Int → String → LocalId → Ty → Lowered
variable next code id ty = { code, next, lifted: [], free: read id ty }

-- Two operands, left first, joined by `render`.
both
  ∷ Lowering
  → Int
  → (String → String → String)
  → IR.Expr
  → IR.Expr
  → Lowered
both lower next render left right =
  { code: render first.code second.code
  , next: second.next
  , lifted: first.lifted <> second.lifted
  , free: union [ first.free, second.free ]
  }
  where
  first = lower next left
  second = lower first.next right

-- Left to right, so matches are numbered in source pre-order. mapAccumL
-- traverses an Array in balanced halves, so long argument lists are safe.
several ∷ Lowering → Int → Array IR.Expr → Several
several lower next expressions =
  { codes: map codeOf threaded.value
  , next: threaded.accum
  , lifted: Array.concatMap liftedOf threaded.value
  , frees: map freeOf threaded.value
  }
  where
  threaded = mapAccumL step next expressions
  step counter expression = advanced (lower counter expression)
  advanced result = { accum: result.next, value: result }
  codeOf result = result.code
  liftedOf result = result.lifted
  freeOf result = result.free
