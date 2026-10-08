module Format.Go.Match (lowerMatch) where

import Prelude
import Data.Array as Array
import Data.String.Common (joinWith)
import Format.Go.Capture (Captured, armFree, union)
import Format.Go.Data
  ( boolean
  , fieldName
  , functionName
  , goType
  , integer
  , localName
  )
import Format.Go.Layout (Layout, tagOf)
import Format.Go.Lowered (Lowered, Lowering, Scope, several)
import Domain.IR.Internal as IR
import Domain.IR.Internal (Ty(..))
import Domain.Resolved (CtorId, FunctionId, LocalId)

-- Where a pattern position lives, and whether reaching it dereferences.
type Access = { path ∷ String, pointer ∷ Boolean }

type Binding = { id ∷ LocalId, value ∷ String }

type Signature =
  { name ∷ String, captured ∷ Array Captured, scrutinee ∷ Ty, result ∷ Ty }

-- Each match is lifted to a top-level function, not an immediately invoked
-- closure: Go's inliner expands nested closures exponentially (E005). The
-- k-th match of bumpusFn{f}, numbered in pre-order with the scrutinee
-- before the arms, is bumpusFn{f}Match{k}. It takes the locals its arms
-- capture, then the scrutinee, which the call site evaluates once, where the
-- closure did. Arms are tested in order; the panic guards only malformed
-- values. Lifted functions follow their bumpusFn in number order. The
-- match's own free locals, which an enclosing match must capture, are its
-- scrutinee's and its captures (Format.Go.Capture).
lowerMatch
  ∷ Scope → Lowering → Int → Ty → IR.Expr → Array IR.Arm → Lowered
lowerMatch scope lower next result scrutinee arms =
  { code: signature.name <> "("
      <> joinWith ", " (map capturedName signature.captured <> [ subject.code ])
      <> ")"
  , next: bodies.next
  , lifted: [ lifted ] <> subject.lifted <> bodies.lifted
  , free: union [ subject.free, signature.captured ]
  , wrappers: subject.wrappers <> bodies.wrappers
  }
  where
  signature =
    { name: matchName scope.owner next
    , captured: union (Array.zipWith armFree patterns bodies.frees)
    , scrutinee: IR.typeOf scrutinee
    , result
    }
  subject = lower (next + 1) scrutinee
  bodies = several lower subject.next (map armBody arms)
  armBody arm = arm.body
  patterns = map armPattern arms
  armPattern arm = arm.pattern
  capturedName captured = localName captured.id
  lifted = matchFunction signature
    (Array.zipWith (armCode scope.tables) arms bodies.codes)

matchName ∷ FunctionId → Int → String
matchName owner number = functionName owner <> "Match" <> show number

scrutineeName ∷ String
scrutineeName = "bumpusScrutinee"

matchFunction ∷ Signature → Array String → String
matchFunction signature arms =
  "func " <> signature.name <> "(" <> joinWith ", " parameters <> ") "
    <> goType signature.result
    <> " {\n"
    <> joinWith "" arms
    <> "panic(\"bumpus: unmatched value\")\n}\n"
  where
  parameters = map parameter signature.captured
    <> [ scrutineeName <> " " <> goType signature.scrutinee ]
  parameter captured = localName captured.id <> " " <> goType captured.ty

armCode ∷ Layout → IR.Arm → String → String
armCode tables arm body =
  if Array.null bound then
    "if " <> condition <> " { return " <> body <> " }\n"
  else
    "if " <> condition <> " {\n" <> joinWith "" (map binding bound)
      <> "return "
      <> body
      <> "\n}\n"
  where
  root = { path: scrutineeName, pointer: false }
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
conditions ∷ Layout → Access → IR.Pattern → Array String
conditions tables access (IR.Pattern pattern) = case pattern.shape of
  IR.Wildcard → []
  IR.Bind _ → guarded []
  IR.IntLit value → [ access.path <> " == " <> integer value ]
  IR.BoolLit value → [ access.path <> " == " <> boolean value ]
  IR.Ctor id fields → guarded
    ( [ access.path <> ".tag == " <> show (tagOf tables id) ]
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
