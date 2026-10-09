-- Application of a function value (FN001 design §5, §13 rule 6): one
-- source application of a value `h` to j arguments is `h(a1)…(aj)`, each
-- stage an ordinary Go call, so Go calls `h(a1)` before any call inside
-- `a2` (Task 1's order checks). Applying a value to many arguments in one
-- Go function builds in about quadratic time (design §13), so beyond 64
-- arguments the chain is cut into top-level helpers of at most 64 stages,
-- numbered per owner like lifted matches. A helper takes the value reached
-- so far and the free locals its own arguments read, and evaluates each
-- argument in place, immediately before its stage: no argument runs
-- earlier than in the unsplit chain.
module Format.Go.Apply (Chain, applied, walked) where

import Prelude
import Data.Array as Array
import Data.Foldable (foldl)
import Data.Maybe (maybe)
import Data.String.Common (joinWith)
import Data.Traversable (mapAccumL)
import Domain.IR.Internal as IR
import Domain.IR.Internal (FunType, FunTypeId(..), Ty(..))
import Format.Go.Capture (Free, union)
import Format.Go.Data (functionName, goType, localName)
import Format.Go.Lowered (Lowered, Lowering, Scope, Wrapper, several)
import Format.Stack (Stack)
import Format.Stack as Stack

-- A lowered head and, only if helpers need them, the Go types of the
-- value after 0…j arguments.
type Chain = { head ∷ Lowered, types ∷ Unit → Array String }

-- What one helper (or the head) adds besides its code.
type Piece = { lifted ∷ Array String, free ∷ Free, wrappers ∷ Array Wrapper }

-- Threaded through the blocks: the code so far and the pieces, pushed
-- onto a stack and concatenated once, so the blocks cost no copy each.
type Blocks = { code ∷ String, next ∷ Int, pieces ∷ Stack Piece }

-- design §13 rule 6.
blockSize ∷ Int
blockSize = 64

applied ∷ Scope → Lowering → Chain → Array IR.Expr → Lowered
applied scope lower chain arguments
  | Array.length arguments <= blockSize = inline lower chain.head arguments
  | otherwise = blocked scope lower chain arguments

-- The types a value of type `ty` passes through when applied to `count`
-- arguments, read from the interned table by a loop.
walked ∷ Array FunType → Ty → Int → Array String
walked table ty count = map goType
  ([ ty ] <> (mapAccumL step ty (Array.replicate count unit)).value)
  where
  step current _ = advanced (result current)
  advanced next = { accum: next, value: next }
  result current = case current of
    TFun (FunTypeId index) → maybe current resultOf
      (Array.index table index)
    _ → current
  resultOf arrow = arrow.result

inline ∷ Lowering → Lowered → Array IR.Expr → Lowered
inline lower head arguments =
  { code: head.code <> joinWith "" (map parenthesized parts.codes)
  , next: parts.next
  , lifted: head.lifted <> parts.lifted
  , free: union ([ head.free ] <> parts.frees)
  , wrappers: head.wrappers <> parts.wrappers
  }
  where
  parts = several lower head.next arguments

blocked ∷ Scope → Lowering → Chain → Array IR.Expr → Lowered
blocked scope lower chain arguments =
  { code: done.code
  , next: done.next
  , lifted: Array.concatMap liftedOf pieces
  , free: union (map freeOf pieces)
  , wrappers: Array.concatMap wrappersOf pieces
  }
  where
  pieces = Array.fromFoldable done.pieces
  liftedOf piece = piece.lifted
  freeOf piece = piece.free
  wrappersOf piece = piece.wrappers
  types = chain.types unit
  starts = map (mul blockSize)
    (Array.range 0 ((Array.length arguments - 1) / blockSize))
  done = foldl (block scope lower types arguments) start starts
  start =
    { code: chain.head.code
    , next: chain.head.next
    , pieces: Stack.push
        { lifted: chain.head.lifted
        , free: chain.head.free
        , wrappers: chain.head.wrappers
        }
        Stack.empty
    }

-- One helper: its number, then its arguments' lifted functions.
block
  ∷ Scope
  → Lowering
  → Array String
  → Array IR.Expr
  → Blocks
  → Int
  → Blocks
block scope lower types arguments so first =
  { code: name <> "(" <> joinWith ", " ([ so.code ] <> map captured free)
      <> ")"
  , next: parts.next
  , pieces: Stack.push
      { lifted: [ helper ] <> parts.lifted, free, wrappers: parts.wrappers }
      so.pieces
  }
  where
  name = functionName scope.owner <> "Apply" <> show so.next
  parts = several lower (so.next + 1)
    (Array.slice first (first + blockSize) arguments)
  free = union parts.frees
  captured local = localName local.id
  parameter local = localName local.id <> " " <> goType local.ty
  typeAt position = maybe "" identity (Array.index types position)
  helper = "func " <> name <> "("
    <> joinWith ", " ([ "waxwingValue " <> typeAt first ] <> map parameter free)
    <> ") "
    <> typeAt (first + Array.length parts.codes)
    <> " {\nreturn waxwingValue"
    <> joinWith "" (map parenthesized parts.codes)
    <> "\n}\n"

parenthesized ∷ String → String
parenthesized code = "(" <> code <> ")"
