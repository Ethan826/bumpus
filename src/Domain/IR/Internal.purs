module Domain.IR.Internal where

import Prelude
import Control.Monad.Rec.Class (Step(..), tailRec)
import Data.Array as Array
import Data.Maybe (Maybe(..), maybe')
import Data.Traversable (mapAccumL)
import Data.Tuple (Tuple(..))
import Domain.Syntax (Operator, Span)
import Domain.Resolved (CtorId, FunctionId, LocalId, TypeId)

-- The monomorphic IR Go generation reads. Its `Ty` has no variable, so no
-- type variable can reach Go by construction. Constructors are internal to
-- specialization and lowering, enforced by the structure gate. Every type
-- is a number or a builtin: a declared type's output id, or an arrow's
-- interned id into the program's `funTypes` table (FN001 Task 5 review),
-- so comparing two types is constant time whatever they stand for, and a
-- 5,000-parameter arrow is one table entry per suffix, not a tree copied
-- into every expression typed by it (design §7, §13 rule 8).
data Ty = TInt | TBool | TData TypeId | TFun FunTypeId

-- An arrow's number: its index in `funTypes`.
newtype FunTypeId = FunTypeId Int

derive instance eqFunTypeId ∷ Eq FunTypeId
derive instance ordFunTypeId ∷ Ord FunTypeId
derive instance eqTy ∷ Eq Ty
derive instance ordTy ∷ Ord Ty

-- One arrow: its parameter and its result, each a number or a builtin.
-- Specialize interns a result before the arrow containing it, and a
-- parameter before both, so each entry names only earlier entries.
type FunType = { parameter ∷ Ty, result ∷ Ty }

-- An arrow's parameters, in order, and its final result, not an arrow.
type Spine = { parameters ∷ Array Ty, result ∷ Ty }

-- Through the table, by two loops as Domain.Type.spineThrough: one counts,
-- one takes. An id missing from the table (a compiler bug) ends the spine
-- there, as a result.
spine ∷ Array FunType → Ty → Spine
spine table ty =
  { parameters: Array.catMaybes taken.value, result: taken.accum }
  where
  count = tailRec counted (Tuple 0 ty)
  counted (Tuple found rest) = maybe' (stop found) (more found)
    (entry rest)
  stop found _ = Done found
  more found arrow = Loop (Tuple (found + 1) arrow.result)
  taken = mapAccumL take ty (Array.replicate count unit)
  take rest _ = maybe' (settled rest) step (entry rest)
  settled rest _ = { accum: rest, value: Nothing }
  step arrow = { accum: arrow.result, value: Just arrow.parameter }
  entry = case _ of
    TFun (FunTypeId index) → Array.index table index
    _ → Nothing

type TypeInfo = { name ∷ String, ctors ∷ Array CtorId, span ∷ Span }

type CtorInfo =
  { name ∷ String, owner ∷ TypeId, fields ∷ Array Ty, span ∷ Span }

type Tables = { types ∷ Array TypeInfo, ctors ∷ Array CtorInfo }

newtype Program = Program
  { types ∷ Array TypeInfo
  , ctors ∷ Array CtorInfo
  , functions ∷ Array FunctionDecl
  , funTypes ∷ Array FunType
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
