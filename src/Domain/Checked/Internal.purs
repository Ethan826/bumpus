module Domain.Checked.Internal where

import Prelude
import Data.Array as Array
import Data.Maybe (Maybe)
import Domain.Syntax (Operator, Span)
import Domain.Type (TyRow)
import Domain.Ids (EffectId)
import Domain.Resolved
  ( CtorId
  , CtorInfo
  , EffectInfo
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

-- The type arguments of a reference to a function or constructor, in the
-- callee's (or the owner's) variable order.
type Instantiation = Array (Ty Open)

newtype Program = Program
  { effects ∷ Array EffectInfo
  , types ∷ Array TypeInfo
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
  , row ∷ TyRow Open
  , body ∷ Expr
  , span ∷ Span
  }

data Expr = Expr { ty ∷ Ty Open, span ∷ Span, node ∷ Node }

-- FN001: `Call` and `Construct` hold 1 to n arguments, fewer than the
-- declared n being a partial application (a construction of a nullary
-- constructor holds none); `FunctionRef` and `CtorRef` are bare
-- references; `Apply` applies any other function value, including an
-- over-applied call's result; `Pipe` keeps its left operand first
-- (design §5, §7).
data Node
  = Integer Int
  | Boolean Boolean
  | Local LocalId
  | FunctionRef FunctionId Instantiation
  | CtorRef CtorId Instantiation
  | Call FunctionId Instantiation (Array Expr)
  | Construct CtorId Instantiation (Array Expr)
  | Add Expr Expr
  | Compare Operator Expr Expr
  | If Expr Expr Expr
  | Match Expr (Array Arm)
  | Apply Expr (Array Expr)
  | Lambda (Array Param) Expr
  | Pipe Expr Expr
  | UnitValue
  | Block (Array Item) Expr
  | Print Expr
  | OperationRef EffectId Int Instantiation
  | Perform EffectId Int Instantiation (Array Expr)

-- A block item (FX001): a monomorphic `let` of a local or `_`, or a
-- discarded value.
data Item = Let (Maybe LocalId) Expr | Discard Expr

-- A lambda parameter: a typed local, or a typed discard (`_`).
type Param = { local ∷ Maybe LocalId, ty ∷ Ty Open }

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

itemValue ∷ Item → Expr
itemValue = case _ of
  Let _ value → value
  Discard value → value

-- A block's expressions in evaluation order: its items', then its value.
blockParts ∷ Array Item → Expr → Array Expr
blockParts items value = Array.snoc (map itemValue items) value
