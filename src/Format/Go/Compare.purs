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
import Data.Maybe (maybe)
import Data.String.Common (joinWith)
import Domain.IR.Internal as IR
import Domain.Resolved (CtorId(..), CtorInfo, Ty(..), TypeId(..), TypeInfo)
import Domain.Syntax (Operator(..))
import Format.Go.Data (fieldName, goType, tagOf)

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
  "func sprigCmpBool(a bool, b bool) int { "
    <> "if a == b { return 0 }; if b { return -1 }; return 1 }\n\n"

compareName ∷ TypeId → String
compareName (TypeId index) = "sprigCmp" <> show index

-- One helper per declared type, in TypeId order, whether or not used.
compareHelpers ∷ Array TypeInfo → Array CtorInfo → String
compareHelpers types ctors = joinWith "" (Array.mapWithIndex helper types)
  where
  helper index info = compareHelper types ctors (TypeId index) info

-- Go evaluates call operands left to right, so every form keeps that order.
-- Go == on the structs would compare field pointers, so declared types
-- always go through their helper.
comparison
  ∷ (IR.Expr → String) → Operator → IR.Expr → IR.Expr → String
comparison lower operator left right = case IR.typeOf left of
  TData owner → viaHelper (compareName owner)
  _ | isBoolOrdering operator left → viaHelper "sprigCmpBool"
  _ → "(" <> lower left <> " " <> symbol <> " " <> lower right <> ")"
  where
  symbol = goOperator operator
  viaHelper name = "(" <> name <> "(" <> lower left <> ", " <> lower right
    <> ") "
    <> symbol
    <> " 0)"

-- Tags are 1-based declaration positions, so comparing tags orders
-- constructors. An out-of-range tag is malformed (I001 foreign values).
compareHelper
  ∷ Array TypeInfo → Array CtorInfo → TypeId → TypeInfo → String
compareHelper types ctors owner info =
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
    <> joinWith "" (map (ctorFields types ctors) info.ctors)
    <> "return 0\n}\n\n"
  where
  name = goType (TData owner)
  count = show (Array.length info.ctors)
  badTag value = value <> ".tag < 1 || " <> value <> ".tag > " <> count

-- Fields compare left to right; the first nonzero result decides.
ctorFields ∷ Array TypeInfo → Array CtorInfo → CtorId → String
ctorFields types ctors id@(CtorId index) =
  maybe "" declared (Array.index ctors index)
  where
  declared ctor = guarded (fieldsOf ctor)
  fieldsOf ctor = joinWith "" (Array.mapWithIndex field ctor.fields)
  field position ty = fieldComparison (fieldName id position) ty
  guarded body =
    if body == "" then ""
    else "if a.tag == " <> show (tagOf types id) <> " {\n" <> body <> "}\n"

fieldComparison ∷ String → Ty → String
fieldComparison field = case _ of
  TInt → "if " <> left <> " < " <> right <> " { return -1 }; if " <> left
    <> " > "
    <> right
    <> " { return 1 }\n"
  TBool → decide ("sprigCmpBool(" <> left <> ", " <> right <> ")")
  TData owner → "if " <> left <> " == nil || " <> right <> " == nil { "
    <> malformed
    <> " }\n"
    <> decide (compareName owner <> "(*" <> left <> ", *" <> right <> ")")
  where
  left = "a." <> field
  right = "b." <> field
  decide call = "if c := " <> call <> "; c != 0 { return c }\n"

malformed ∷ String
malformed = "panic(\"sprig: malformed value\")"
