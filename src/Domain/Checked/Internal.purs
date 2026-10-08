module Domain.Checked.Internal where

import Prelude
import Domain.Syntax (Operator, Span)
import Domain.Resolved
  ( CtorId
  , CtorInfo
  , FunctionId
  , LocalId
  , Ty
  , TypeInfo
  , VarId
  )

-- The checked IR: typed and possibly polymorphic. Constructors are internal
-- to checking and specialization, enforced by the structure gate.

-- A variable a checked type may hold: a rigid variable of the enclosing
-- function's signature, or a hole (a use whose type checking left open).
data Open = Rigid VarId | Hole Int

derive instance eqOpen ∷ Eq Open
derive instance ordOpen ∷ Ord Open

-- The type arguments of a call or construction, in the callee's (or the
-- owner's) variable order; always empty until P001 adds type variables.
type Instantiation = Array (Ty Open)

newtype Program = Program
  { types ∷ Array TypeInfo
  , ctors ∷ Array CtorInfo
  , functions ∷ Array FunctionDecl
  , entry ∷ FunctionId
  }

-- The name appears only in diagnostics.
type FunctionDecl =
  { id ∷ FunctionId
  , name ∷ String
  , parameters ∷ Array (Ty Open)
  , result ∷ Ty Open
  , body ∷ Expr
  , span ∷ Span
  }

data Expr = Expr { ty ∷ Ty Open, span ∷ Span, node ∷ Node }

data Node
  = Integer Int
  | Boolean Boolean
  | Local LocalId
  | Call FunctionId Instantiation (Array Expr)
  | Construct CtorId Instantiation (Array Expr)
  | Add Expr Expr
  | Compare Operator Expr Expr
  | If Expr Expr Expr
  | Match Expr (Array Arm)

type Arm = { pattern ∷ Pattern, body ∷ Expr, span ∷ Span }

-- A pattern carries the type it was checked against.
data Pattern = Pattern { ty ∷ Ty Open, span ∷ Span, shape ∷ Shape }

data Shape
  = Wildcard
  | Bind LocalId
  | IntLit Int
  | BoolLit Boolean
  | Ctor CtorId (Array Pattern)

-- A declared type seen from inside its declaration, where its variables are
-- rigid.
rigid ∷ Ty VarId → Ty Open
rigid = map Rigid

typeOf ∷ Expr → Ty Open
typeOf (Expr expression) = expression.ty

spanOf ∷ Expr → Span
spanOf (Expr expression) = expression.span
