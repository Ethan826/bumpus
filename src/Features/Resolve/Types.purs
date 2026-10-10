module Features.Resolve.Types (typeTable, resolveType, resolveTypeWith) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (Maybe(..), maybe')
import Data.Traversable (traverse)
import Data.Tuple (Tuple(..))
import Control.Monad.Rec.Class (Step(..), tailRec)
import Domain.Problem (Problem(..), UnboundKind(..))
import Domain.Syntax as Syntax
import Domain.Resolved as Resolved
import Features.Resolve.Row (label, resolveRow)
import Features.Resolve.HandlerType as HandlerType
import Features.Resolve.TypeValidation as TypeValidation
import Features.Resolve.Variables (uniqueTypeParameters)

-- `parameters` are the owner's, the variables its fields may name.
type Owned =
  { id ∷ Resolved.CtorId
  , owner ∷ Resolved.TypeId
  , parameters ∷ Array String
  , decl ∷ Syntax.CtorDecl
  }

-- A function or constructor name, for the shared-namespace duplicate check.
-- Declarations are checked in the order the spec fixes: types, constructors,
-- functions and parameters, then type parameters, then constructor fields.
typeTable ∷ Syntax.Program → Either Syntax.Diagnostic Resolved.Tables
typeTable program = do
  TypeValidation.uniqueTypes program.types
  TypeValidation.uniqueCtors program.functions program.types
  TypeValidation.uniqueFunctions program.functions
  uniqueTypeParameters program.types
  ctors ← traverse (resolveCtor types effects) owned
  pure { types, ctors }
  where
  effects = map summary program.effects
  summary effect =
    { name: effect.name, arity: Array.length effect.parameters }
  owned = ownedCtors program.types
  types = Array.zipWith typeInfo (firstCtors program.types) program.types

-- `variables` are those in scope: `VarId i` is the i-th. A declared type
-- takes exactly as many arguments as it has parameters, else E_ARITY at the
-- whole reference, which is checked before its arguments.
resolveType
  ∷ Array Resolved.TypeInfo
  → Array String
  → Syntax.TypeRef
  → Either Syntax.Diagnostic (Resolved.Ty Resolved.VarId)
resolveType types variables = resolveTypeWith types [] variables Nothing

resolveTypeWith
  ∷ Array Resolved.TypeInfo
  → Array { name ∷ String, arity ∷ Int }
  → Array String
  → Maybe Resolved.VarId
  → Syntax.TypeRef
  → Either Syntax.Diagnostic (Resolved.Ty Resolved.VarId)
resolveTypeWith types effects variables ambient = resolved
  where
  resolved = case _ of
    Syntax.IntRef _ → pure Resolved.TInt
    Syntax.BoolRef _ → pure Resolved.TBool
    Syntax.UnitRef _ → pure Resolved.TUnit
    Syntax.VarRef span name → maybe' (unbound UnboundTypeVariable span name)
      variable
      (Array.elemIndex name variables)
    Syntax.NamedRef span name arguments → maybe'
      (missingType span name arguments)
      (applied span name arguments)
      (Array.findIndex (named name) types)
    Syntax.THandlerRef _ reference row → Resolved.THandler
      <$> label effects resolved reference
      <*> resolveRow effects variables ambient resolved row
    arrow@(Syntax.FunRef _ _ _ _) → spine arrow
  spine arrow = do
    parameters ← traverse resolved (Syntax.typeRefSpine arrow).parameters
    rows ← traverse (resolveRow effects variables ambient resolved)
      (arrowRows arrow)
    result ← resolved (Syntax.typeRefSpine arrow).result
    pure (Array.foldr stage result (Array.zip parameters rows))
  stage pair result = Resolved.TFun (first pair) (second pair) result
  first (Tuple value _) = value
  second (Tuple _ value) = value
  variable index = pure (Resolved.TVar (Resolved.VarId index))
  named name info = info.name == name
  missingType span name arguments _
    | name == "Handler" = HandlerType.resolve effects variables ambient
        resolved
        span
        arguments
    | otherwise = unbound UnboundType span name unit
  applied span _ arguments index = maybe' invalid
    (appliedTo span arguments index)
    (Array.index types index)
  invalid _ = Left (Syntax.problemAt (Internal "Invalid type id") nowhere)
  appliedTo span arguments index info
    | Array.length arguments /= Array.length info.sourceSorts = Left
        (Syntax.problemAt (TypeArguments info.name) span)
    | otherwise =
        do
          typeArguments ← traverse resolveTypeArgument typeArgumentsSyntax
          rowArguments ← traverse resolveRowArgument rowArgumentsSyntax
          pure
            (Resolved.TData (Resolved.TypeId index) typeArguments rowArguments)
        where
        ordered sort = Array.mapMaybe (matching sort)
          (Array.zip info.sourceSorts arguments)
        matching sort (Tuple foundSort argument) =
          if foundSort == sort then Just argument else Nothing
        typeArgumentsSyntax = ordered Syntax.TypeSort
        rowArgumentsSyntax = ordered Syntax.RowSort
        resolveTypeArgument = typeArgument
        typeArgument = case _ of
          Syntax.TypeArgument reference → resolved reference
          Syntax.RowArgument row → sortError false (rowSpan row)
        resolveRowArgument = rowArgument
        rowArgument = case _ of
          Syntax.RowArgument row → resolveRow effects variables ambient
            resolved
            (Just (closedRowArgument row))
          Syntax.TypeArgument
            ( Syntax.NamedRef referenceSpan effectName
                effectArguments
            ) → maybe' (notAnEffect referenceSpan)
            (effectRow referenceSpan effectName effectArguments)
            (Array.findIndex (namedEffect effectName) effects)
          Syntax.TypeArgument reference → sortError true
            (Syntax.typeRefSpan reference)
        effectRow referenceSpan effectName effectArguments _ = do
          argumentTypes ← traverse effectTypeArgument effectArguments
          resolveRow effects variables ambient resolved
            ( Just
                ( Syntax.RowRef referenceSpan
                    [ { name: effectName
                      , arguments: argumentTypes
                      , span: referenceSpan
                      }
                    ]
                    Nothing
                )
            )
        effectTypeArgument = case _ of
          Syntax.TypeArgument reference → Right reference
          Syntax.RowArgument row → sortError false (rowSpan row)
        namedEffect effectName effect = effect.name == effectName
        notAnEffect referenceSpan _ = sortError true referenceSpan
        closedRowArgument (Syntax.RowRef argumentSpan labels tail) =
          Syntax.RowRef
            argumentSpan
            labels
            (maybe' pureTail Just tail)
        pureTail _ = Just Syntax.Pure

  sortError ∷ ∀ a. Boolean → Syntax.Span → Either Syntax.Diagnostic a
  sortError expectedRow span = Left
    (Syntax.problemAt (RowSort expectedRow) span)
  rowSpan (Syntax.RowRef span _ _) = span
  nowhere = { start: Syntax.origin, end: Syntax.origin }
  unbound kind span name _ = Left
    (Syntax.problemAt (Unbound kind name) span)

ownedCtors ∷ Array Syntax.TypeDecl → Array Owned
ownedCtors types = Array.mapWithIndex numbered
  (Array.concat (Array.mapWithIndex ownedBy types))
  where
  ownedBy index declaration = map
    (withOwner (Resolved.TypeId index) (parameterNames declaration.parameters))
    declaration.ctors
  name parameter = parameter.name
  parameterNames parameters = map name (Array.filter isType parameters)
    <> map name (Array.filter isRow parameters)
  isType parameter = parameter.sort == Syntax.TypeSort
  isRow parameter = parameter.sort == Syntax.RowSort
  withOwner owner parameters decl = { owner, parameters, decl }
  numbered index entry =
    { id: Resolved.CtorId index
    , owner: entry.owner
    , parameters: entry.parameters
    , decl: entry.decl
    }

-- Constructors are numbered in declaration order (ownedCtors), so each type
-- owns the run of ids after all earlier types' constructors. Filtering every
-- constructor per type was O(types × constructors) (A003 final review I3).
firstCtors ∷ Array Syntax.TypeDecl → Array Int
firstCtors types = Array.zipWith sub (Array.scanl add 0 counts) counts
  where
  counts = map ctorCount types
  ctorCount declaration = Array.length declaration.ctors

typeInfo ∷ Int → Syntax.TypeDecl → Resolved.TypeInfo
typeInfo first declaration =
  { name: declaration.name
  , parameters: map parameterName (typeParameters declaration.parameters)
  , rowParameters: map parameterName (rowParameters declaration.parameters)
  , variables: map parameterName (typeParameters declaration.parameters)
      <> map parameterName (rowParameters declaration.parameters)
  , sorts:
      Array.replicate (Array.length (typeParameters declaration.parameters))
        Syntax.TypeSort <> Array.replicate
        (Array.length (rowParameters declaration.parameters))
        Syntax.RowSort
  , sourceSorts: map parameterSort declaration.parameters
  , ctors: Array.mapWithIndex ctorId declaration.ctors
  , span: declaration.span
  }
  where
  ctorId position _ = Resolved.CtorId (first + position)
  parameterName parameter = parameter.name
  typeParameters = Array.filter (hasSort Syntax.TypeSort)
  rowParameters = Array.filter (hasSort Syntax.RowSort)
  hasSort sort parameter = parameter.sort == sort
  parameterSort parameter = parameter.sort

resolveCtor
  ∷ Array Resolved.TypeInfo
  → Array { name ∷ String, arity ∷ Int }
  → Owned
  → Either Syntax.Diagnostic Resolved.CtorInfo
resolveCtor types effects entry = withFields <$> traverse field
  entry.decl.fields
  where
  field reference = resolveTypeWith types effects entry.parameters Nothing
    reference
  withFields fields =
    { name: entry.decl.name
    , owner: entry.owner
    , fields
    , fieldSyntax: entry.decl.fields
    , span: entry.decl.span
    }

arrowRows ∷ Syntax.TypeRef → Array (Maybe Syntax.RowRef)
arrowRows reference = Array.reverse (tailRec step { rest: reference, rows: [] })
  where
  step found = case found.rest of
    Syntax.FunRef _ _ row rest → Loop
      { rest, rows: Array.cons row found.rows }
    _ → Done found.rows
