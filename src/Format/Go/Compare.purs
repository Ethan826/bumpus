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
import Domain.IR.Internal (Ty(..))
import Domain.Resolved (TypeId(..))
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
  "func waxwingCmpBool(a bool, b bool) int { "
    <> "if a == b { return 0 }; if b { return -1 }; return 1 }\n\n"

compareName ∷ TypeId → String
compareName (TypeId index) = "waxwingCmp" <> show index

-- One helper per declared type, in TypeId order, whether or not used.
compareHelpers ∷ Layout → String
compareHelpers program = joinWith "" (map compareHelper program.types)

-- Go evaluates call operands left to right, so every form keeps that order.
-- Go == on the structs would compare field pointers, so declared types
-- always go through their helper. `ty` is the operands' type; `left` and
-- `right` are their lowered code.
comparison ∷ Operator → Ty → String → String → String
comparison operator ty left right = case ty of
  TData owner → viaHelper (compareName owner)
  TBool | isOrdering operator → viaHelper "waxwingCmpBool"
  TUnit | isOrdering operator → viaHelper unitOrder
  _ → "(" <> left <> " " <> symbol <> " " <> right <> ")"
  where
  symbol = goOperator operator
  viaHelper name = "(" <> name <> "(" <> left <> ", " <> right
    <> ") "
    <> symbol
    <> " 0)"

-- Unit has one value, so any two are equal (ADR 005); Go has no ordering
-- on struct{}, and this literal still evaluates both operands in order,
-- with no helper to emit.
unitOrder ∷ String
unitOrder = "func(struct{}, struct{}) int { return 0 }"

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
  TBool → decide ("waxwingCmpBool(" <> left <> ", " <> right <> ")")
  -- Two Unit fields are always equal.
  TUnit → ""
  TData owner → "if " <> left <> " == nil || " <> right <> " == nil { "
    <> malformed
    <> " }\n"
    <> decide (compareName owner <> "(*" <> left <> ", *" <> right <> ")")
  -- Checking rejects every comparison at a type holding an arrow (design
  -- §3), yet every declared type gets its helper; Go cannot compare two
  -- func values, so a function field is never compared and a constructor
  -- holding one, never reached, reports a malformed value.
  TFun _ → malformed <> "\n"
  where
  left = "a." <> field
  right = "b." <> field
  decide call = "if c := " <> call <> "; c != 0 { return c }\n"
