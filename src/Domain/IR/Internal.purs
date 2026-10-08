module Domain.IR.Internal where

import Prelude
import Control.Monad.Rec.Class (Step(..), tailRec)
import Data.Array as Array
import Data.Maybe (Maybe(..))
import Data.Traversable (mapAccumL)
import Data.Tuple (Tuple(..))
import Domain.Syntax (Operator, Span)
import Domain.Resolved (CtorId, FunctionId, LocalId, TypeId)

-- The monomorphic IR Go generation reads. Its `Ty` has no variable, so no
-- type variable can reach Go by construction. Constructors are internal to
-- specialization and lowering, enforced by the structure gate. `TFun` is
-- the curried arrow, nested as in the source type (design §7); an output
-- type is already numbered, so only an arrow has parts.
data Ty = TInt | TBool | TData TypeId | TFun Ty Ty

-- An arrow's parameters, in order, and its final result, not an arrow.
type Spine = { parameters ∷ Array Ty, result ∷ Ty }

-- Constructors in declaration order, as a derived instance ranks them.
data Head = IntHead | BoolHead | DataHead | FunHead

derive instance eqHead ∷ Eq Head
derive instance ordHead ∷ Ord Head

-- Hand-written like Domain.Type's (FN001 Task 2): spines are walked in step
-- by a loop and only parameters recurse, so a 20,000-long spine costs no
-- stack. The order is the derived one: constructors in declaration order,
-- then fields left to right.
instance eqTy ∷ Eq Ty where
  eq left right = compare left right == EQ

instance ordTy ∷ Ord Ty where
  compare left right = tailRec step (Tuple left right)
    where
    step (Tuple one other) = case one, other of
      TFun first rest, TFun second more → case compare first second of
        EQ → Loop (Tuple rest more)
        decided → Done decided
      TData first, TData second → Done (compare first second)
      _, _ → Done (compare (headOf one) (headOf other))

-- By two loops, as Domain.Type.spineThrough: one counts, one takes.
spine ∷ Ty → Spine
spine ty = { parameters: Array.catMaybes taken.value, result: taken.accum }
  where
  count = tailRec counted (Tuple 0 ty)
  counted (Tuple found rest) = case rest of
    TFun _ more → Loop (Tuple (found + 1) more)
    _ → Done found
  taken = mapAccumL take ty (Array.replicate count unit)
  take rest _ = case rest of
    TFun parameter more → { accum: more, value: Just parameter }
    settled → { accum: settled, value: Nothing }

type TypeInfo = { name ∷ String, ctors ∷ Array CtorId, span ∷ Span }

type CtorInfo =
  { name ∷ String, owner ∷ TypeId, fields ∷ Array Ty, span ∷ Span }

type Tables = { types ∷ Array TypeInfo, ctors ∷ Array CtorInfo }

newtype Program = Program
  { types ∷ Array TypeInfo
  , ctors ∷ Array CtorInfo
  , functions ∷ Array FunctionDecl
  , entry ∷ FunctionId
  }

-- The source name is carried for diagnostics; Go names functions by id.
type FunctionDecl =
  { id ∷ FunctionId
  , name ∷ String
  , parameters ∷ Array Ty
  , result ∷ Ty
  , body ∷ Expr
  , span ∷ Span
  }

data Expr = Expr { ty ∷ Ty, span ∷ Span, node ∷ Node }

data Node
  = Integer Int
  | Boolean Boolean
  | Local LocalId
  | Call FunctionId (Array Expr)
  | Construct CtorId (Array Expr)
  | Add Expr Expr
  | Compare Operator Expr Expr
  | If Expr Expr Expr
  | Match Expr (Array Arm)
  | FunctionRef FunctionId
  | CtorRef CtorId
  | Apply Expr (Array Expr)
  | Lambda (Array Param) Expr
  | Pipe Expr Expr

-- Mirrors the checked IR (FN001): `Call` and `Construct` may be partial;
-- a lambda parameter is a typed local or a typed discard.
type Param = { local ∷ Maybe LocalId, ty ∷ Ty }

type Arm = { pattern ∷ Pattern, body ∷ Expr, span ∷ Span }

-- A pattern carries the type it was checked against; lowering reads it.
data Pattern = Pattern { ty ∷ Ty, span ∷ Span, shape ∷ Shape }

data Shape
  = Wildcard
  | Bind LocalId
  | IntLit Int
  | BoolLit Boolean
  | Ctor CtorId (Array Pattern)

typeOf ∷ Expr → Ty
typeOf (Expr expression) = expression.ty

spanOf ∷ Expr → Span
spanOf (Expr expression) = expression.span

headOf ∷ Ty → Head
headOf = case _ of
  TInt → IntHead
  TBool → BoolHead
  TData _ → DataHead
  TFun _ _ → FunHead
