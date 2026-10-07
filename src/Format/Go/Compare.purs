module Format.Go.Compare
  ( goOperator
  , isOrdering
  , isBoolOrdering
  , boolHelper
  , compareName
  , compareHelpers
  , comparison
  ) where

import Prelude
import Data.Array as Array
import Data.String.Common (joinWith)
import Domain.IR.Internal as IR
import Domain.Resolved (Ty(..), TypeId(..))
import Domain.Syntax (Operator(..))
import Format.Go.Data (fieldName, goType, malformed)
import Format.Go.Layout (Declared, Layout, Member)

goOperator ∷ Operator → String
goOperator = case _ of
  Equal → "=="
  NotEqual → "!="
  Less → "<"
  LessEqual → "<="
  Greater → ">"
  GreaterEqual → ">="

isOrdering ∷ Operator → Boolean
isOrdering = case _ of
  Equal → false
  NotEqual → false
  _ → true

-- Bool has equality in Go but needs the helper for ordering.
isBoolOrdering ∷ Operator → IR.Expr → Boolean
isBoolOrdering operator left = isOrdering operator
  && IR.typeOf left == TBool

-- Go has no ordering on bool; false < true is expressed through -1, 0, 1.
boolHelper ∷ String
boolHelper =
  "func bumpusCmpBool(a bool, b bool) int { "
    <> "if a == b { return 0 }; if b { return -1 }; return 1 }\n\n"

compareName ∷ TypeId → String
compareName (TypeId index) = "bumpusCmp" <> show index

-- One helper per declared type, in TypeId order, whether or not used.
compareHelpers ∷ Layout → String
compareHelpers program = joinWith "" (map compareHelper program.types)

-- Go evaluates call operands left to right, so every form keeps that order.
-- Go == on the structs would compare field pointers, so declared types
-- always go through their helper.
comparison
  ∷ (IR.Expr → String) → Operator → IR.Expr → IR.Expr → String
comparison lower operator left right = case IR.typeOf left of
  TData owner → viaHelper (compareName owner)
  _ | isBoolOrdering operator left → viaHelper "bumpusCmpBool"
  _ → "(" <> lower left <> " " <> symbol <> " " <> lower right <> ")"
  where
  symbol = goOperator operator
  viaHelper name = "(" <> name <> "(" <> lower left <> ", " <> lower right
    <> ") "
    <> symbol
    <> " 0)"

-- Tags are 1-based declaration positions, so comparing tags orders
-- constructors. An out-of-range tag is malformed (I001 foreign values).
compareHelper ∷ Declared → String
compareHelper declared =
  "func " <> compareName owner <> "(a " <> name <> ", b " <> name
    <> ") int {\n"
    <> "if "
    <> badTag "a"
    <> " || "
    <> badTag "b"
    <> " { "
    <> malformed
    <> " }\n"
    <> "if a.tag != b.tag { if a.tag < b.tag { return -1 }; return 1 }\n"
    <> joinWith "" (map ctorFields declared.members)
    <> "return 0\n}\n\n"
  where
  owner = declared.id
  name = goType (TData owner)
  count = show (Array.length declared.members)
  badTag value = value <> ".tag < 1 || " <> value <> ".tag > " <> count

-- Fields compare left to right; the first nonzero result decides.
ctorFields ∷ Member → String
ctorFields member = guarded
  (joinWith "" (Array.mapWithIndex field member.ctor.fields))
  where
  field position ty = fieldComparison (fieldName member.id position) ty
  guarded body =
    if body == "" then ""
    else "if a.tag == " <> show member.tag <> " {\n" <> body <> "}\n"

fieldComparison ∷ String → Ty → String
fieldComparison field = case _ of
  TInt → "if " <> left <> " < " <> right <> " { return -1 }; if " <> left
    <> " > "
    <> right
    <> " { return 1 }\n"
  TBool → decide ("bumpusCmpBool(" <> left <> ", " <> right <> ")")
  TData owner → "if " <> left <> " == nil || " <> right <> " == nil { "
    <> malformed
    <> " }\n"
    <> decide (compareName owner <> "(*" <> left <> ", *" <> right <> ")")
  where
  left = "a." <> field
  right = "b." <> field
  decide call = "if c := " <> call <> "; c != 0 { return c }\n"
