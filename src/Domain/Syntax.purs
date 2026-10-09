module Domain.Syntax where

import Prelude
import Control.Monad.Rec.Class (Step(..), tailRec)
import Data.Array as Array
import Data.Maybe (Maybe(..))
import Data.Traversable (mapAccumL)
import Data.Tuple (Tuple(..))
import Domain.Problem (Problem)

type Position = { offset ∷ Int, line ∷ Int, column ∷ Int }
type Span = { start ∷ Position, end ∷ Position }
type Note = { span ∷ Span, reason ∷ NoteReason }
data NoteReason = RequiredBy String
type Diagnostic =
  { problem ∷ Problem, span ∷ Span, related ∷ Array Note }

data Operator = Equal | NotEqual | Less | LessEqual | Greater | GreaterEqual

derive instance eqOperator ∷ Eq Operator

data Expr
  = Integer Span Int
  | Boolean Span Boolean
  | Variable Span String
  | Call Span String (Array Expr)
  | Add Span Expr Expr
  | Compare Span Operator Expr Expr
  | If Span Expr Expr Expr
  | Match Span Expr (Array Arm)
  | Lambda Span (Array LambdaParam) Expr
  | Apply Span Expr (Array Expr)
  | Pipe Span Expr Expr
  | UnitValue Span
  | Block Span (Array Item) Expr
  | HandlerExpr Span LabelRef (Array Clause)
  | With Span Expr Expr
  | Handle Span Expr (Array FailClause)
  | Fail Span Expr

-- A block item (FX001 design §1): `let name = e`, `let _ = e` (Nothing)
-- spanning `let` through `e`, `defer e` spanning `defer` through `e`, or
-- `e`, whose value is discarded. A block whose items end in `;` has the
-- value `UnitValue` at its closing `}`; no written value ends where the
-- block does, so that span marks it.
data Item = Let Span (Maybe String) Expr | Defer Span Expr | Discard Expr

-- A lambda parameter spans its name; `_` (no name) binds nothing.
type LambdaParam = { name ∷ Maybe String, ty ∷ Maybe TypeRef, span ∷ Span }

data Pattern
  = PWildcard Span
  | PBind Span String
  | PInt Span Int
  | PBool Span Boolean
  | PCtor Span String (Array Pattern)

type Arm = { pattern ∷ Pattern, body ∷ Expr, span ∷ Span }
type Clause =
  { name ∷ String
  , parameters ∷ Array HandlerParameterRef
  , body ∷ Expr
  , span ∷ Span
  }

type HandlerParameterRef = { name ∷ Maybe String, span ∷ Span }
type FailClause = { name ∷ String, ty ∷ TypeRef, body ∷ Expr, span ∷ Span }

-- A lowercase name is a type variable; an applied type spans its head
-- through its closing parenthesis. `FunRef` is one arrow, parameter then
-- result; `(A, B) -> C` is written notation for `A -> B -> C`.
data TypeRef
  = IntRef Span
  | BoolRef Span
  | UnitRef Span
  | VarRef Span String
  | NamedRef Span String (Array TypeArgument)
  | THandlerRef Span LabelRef (Maybe RowRef)
  | FunRef Span TypeRef (Maybe RowRef) TypeRef

data TypeArgument = TypeArgument TypeRef | RowArgument RowRef

data Sort = TypeSort | RowSort

derive instance eqSort ∷ Eq Sort
derive instance ordSort ∷ Ord Sort

data RowTail = Spread String | Pure
data RowRef = RowRef Span (Array LabelRef) (Maybe RowTail)
type LabelRef = { name ∷ String, arguments ∷ Array TypeRef, span ∷ Span }

-- An arrow's parameters along its result side, and the final result.
type RefSpine = { parameters ∷ Array TypeRef, result ∷ TypeRef }

type CtorDecl = { name ∷ String, fields ∷ Array TypeRef, span ∷ Span }
type TypeParameter = { name ∷ String, sort ∷ Sort, span ∷ Span }
type TypeDecl =
  { name ∷ String
  , parameters ∷ Array TypeParameter
  , ctors ∷ Array CtorDecl
  , span ∷ Span
  }

type Parameter = { name ∷ String, ty ∷ TypeRef, span ∷ Span }
type FunctionDecl =
  { name ∷ String
  , parameters ∷ Array Parameter
  , result ∷ TypeRef
  , row ∷ Maybe RowRef
  , body ∷ Expr
  , span ∷ Span
  }

type OperationDecl =
  { name ∷ String
  , parameters ∷ Array Parameter
  , result ∷ TypeRef
  , row ∷ Maybe RowRef
  , span ∷ Span
  }

type EffectDecl =
  { name ∷ String
  , parameters ∷ Array TypeParameter
  , operations ∷ Array OperationDecl
  , span ∷ Span
  }

type Program =
  { types ∷ Array TypeDecl
  , functions ∷ Array FunctionDecl
  , effects ∷ Array EffectDecl
  }

-- Wire codes; Format.Diagnostic maps each Problem to one.
data ErrorCode
  = LexError
  | SyntaxError
  | IntegerRange
  | NestingLimit
  | EntryError
  | DuplicateName
  | UnboundName
  | NotCallable
  | TypeMismatch
  | InternalError
  | ArityMismatch
  | Redundant
  | NonExhaustive
  | SpecializationError
  | EffectError
  | HandlerError

derive instance eqErrorCode ∷ Eq ErrorCode

origin ∷ Position
origin = { offset: 0, line: 1, column: 1 }

exprSpan ∷ Expr → Span
exprSpan = case _ of
  Integer span _ → span
  Boolean span _ → span
  Variable span _ → span
  Call span _ _ → span
  Add span _ _ → span
  Compare span _ _ _ → span
  If span _ _ _ → span
  Match span _ _ → span
  Lambda span _ _ → span
  Apply span _ _ → span
  Pipe span _ _ → span
  UnitValue span → span
  Block span _ _ → span
  HandlerExpr span _ _ → span
  With span _ _ → span
  Handle span _ _ → span
  Fail span _ → span

typeRefSpan ∷ TypeRef → Span
typeRefSpan = case _ of
  IntRef span → span
  BoolRef span → span
  UnitRef span → span
  VarRef span _ → span
  NamedRef span _ _ → span
  THandlerRef span _ _ → span
  FunRef span _ _ _ → span

-- A written spine can be thousands of arrows long, so it is walked by
-- loops, never by one recursion per arrow: one counts the arrows, one takes
-- their parameters (as Domain.Type `spineThrough` does).
typeRefSpine ∷ TypeRef → RefSpine
typeRefSpine reference =
  { parameters: Array.catMaybes taken.value, result: taken.accum }
  where
  count = tailRec counted (Tuple 0 reference)
  counted (Tuple found rest) = case rest of
    FunRef _ _ _ more → Loop (Tuple (found + 1) more)
    _ → Done found
  taken = mapAccumL take reference (Array.replicate count unit)
  take rest _ = case rest of
    FunRef _ parameter _ more → { accum: more, value: Just parameter }
    settled → { accum: settled, value: Nothing }

patternSpan ∷ Pattern → Span
patternSpan = case _ of
  PWildcard span → span
  PBind span _ → span
  PInt span _ → span
  PBool span _ → span
  PCtor span _ _ → span

problemAt ∷ Problem → Span → Diagnostic
problemAt problem span = { problem, span, related: [] }

-- The effect reference in a handler type's source (FX001 Task 6):
-- `Handler(L(…) with R)` is its own form; `Handler(L(…))` parses as an
-- application, which Resolve read as a handler type.
handlerLabelRef ∷ TypeRef → Maybe LabelRef
handlerLabelRef = case _ of
  THandlerRef _ label _ → Just label
  NamedRef _ "Handler" [ TypeArgument (NamedRef span name arguments) ] →
    Just { name, arguments: Array.mapMaybe typeArgument arguments, span }
  _ → Nothing
  where
  typeArgument = case _ of
    TypeArgument found → Just found
    RowArgument _ → Nothing
