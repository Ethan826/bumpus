module Features.Specialize.Lower (lowerType, fillType) where

import Prelude
import Data.Array as Array
import Data.Map as Map
import Data.Maybe (maybe')
import Data.Traversable (sequence, traverse)
import Domain.Checked.Internal (Open(..))
import Domain.IR.Internal as IR
import Domain.Resolved (CtorId(..), CtorInfo)
import Domain.Syntax (Span, TypeRef(..), typeRefSpan)
import Domain.Type (Ty(..), TypeId(..), VarId(..))
import Features.Specialize.Copy (get, modify)
import Features.Specialize.Keys (Env, Specializing, Work, applied, internal)

-- A body type at one key: rigid variable i is the key's i-th argument and
-- every hole is the representative (design §6). An application's arguments
-- are numbered before it, so each key refers only to earlier output types.
lowerType ∷ Env → Array IR.Ty → Span → Ty Open → Specializing IR.Ty
lowerType env arguments span = case _ of
  TInt → pure IR.TInt
  TBool → pure IR.TBool
  TData id parts → traverse recur parts >>= applied env span id
  TVar (Rigid (VarId index)) → argument span arguments index
  TVar (Hole _) → lowerType env [] span (map absurd env.representative)
  TFun _ _ → unlowered span
  where
  recur part = lowerType env arguments span part

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
        { name: ctor.name, owner: TypeId work.output, fields, span: ctor.span }
        state.ctors
    }

-- A field's applications are created at their own references in the
-- constructor's source, walked alongside it as Check.Nested does.
lowerField ∷ Env → Array IR.Ty → Ty VarId → TypeRef → Specializing IR.Ty
lowerField env arguments ty syntax = case ty, syntax of
  TData id parts, NamedRef span _ references →
    paired span parts references (lowerField env arguments)
      >>= applied env span id
  TData _ _, _ → mismatch
  TVar (VarId index), _ → argument (typeRefSpan syntax) arguments index
  TInt, _ → pure IR.TInt
  TBool, _ → pure IR.TBool
  TFun _ _, _ → unlowered (typeRefSpan syntax)
  where
  mismatch = internal "Field syntax mismatch" (typeRefSpan syntax) unit

-- The monomorphic IR has no arrow until FN001 Task 5.
unlowered ∷ ∀ a. Span → Specializing a
unlowered span = internal "unlowered function" span unit

missingType ∷ ∀ a b. Work → a → Specializing b
missingType work = internal "Invalid type id" work.span

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
