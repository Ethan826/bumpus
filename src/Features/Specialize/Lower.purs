module Features.Specialize.Lower (lowerType, fillType, fillEffect) where

import Prelude
import Data.Array as Array
import Data.Map as Map
import Data.Maybe (Maybe(..), maybe')
import Data.Traversable (sequence, traverse)
import Domain.Checked.Internal (Open(..))
import Domain.IR.Internal as IR
import Domain.Resolved (CtorId(..), CtorInfo, OperationInfo)
import Domain.Row (Label(..))
import Domain.Syntax
  ( Span
  , TypeArgument(..)
  , TypeRef(..)
  , handlerLabelRef
  , typeRefSpan
  , typeRefSpine
  )
import Domain.Type (Ty(..), TypeId(..), VarId(..))
import Domain.Type.Parts (Spine, spine)
import Features.Specialize.Copy (get, modify)
import Features.Specialize.Effects (effectAt)
import Features.Specialize.Keys
  ( Env
  , Specializing
  , Work
  , applied
  , arrowOf
  , internal
  )

-- A body type at one key: rigid variable i is the key's i-th argument and
-- every hole is the representative (design §6). An application's arguments
-- are numbered before it, so each key refers only to earlier output types.
-- An arrow's parameters and final result are lowered in order, along its
-- spine, then its suffixes interned (FN001 Task 5): no recursion per arrow.
-- Rows are erased (FX001 design §4): no Go type depends on one. A handler
-- type is its label's layout: the label's arguments, then its effect key.
lowerType ∷ Env → Array IR.Ty → Span → Ty Open → Specializing IR.Ty
lowerType env arguments span = case _ of
  TInt → pure IR.TInt
  TBool → pure IR.TBool
  TUnit → pure IR.TUnit
  TData id parts _ → traverse recur parts >>= applied env span id
  TVar (Rigid (VarId index)) → argument span arguments index
  TVar (Hole _) → lowerType env [] span (map absurd env.representative)
  arrow@(TFun _ _ _) → lowerSpine recur (spine arrow)
  THandler (Label effect parts) _ → traverse recur parts
    >>= effectAt env span effect
    >>= (pure <<< IR.THandler)
  where
  recur part = lowerType env arguments span part

-- Parameters left to right, then the result, then the interned arrow.
lowerSpine
  ∷ ∀ v. (Ty v → Specializing IR.Ty) → Spine v → Specializing IR.Ty
lowerSpine lower found = do
  parameters ← traverse lower found.parameters
  result ← lower found.result
  arrowOf parameters result

-- Fills a type's output constructors: each declared constructor, in order,
-- takes the next id of the type's block, with its fields at the key's
-- arguments. `sequence` is balanced, so thousands of constructors stay in
-- shallow stack.
fillType ∷ Env → Work → Specializing Unit
fillType env work = do
  state ← get
  info ← maybe' (missingType work) pure (Map.lookup work.output state.types)
  declared ← maybe' (missingType work) pure
    (Array.index env.types work.declaration)
  void (sequence (Array.zipWith fill info.ctors declared.ctors))
  where
  fill output (CtorId original) =
    maybe' (internal "Invalid constructor id" work.span)
      (fillCtor env work output)
      (Array.index env.ctors original)

fillCtor ∷ Env → Work → CtorId → CtorInfo → Specializing Unit
fillCtor env work (CtorId output) ctor = do
  fields ← paired ctor.span ctor.fields ctor.fieldSyntax
    (lowerField env work.arguments)
  modify (inserted fields)
  where
  inserted fields state = state
    { ctors = Map.insert output
        { name: ctor.name
        , owner: TypeId work.output
        , fields
        , span: ctor.span
        }
        state.ctors
    }

-- Fills an effect layout's operations (FX001 design §4): each parameter
-- type, then the result, at the key's arguments, beside its source as a
-- constructor's fields are; so an effect key reaches the keys of its
-- operations' types, and of the effect of every handler type among them.
fillEffect ∷ Env → Work → Specializing Unit
fillEffect env work = maybe' (missingEffect work) filled
  (Array.index env.effects work.declaration)
  where
  filled declared = do
    operations ← traverse (layout env work) declared.operations
    modify (inserted operations)
  inserted operations state = state
    { effects = Map.update (withOperations operations) work.output
        state.effects
    }
  withOperations operations info = Just info { operations = operations }

layout ∷ Env → Work → OperationInfo → Specializing IR.OperationInfo
layout env work operation = do
  types ← paired operation.span
    (Array.snoc (map parameterType operation.parameters) operation.result)
    operation.syntax
    (lowerField env work.arguments)
  maybe' (internal "Operation syntax mismatch" operation.span) pure
    (made <$> Array.unsnoc types)
  where
  parameterType parameter = parameter.ty
  made split =
    { name: operation.name
    , parameters: split.init
    , result: split.last
    , span: operation.span
    }

-- A field's applications are created at their own references in the
-- constructor's source, walked alongside it as Check.Nested does; a
-- handler type's label arguments beside its label's.
lowerField
  ∷ Env → Array IR.Ty → Ty VarId → TypeRef → Specializing IR.Ty
lowerField env arguments ty syntax = case ty, syntax of
  TData id parts _, NamedRef span _ references →
    paired span parts (Array.mapMaybe typeArgument references)
      (lowerField env arguments)
      >>= applied env span id
  TData _ _ _, _ → mismatch
  TVar (VarId index), _ → argument (typeRefSpan syntax) arguments index
  TInt, _ → pure IR.TInt
  TBool, _ → pure IR.TBool
  TUnit, _ → pure IR.TUnit
  TFun _ _ _, FunRef span _ _ _ → lowerWritten span (spine ty)
    (typeRefSpine syntax)
  TFun _ _ _, _ → mismatch
  THandler (Label effect parts) _, _ → maybe' (const mismatch)
    (lowerHandler effect parts)
    (handlerLabelRef syntax)
  where
  lowerHandler effect parts label =
    paired label.span parts label.arguments
      recur
      >>= effectAt env label.span effect
      >>= (pure <<< IR.THandler)
  typeArgument = case _ of
    TypeArgument foundType → Just foundType
    RowArgument _ → Nothing
  mismatch = internal "Field syntax mismatch" (typeRefSpan syntax) unit
  recur = lowerField env arguments
  -- Each parameter and the final result beside its written source, as
  -- Check.Nested pairs them.
  lowerWritten span found written = do
    parameters ← paired span found.parameters written.parameters recur
    result ← recur found.result written.result
    arrowOf parameters result

missingType ∷ ∀ a b. Work → a → Specializing b
missingType work = internal "Invalid type id" work.span

missingEffect ∷ ∀ a b. Work → a → Specializing b
missingEffect work = internal "Invalid effect id" work.span

argument ∷ Span → Array IR.Ty → Int → Specializing IR.Ty
argument span arguments index =
  maybe' (internal "Invalid type variable" span) pure
    (Array.index arguments index)

-- Resolution keeps each field's source beside it, argument for argument;
-- a disagreement is a compiler bug.
paired
  ∷ ∀ a b c
  . Span
  → Array a
  → Array b
  → (a → b → Specializing c)
  → Specializing (Array c)
paired span left right lower
  | Array.length left == Array.length right = sequence
      (Array.zipWith lower left right)
  | otherwise = internal "Field syntax mismatch" span unit
