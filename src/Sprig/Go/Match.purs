module Sprig.Go.Match (lowerMatch) where

import Prelude
import Data.Array as Array
import Data.String.Common (joinWith)
import Sprig.Go.Data (boolean, fieldName, goType, integer, localName, tagOf)
import Sprig.IR.Internal as IR
import Sprig.Resolved (CtorId, LocalId, Tables, Ty(..))

-- Where a pattern position lives, and whether reaching it dereferences.
type Access = { path ∷ String, pointer ∷ Boolean }

type Binding = { id ∷ LocalId, value ∷ String }

-- An immediately invoked function whose parameter is named by match nesting
-- depth. Arms are tested in order; the panic guards only malformed values.
lowerMatch
  ∷ Tables
  → (Int → IR.Expr → String)
  → Int
  → Ty
  → IR.Expr
  → Array IR.Arm
  → String
lowerMatch tables lower depth ty scrutinee arms =
  "func(" <> parameter <> " " <> goType (IR.typeOf scrutinee) <> ") "
    <> goType ty
    <> " {\n"
    <> joinWith "" (map lowerArm arms)
    <> "panic(\"sprig: unmatched value\")\n}("
    <> lower depth scrutinee
    <> ")"
  where
  parameter = "sprigMatch" <> show depth
  lowerArm arm = armCode tables (lower (depth + 1)) parameter arm

armCode ∷ Tables → (IR.Expr → String) → String → IR.Arm → String
armCode tables lower parameter arm =
  if Array.null bound then
    "if " <> condition <> " { return " <> lower arm.body <> " }\n"
  else
    "if " <> condition <> " {\n" <> joinWith "" (map binding bound)
      <> "return "
      <> lower arm.body
      <> "\n}\n"
  where
  root = { path: parameter, pointer: false }
  tests = conditions tables root arm.pattern
  bound = bindings root arm.pattern
  condition = if Array.null tests then "true" else joinWith " && " tests

-- Each binder is also discarded so Go never reports an unused variable.
binding ∷ Binding → String
binding bound = name <> " := " <> bound.value <> "\n_ = " <> name <> "\n"
  where
  name = localName bound.id

-- Conjuncts in pattern pre-order; a pointer is tested before any projection
-- through it, so `&&` short-circuiting guards every dereference.
conditions ∷ Tables → Access → IR.Pattern → Array String
conditions tables access (IR.Pattern pattern) = case pattern.shape of
  IR.Wildcard → []
  IR.Bind _ → guarded []
  IR.IntLit value → [ access.path <> " == " <> integer value ]
  IR.BoolLit value → [ access.path <> " == " <> boolean value ]
  IR.Ctor id fields → guarded
    ( [ access.path <> ".tag == " <> show (tagOf tables.types id) ]
        <> Array.concat (Array.mapWithIndex (field id) fields)
    )
  where
  guarded tests = (if access.pointer then [ nilGuard access.path ] else [])
    <> tests
  field id index sub = conditions tables (fieldAccess access id index sub) sub

nilGuard ∷ String → String
nilGuard path = path <> " != nil"

bindings ∷ Access → IR.Pattern → Array Binding
bindings access (IR.Pattern pattern) = case pattern.shape of
  IR.Bind id → [ { id, value: dereferenced } ]
  IR.Ctor id fields → Array.concat (Array.mapWithIndex (field id) fields)
  _ → []
  where
  dereferenced = (if access.pointer then "*" else "") <> access.path
  field id index sub = bindings (fieldAccess access id index sub) sub

-- ADT fields are stored as pointers; primitive fields are stored directly.
fieldAccess ∷ Access → CtorId → Int → IR.Pattern → Access
fieldAccess access id index (IR.Pattern sub) =
  { path: access.path <> "." <> fieldName id index, pointer: isData sub.ty }
  where
  isData = case _ of
    TData _ → true
    _ → false
