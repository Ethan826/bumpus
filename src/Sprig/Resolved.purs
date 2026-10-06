module Sprig.Resolved where

import Prelude
import Data.Array as Array
import Data.Maybe (maybe)
import Sprig.Model (Span)

newtype FunctionId = FunctionId Int
newtype LocalId = LocalId Int
newtype TypeId = TypeId Int
newtype CtorId = CtorId Int

derive instance eqFunctionId ∷ Eq FunctionId
derive instance eqLocalId ∷ Eq LocalId
derive instance eqTypeId ∷ Eq TypeId
derive instance eqCtorId ∷ Eq CtorId

data Ty = TInt | TBool | TData TypeId

derive instance eqTy ∷ Eq Ty

type TypeInfo = { name ∷ String, ctors ∷ Array CtorId, span ∷ Span }

type CtorInfo =
  { name ∷ String, owner ∷ TypeId, fields ∷ Array Ty, span ∷ Span }

type Tables = { types ∷ Array TypeInfo, ctors ∷ Array CtorInfo }

-- The resolver's scope entry: a source name and the id it resolves to.
type Local = { name ∷ String, id ∷ LocalId }

data GlobalRef = FunctionRef FunctionId | CtorRef CtorId

data Expr
  = Integer Span Int
  | Boolean Span Boolean
  | Local Span LocalId
  | Call Span FunctionId (Array Expr)
  | Construct Span CtorId (Array Expr)
  | Add Span Expr Expr
  | If Span Expr Expr Expr

type Parameter = { name ∷ String, ty ∷ Ty, span ∷ Span }

type FunctionDecl =
  { id ∷ FunctionId
  , parameters ∷ Array Parameter
  , result ∷ Ty
  , body ∷ Expr
  , span ∷ Span
  }

type Program =
  { types ∷ Array TypeInfo
  , ctors ∷ Array CtorInfo
  , functions ∷ Array FunctionDecl
  , entry ∷ FunctionId
  }

-- Names appear only in diagnostics, never in generated Go.
describe ∷ Array TypeInfo → Ty → String
describe types = case _ of
  TInt → "Int"
  TBool → "Bool"
  TData (TypeId index) → maybe "type" typeName (Array.index types index)
  where
  typeName info = info.name

exprSpan ∷ Expr → Span
exprSpan expression = case expression of
  Integer span _ → span
  Boolean span _ → span
  Local span _ → span
  Call span _ _ → span
  Construct span _ _ → span
  Add span _ _ → span
  If span _ _ _ → span
