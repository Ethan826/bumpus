module Domain.Resolved
  ( module Domain.Resolved
  , module Domain.Type
  ) where

import Prelude
import Domain.Syntax (Operator, Span, TypeRef)
import Domain.Type (Ty(..), TypeId(..), VarId(..))

newtype FunctionId = FunctionId Int
newtype LocalId = LocalId Int
newtype CtorId = CtorId Int

derive instance eqFunctionId ∷ Eq FunctionId
derive instance eqLocalId ∷ Eq LocalId
derive instance eqCtorId ∷ Eq CtorId

-- `VarId i` in a constructor field is the owner's i-th parameter.
type TypeInfo =
  { name ∷ String
  , parameters ∷ Array String
  , ctors ∷ Array CtorId
  , span ∷ Span
  }

-- Field types are over the owner's parameters. `fieldSyntax` keeps each
-- field's source reference, whose nested spans diagnostics point into.
type CtorInfo =
  { name ∷ String
  , owner ∷ TypeId
  , fields ∷ Array (Ty VarId)
  , fieldSyntax ∷ Array TypeRef
  , span ∷ Span
  }

type Tables = { types ∷ Array TypeInfo, ctors ∷ Array CtorInfo }

-- The resolver's scope entry: a source name and the id it resolves to.
type Local = { name ∷ String, id ∷ LocalId }

data GlobalRef = FunctionRef FunctionId | CtorRef CtorId

-- Functions and constructors share one global namespace.
type Global = { name ∷ String, ref ∷ GlobalRef }

data Pattern
  = Wildcard Span
  | Bind Span LocalId
  | IntLit Span Int
  | BoolLit Span Boolean
  | Ctor Span CtorId (Array Pattern)

type Arm = { pattern ∷ Pattern, body ∷ Expr, span ∷ Span }

data Expr
  = Integer Span Int
  | Boolean Span Boolean
  | Local Span LocalId
  | Call Span FunctionId (Array Expr)
  | Construct Span CtorId (Array Expr)
  | Add Span Expr Expr
  | Compare Span Operator Expr Expr
  | If Span Expr Expr Expr
  | Match Span Expr (Array Arm)

type Parameter = { name ∷ String, ty ∷ Ty VarId, span ∷ Span }

-- `VarId i` in a signature is `variables !! i`: the i-th distinct type
-- variable in first-occurrence order, parameters then result.
type FunctionDecl =
  { id ∷ FunctionId
  , name ∷ String
  , variables ∷ Array String
  , parameters ∷ Array Parameter
  , result ∷ Ty VarId
  , body ∷ Expr
  , span ∷ Span
  }

type Program =
  { types ∷ Array TypeInfo
  , ctors ∷ Array CtorInfo
  , functions ∷ Array FunctionDecl
  , entry ∷ FunctionId
  }

exprSpan ∷ Expr → Span
exprSpan expression = case expression of
  Integer span _ → span
  Boolean span _ → span
  Local span _ → span
  Call span _ _ → span
  Construct span _ _ → span
  Add span _ _ → span
  Compare span _ _ _ → span
  If span _ _ _ → span
  Match span _ _ → span
