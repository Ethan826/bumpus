module Format.Go.Lowered
  ( Scope
  , Lowered
  , Lowering
  , Several
  , leaf
  , both
  , several
  ) where

import Prelude
import Data.Array as Array
import Data.Traversable (mapAccumL)
import Domain.IR.Internal as IR
import Domain.Resolved (FunctionId)
import Format.Go.Layout (Layout)

-- What lowering one function body reads: the layout, and the function whose
-- matches are being numbered and lifted (E005).
type Scope = { tables ∷ Layout, owner ∷ FunctionId }

-- One expression's Go code, the number the next match in its function will
-- take, and the top-level functions its matches were lifted to, in the
-- pre-order of their numbers.
type Lowered = { code ∷ String, next ∷ Int, lifted ∷ Array String }

-- Lowers an expression whose first match (if any) takes the given number.
type Lowering = Int → IR.Expr → Lowered

type Several = { codes ∷ Array String, next ∷ Int, lifted ∷ Array String }

-- Code that contains no match.
leaf ∷ Int → String → Lowered
leaf next code = { code, next, lifted: [] }

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
  }
  where
  threaded = mapAccumL step next expressions
  step counter expression = advanced (lower counter expression)
  advanced result = { accum: result.next, value: result }
  codeOf result = result.code
  liftedOf result = result.lifted
