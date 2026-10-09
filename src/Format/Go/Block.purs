-- Blocks (FX001 design §4). Each block is lifted, as a match is (E005),
-- to a top-level function of the locals its items and value read but do
-- not bind (ascending LocalId, Format.Go.Capture). The k-th lifted
-- function of waxwingFn{f}, numbered in pre-order with the block before its
-- items, sharing the counter with matches, lambdas, pipes and application
-- helpers, is waxwingFn{f}Block{k}. Its body runs the items in order, a
-- `let` as a typed `var` (also discarded, so Go never reports an unused
-- variable), `let _` and discarded items as `_ = e`, and returns the
-- value. The `var` is typed because an arity-one function value is the
-- lifted function itself, whose Go type is unnamed.
module Format.Go.Block (lowerBlock) where

import Prelude
import Data.Array as Array
import Data.Maybe (Maybe(..), fromMaybe)
import Data.String.Common (joinWith)
import Domain.IR.Internal as IR
import Domain.IR.Internal (Ty)
import Domain.Resolved (LocalId)
import Format.Go.Capture (Captured, union, withoutAll)
import Format.Go.Data (functionName, goType, localName)
import Format.Go.Lowered (Lowered, Lowering, Scope, several)

lowerBlock
  ∷ Scope → Lowering → Int → Ty → Array IR.Item → IR.Expr → Lowered
lowerBlock scope lower next result items value =
  { code: name <> "(" <> joinWith ", " (map capturedName captured) <> ")"
  , next: parts.next
  , lifted: [ lifted ] <> parts.lifted
  , free: captured
  , wrappers: parts.wrappers
  }
  where
  name = functionName scope.owner <> "Block" <> show next
  parts = several lower (next + 1) (IR.blockParts items value)
  captured = withoutAll (Array.mapMaybe letLocal items) (union parts.frees)
  capturedName local = localName local.id
  lifted = blockFunction name captured result
    (Array.zipWith statement items parts.codes)
    (fromMaybe "" (Array.last parts.codes))

blockFunction ∷ String → Array Captured → Ty → Array String → String → String
blockFunction name captured result statements value =
  "func " <> name <> "(" <> joinWith ", " (map parameter captured) <> ") "
    <> goType result
    <> " {\n"
    <> joinWith "" statements
    <> "return "
    <> value
    <> "\n}\n"
  where
  parameter local = localName local.id <> " " <> goType local.ty

statement ∷ IR.Item → String → String
statement item code = case item of
  IR.Let (Just id) bound → "var " <> localName id <> " "
    <> goType (IR.typeOf bound)
    <> " = "
    <> code
    <> "\n_ = "
    <> localName id
    <> "\n"
  _ → "_ = " <> code <> "\n"

letLocal ∷ IR.Item → Maybe LocalId
letLocal = case _ of
  IR.Let local _ → local
  IR.Discard _ → Nothing
