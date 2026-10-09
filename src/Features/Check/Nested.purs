module Features.Check.Nested (nestedTypes, admissible, referenced) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Foldable (sequence_, traverse_)
import Data.Maybe (Maybe(..), maybe')
import Data.Traversable (traverse)
import Data.Tuple (Tuple(..))
import Domain.Checked.Internal as Checked
import Domain.Ids (EffectId(..))
import Domain.Problem (Problem(..))
import Domain.Resolved (CtorId(..), EffectInfo)
import Domain.Row (EffectRef(..), Label(..))
import Domain.Syntax
  ( Diagnostic
  , RefSpine
  , Span
  , TypeArgument(..)
  , TypeRef(..)
  , handlerLabelRef
  , problemAt
  , typeRefSpan
  , typeRefSpine
  )
import Domain.Type (Ty(..), TypeId(..), VarId)
import Domain.Type.Parts (children)
import Features.Check.Components (components)

-- The instantiation rule over one reference graph of type and effect
-- declarations (design §4.1, FX001 design §4 "Layout dependencies"): an
-- edge for each declared type a constructor field or an operation's
-- parameter or result type mentions, however deeply, and for the effect
-- every `Handler(L …)` among them names: exactly the dependencies of the
-- specialization worklist's type and effect keys. Rows are erased there,
-- so labels inside rows are no edge. Inside a component, every type
-- argument of a reference must be a bare parameter of the referring
-- declaration or ground. The resolved type is walked alongside its source
-- reference, so the offence is reported at the nested reference itself.
nestedTypes ∷ Checked.Program → Either Diagnostic Unit
nestedTypes (Checked.Program program) = do
  typeNodes ← traverse typeNode program.types
  let nodes = typeNodes <> map effectNode program.effects
  component ← components (map (edges offset) nodes)
  traverse_ (judgeNode { component, names: map nodeName nodes, offset })
    (Array.mapWithIndex Tuple nodes)
  where
  offset = Array.length program.types
  typeNode info = typeNamed info <$> traverse (ctorAt info.span) info.ctors
  typeNamed info entries = { name: info.name, entries }
  ctorAt span (CtorId index) = maybe' (invalid span) (Right <<< ctorEntry)
    (Array.index program.ctors index)
  invalid span _ = Left (problemAt (Internal "Invalid constructor id") span)
  ctorEntry ctor =
    { span: ctor.span, types: ctor.fields, syntax: ctor.fieldSyntax }
  nodeName node = node.name

-- `admissible variable ty`: `ty` is a bare variable, or mentions no
-- variable that `variable` selects. Shared with the function half.
admissible ∷ ∀ v. (v → Boolean) → Ty v → Boolean
admissible variable = case _ of
  TVar _ → true
  ty → not (mentions variable ty)

-- A declaration of the graph: a type, whose entries are its constructors,
-- or an effect, whose entries are its operations; an entry's types are
-- beside their source references.
type Node = { name ∷ String, entries ∷ Array Entry }
type Entry = { span ∷ Span, types ∷ Array (Ty VarId), syntax ∷ Array TypeRef }

-- Types are nodes 0 to n - 1, effects n onwards (`offset` is n).
type Graph = { component ∷ Array Int, names ∷ Array String, offset ∷ Int }

-- An operation's parameter types, then its result.
effectNode ∷ EffectInfo → Node
effectNode effect = { name: effect.name, entries: map entry effect.operations }
  where
  entry operation =
    { span: operation.span
    , types: Array.snoc (map parameterType operation.parameters)
        operation.result
    , syntax: operation.syntax
    }
  parameterType parameter = parameter.ty

edges ∷ Int → Node → Array Int
edges offset node = Array.concatMap (layoutReferences offset)
  (Array.concatMap entryTypes node.entries)
  where
  entryTypes entry = entry.types

-- `referenced`, with the effect node a handler type names.
layoutReferences ∷ ∀ v. Int → Ty v → Array Int
layoutReferences offset = case _ of
  TData (TypeId index) arguments _ → Array.cons index
    (Array.concatMap recur arguments)
  THandler (Label (UserEffect (EffectId index)) arguments) _ → Array.cons
    (offset + index)
    (Array.concatMap recur arguments)
  ty → Array.concatMap recur (children ty)
  where
  recur ty = layoutReferences offset ty

judgeNode ∷ Graph → Tuple Int Node → Either Diagnostic Unit
judgeNode graph (Tuple index node) = traverse_ judgeEntry node.entries
  where
  judgeEntry entry = paired entry.span entry.types entry.syntax
    (judgeField graph inside)
  inside other = Array.index graph.component other
    == Array.index graph.component index

-- Pre-order: a reference is judged before the references in its
-- arguments, so the outermost offending one is reported. An arrow's
-- parameters and final result are walked beside its written spine, in
-- source order, by a loop along the spine (`children`, `typeRefSpine`);
-- a handler type's label arguments beside its label's (FX001).
judgeField
  ∷ Graph
  → (Int → Boolean)
  → Ty VarId
  → TypeRef
  → Either Diagnostic Unit
judgeField graph inside ty syntax = case ty, syntax of
  TData (TypeId index) arguments _, NamedRef span _ references → reference
    span
    index
    arguments
    (Array.mapMaybe typeArgument references)
  TData _ _ _, _ → Left (mismatch (typeRefSpan syntax))
  THandler label _, _ → maybe' (const (Left (mismatch (typeRefSpan syntax))))
    (handler label)
    (handlerLabelRef syntax)
  TFun _ _ _, FunRef span _ _ _ → paired span (children ty)
    (spineParts (typeRefSpine syntax))
    recur
  TFun _ _ _, _ → Left (mismatch (typeRefSpan syntax))
  _, _ → Right unit
  where
  recur = judgeField graph inside
  handler (Label effect arguments) written = case effect of
    UserEffect (EffectId index) → reference written.span
      (graph.offset + index)
      arguments
      written.arguments
    _ → paired written.span arguments written.arguments recur
  reference span index arguments references = offending span index arguments
    *> paired span arguments references recur
  offending span index arguments
    | inside index && not (Array.all (admissible always) arguments) =
        maybe' (missing span) (nested span) (Array.index graph.names index)
    | otherwise = Right unit
  nested span name = Left (problemAt (NestedDatatype name) span)
  missing span _ = Left (problemAt (Internal "Invalid type id") span)
  always _ = true
  typeArgument = case _ of
    TypeArgument foundType → Just foundType
    RowArgument _ → Nothing

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

spineParts ∷ RefSpine → Array TypeRef
spineParts found = Array.snoc found.parameters found.result

mismatch ∷ Span → Diagnostic
mismatch = problemAt (Internal "Field syntax mismatch")

-- An arrow is a constructor of two arguments to the reference graph: the
-- types its parameters and result mention are referenced.
referenced ∷ ∀ v. Ty v → Array Int
referenced = case _ of
  TData (TypeId index) arguments _ → Array.cons index
    (Array.concatMap referenced arguments)
  ty → Array.concatMap referenced (children ty)

mentions ∷ ∀ v. (v → Boolean) → Ty v → Boolean
mentions variable = case _ of
  TVar each → variable each
  ty → Array.any (mentions variable) (children ty)
