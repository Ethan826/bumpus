module Features.Specialize.Lower (lowerType, fillType) where

import Prelude
import Data.Array as Array
import Data.Map as Map
import Data.Maybe (maybe')
import Data.Traversable (sequence, traverse)
import Domain.Checked.Internal (Open(..))
import Domain.Resolved (CtorId(..), CtorInfo)
import Domain.Syntax (Span, TypeRef(..), typeRefSpan, typeRefSpine)
import Domain.Type (Spine, Ty(..), TypeId(..), VarId(..), spine)
import Features.Specialize.Copy (get, modify)
import Features.Specialize.Intern (Lowered, bool, int, loweredType)
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
lowerType ∷ Env → Array Lowered → Span → Ty Open → Specializing Lowered
lowerType env arguments span = case _ of
  TInt → pure int
  TBool → pure bool
  TData id parts → traverse recur parts >>= applied env span id
  TVar (Rigid (VarId index)) → argument span arguments index
  TVar (Hole _) → lowerType env [] span (map absurd env.representative)
  arrow@(TFun _ _) → lowerSpine recur (spine arrow)
  where
  recur part = lowerType env arguments span part

-- Parameters left to right, then the result, then the interned arrow.
lowerSpine
  ∷ ∀ v. (Ty v → Specializing Lowered) → Spine v → Specializing Lowered
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
        , fields: map loweredType fields
        , span: ctor.span
        }
        state.ctors
    }

-- A field's applications are created at their own references in the
-- constructor's source, walked alongside it as Check.Nested does.
lowerField
  ∷ Env → Array Lowered → Ty VarId → TypeRef → Specializing Lowered
lowerField env arguments ty syntax = case ty, syntax of
  TData id parts, NamedRef span _ references →
    paired span parts references (lowerField env arguments)
      >>= applied env span id
  TData _ _, _ → mismatch
  TVar (VarId index), _ → argument (typeRefSpan syntax) arguments index
  TInt, _ → pure int
  TBool, _ → pure bool
  TFun _ _, FunRef span _ _ → lowerWritten span (spine ty)
    (typeRefSpine syntax)
  TFun _ _, _ → mismatch
  where
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

argument ∷ Span → Array Lowered → Int → Specializing Lowered
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
