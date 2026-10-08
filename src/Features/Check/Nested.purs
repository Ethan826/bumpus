module Features.Check.Nested (nestedTypes, admissible, referenced) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Foldable (sequence_, traverse_)
import Data.Maybe (maybe')
import Data.Traversable (traverse)
import Domain.Checked.Internal as Checked
import Domain.Problem (Problem(..))
import Domain.Resolved (CtorId(..), CtorInfo, TypeInfo)
import Domain.Syntax (Diagnostic, Span, TypeRef(..), problemAt, typeRefSpan)
import Domain.Type (Ty(..), TypeId(..), VarId, children)
import Features.Check.Components (components)

-- The instantiation rule over the reference graph of type declarations
-- (design §4.1): an edge for each declared type a constructor field
-- mentions, however deeply. Inside a component, every type argument of a
-- reference must be a bare parameter of the referring type or ground. The
-- resolved field is walked alongside its source reference, so the offence
-- is reported at the nested reference itself.
nestedTypes ∷ Checked.Program → Either Diagnostic Unit
nestedTypes (Checked.Program program) = do
  owned ← traverse ctorsOf program.types
  component ← components (map edges owned)
  traverse_ (judgeType program.types component)
    (Array.mapWithIndex owner owned)
  where
  ctorsOf info = traverse (ctorAt info.span) info.ctors
  ctorAt span (CtorId index) = maybe' (invalid span) Right
    (Array.index program.ctors index)
  invalid span _ = Left (problemAt (Internal "Invalid constructor id") span)
  owner index ctors = { index, ctors }
  edges ctors = Array.concatMap referenced (Array.concatMap fields ctors)
  fields ctor = ctor.fields

-- `admissible variable ty`: `ty` is a bare variable, or mentions no
-- variable that `variable` selects. Shared with the function half.
admissible ∷ ∀ v. (v → Boolean) → Ty v → Boolean
admissible variable = case _ of
  TVar _ → true
  ty → not (mentions variable ty)

type Owned = { index ∷ Int, ctors ∷ Array CtorInfo }

judgeType
  ∷ Array TypeInfo → Array Int → Owned → Either Diagnostic Unit
judgeType types component owned = traverse_ judgeCtor owned.ctors
  where
  judgeCtor ctor = paired ctor.span ctor.fields ctor.fieldSyntax
    (judgeField types inside)
  inside (TypeId index) = Array.index component index
    == Array.index component owned.index

-- Pre-order: a reference is judged before the references in its
-- arguments, so the outermost offending one is reported.
judgeField
  ∷ Array TypeInfo
  → (TypeId → Boolean)
  → Ty VarId
  → TypeRef
  → Either Diagnostic Unit
judgeField types inside ty syntax = case ty, syntax of
  TData id arguments, NamedRef span _ references → reference span id
    arguments
    references
  TData _ _, _ → Left (mismatch (typeRefSpan syntax))
  -- No field syntax writes an arrow until FN001 Task 3, so a resolved
  -- arrow here has no source beside it.
  TFun _ _, _ → Left (mismatch (typeRefSpan syntax))
  _, _ → Right unit
  where
  reference span id arguments references = offending span id arguments
    *> paired span arguments references (judgeField types inside)
  offending span id@(TypeId index) arguments
    | inside id && not (Array.all (admissible always) arguments) =
        maybe' (missing span) (nested span) (Array.index types index)
    | otherwise = Right unit
  nested span info = Left (problemAt (NestedDatatype info.name) span)
  missing span _ = Left (problemAt (Internal "Invalid type id") span)
  always _ = true

-- Resolution keeps each field's source beside it, argument for argument;
-- a disagreement is a compiler bug.
paired
  ∷ ∀ a b
  . Span
  → Array a
  → Array b
  → (a → b → Either Diagnostic Unit)
  → Either Diagnostic Unit
paired span left right judge
  | Array.length left == Array.length right = sequence_
      (Array.zipWith judge left right)
  | otherwise = Left (mismatch span)

mismatch ∷ Span → Diagnostic
mismatch = problemAt (Internal "Field syntax mismatch")

-- An arrow is a constructor of two arguments to the reference graph: the
-- types its parameters and result mention are referenced.
referenced ∷ ∀ v. Ty v → Array Int
referenced = case _ of
  TData (TypeId index) arguments → Array.cons index
    (Array.concatMap referenced arguments)
  ty → Array.concatMap referenced (children ty)

mentions ∷ ∀ v. (v → Boolean) → Ty v → Boolean
mentions variable = case _ of
  TVar each → variable each
  ty → Array.any (mentions variable) (children ty)
