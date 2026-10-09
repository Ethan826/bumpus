module Domain.Type.Parts
  ( Spine
  , spine
  , spineThrough
  , arrows
  , ground
  , groundErased
  , children
  , rowsOf
  , rowArguments
  , typeHead
  ) where

import Prelude
import Prim hiding (Row)
import Data.Array as Array
import Data.Maybe (Maybe(..), maybe')
import Data.Traversable (traverse)
import Domain.Row (Label(..), Row(..), TypeHead(..), closedRow)
import Domain.Type (Stages, Ty(..), TyRow, foldStages, stagesThrough)

-- An arrow's parameters, in order, and its final result, which is not an
-- arrow. A type that is not an arrow is its own result.
type Spine v = { parameters ∷ Array (Ty v), result ∷ Ty v }

spine ∷ ∀ v. Ty v → Spine v
spine = spineThrough identity

-- Through `look`, as Domain.Type's `stagesThrough`, keeping parameters.
spineThrough ∷ ∀ v. (Ty v → Ty v) → Ty v → Spine v
spineThrough look ty =
  { parameters: Array.mapMaybe parameterOf staged.arrows
  , result: staged.result
  }
  where
  staged = stagesThrough look ty
  parameterOf = case _ of
    TFun parameter _ _ → Just parameter
    _ → Nothing

-- `arrows [a, b] r` is the pure `a -> b -> r`; Array.foldr is a loop.
arrows ∷ ∀ v. Array (Ty v) → Ty v → Ty v
arrows parameters result = Array.foldr pureArrow result parameters
  where
  pureArrow parameter rest = TFun parameter closedRow rest

-- The same type with no variable in it, if it has none: no type variable
-- and no row tail.
ground ∷ ∀ v. Ty v → Maybe (Ty Void)
ground ty = groundWith groundRow ty

-- The same with every row erased to the closed row: ground when no type
-- variable remains, whatever the rows. Specialization erases rows (design
-- §4), so a function polymorphic only in its effects is monomorphic
-- there, and `main` may have an open row.
groundErased ∷ ∀ v. Ty v → Maybe (Ty Void)
groundErased = groundWith erased
  where
  erased _ = Just closedRow

-- The types a structural pass enters: an application's type arguments, a
-- handler's label arguments, or an arrow's parameters followed by its
-- final result (never the arrows of the spine in between, so no pass
-- recurses once per arrow). Rows are apart: `rowsOf`.
children ∷ ∀ v. Ty v → Array (Ty v)
children = case _ of
  TData _ arguments _ → arguments
  THandler (Label _ arguments) _ → arguments
  arrow@(TFun _ _ _) → spineParts (spine arrow)
  _ → []
  where
  spineParts found = Array.snoc found.parameters found.result

-- The rows a structural pass enters beside `children`: an application's
-- row arguments, a handler's row, or each arrow's row along the spine.
rowsOf ∷ ∀ v. Ty v → Array (TyRow v)
rowsOf = case _ of
  TData _ _ rows → rows
  THandler _ row → [ row ]
  arrow@(TFun _ _ _) → Array.mapMaybe rowOf
    (stagesThrough identity arrow).arrows
  _ → []

-- An arrow node's row (`stages` keeps only arrows).
rowOf ∷ ∀ v. Ty v → Maybe (TyRow v)
rowOf = case _ of
  TFun _ row _ → Just row
  _ → Nothing

-- Every label's arguments, in order: the types a row holds.
rowArguments ∷ ∀ v. TyRow v → Array (Ty v)
rowArguments (Row labels _) = Array.concatMap labelArguments labels
  where
  labelArguments (Label _ arguments) = arguments

-- The declared identity a Fail payload is keyed by, if the type has one.
typeHead ∷ ∀ v. Ty v → Maybe TypeHead
typeHead = case _ of
  TInt → Just HeadInt
  TBool → Just HeadBool
  TUnit → Just HeadUnit
  TData id _ _ → Just (HeadData id)
  _ → Nothing

groundWith
  ∷ ∀ v. (TyRow v → Maybe (TyRow Void)) → Ty v → Maybe (Ty Void)
groundWith rowGround = case _ of
  TInt → Just TInt
  TBool → Just TBool
  TUnit → Just TUnit
  TData id arguments rows → TData id <$> traverse recur arguments
    <*> traverse rowGround rows
  TVar _ → Nothing
  THandler (Label effect arguments) row → THandler
    <$> (Label effect <$> traverse recur arguments)
    <*> rowGround row
  arrow@(TFun _ _ _) → groundStages recur rowGround
    (stagesThrough identity arrow)
  where
  recur ty = groundWith rowGround ty

-- Right to left: each arrow rebuilt once its result is ground.
groundStages
  ∷ ∀ v
  . (Ty v → Maybe (Ty Void))
  → (TyRow v → Maybe (TyRow Void))
  → Stages v
  → Maybe (Ty Void)
groundStages typeGround rowGround found = foldStages stage
  (typeGround found.result)
  found.arrows
  where
  stage parameter row rest = TFun <$> typeGround parameter
    <*> rowGround row
    <*> rest

-- A row is ground when closed and its labels' arguments are ground.
groundRow ∷ ∀ v. TyRow v → Maybe (TyRow Void)
groundRow (Row labels tail) = maybe' closedLabels open tail
  where
  closedLabels _
    | Array.null labels = Just closedRow
    | otherwise = Row <$> traverse groundLabel labels <*> pure Nothing
  open _ = Nothing

groundLabel ∷ ∀ v. Label (Ty v) → Maybe (Label (Ty Void))
groundLabel (Label effect arguments) = Label effect <$> traverse ground
  arguments
