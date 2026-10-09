-- `crash` and the description of a typed abort (FX001 design §3, §5). A
-- crash renders its argument as `print` does, then raises a defect with
-- that text. A `fail` site, in a program that can report (Format.Go.Cleanup),
-- passes a function that renders `fail(T): V` for its payload: T as
-- diagnostics print the type, V as `print` prints the value, or
-- `<not printable>` when T holds a function or a handler, which is decided
-- here from the type alone.
module Format.Go.Report (lowerCrash, abortReport) where

import Prelude
import Control.Monad.Rec.Class (Step(..), tailRec)
import Data.Array as Array
import Data.Foldable (foldl)
import Data.Maybe (Maybe(..), maybe)
import Data.Set (Set)
import Data.Set as Set
import Domain.IR.Internal as IR
import Domain.IR.Internal (EffectKey(..), Ty(..))
import Domain.Problem (TypeName(..))
import Domain.Resolved (TypeId(..))
import Format.Diagnostic (typeName)
import Format.Go.Data (goType)
import Format.Go.Layout (Layout)
import Format.Go.Lowered (Lowered, Lowering, Scope, Shape)
import Format.Go.Show (printed)

lowerCrash ∷ Lowering → Int → Ty → IR.Expr → Lowered
lowerCrash lower next result value = rendered
  { code = "waxwingCrash[" <> goType result <> "](fmt.Sprint("
      <> printed (IR.typeOf value) rendered.code
      <> "))"
  }
  where
  rendered = lower next value

-- The argument of waxwingFail: nil unless a report can happen.
abortReport ∷ Scope → Ty → String
abortReport scope payload
  | not scope.shape.defects = "nil"
  | holdsFunction scope.shape scope.tables payload =
      "func(any) string { return " <> described scope payload
        <> " + \"<not printable>\" }"
  | otherwise = "func(value any) string { return " <> described scope payload
      <> " + fmt.Sprint("
      <> printed payload ("value.(" <> goType payload <> ")")
      <> ") }"

described ∷ Scope → Ty → String
described scope payload = "\"fail("
  <> typeName (payloadName scope.shape payload)
  <> "): \""

payloadName ∷ Shape → Ty → TypeName
payloadName shape ty = case ty of
  TInt → IntName
  TBool → BoolName
  TUnit → UnitName
  TData (TypeId index) → maybe unknown named (Array.index shape.types index)
  TFun _ → arrow (IR.spine shape.funTypes ty)
  THandler (EffectKey index) → maybe unknown handler
    (Array.index shape.effectInfos index)
  where
  recur = payloadName shape
  unknown = DataName "?"
  named info = applied info.name (map recur info.arguments)
  -- The spine is walked by a loop (IR.spine), then folded, so an arrow of
  -- thousands of parameters costs no stack.
  arrow found = Array.foldr FunctionName (recur found.result)
    (map recur found.parameters)
  handler info = AppliedName "Handler"
    [ applied info.name (map recur info.arguments) ]

applied ∷ String → Array TypeName → TypeName
applied name arguments
  | Array.null arguments = DataName name
  | otherwise = AppliedName name arguments

-- Whether the type mentions an arrow or a handler, directly, as an
-- argument or through a declared type's fields, as Check.Functional
-- decides for the source type. One round per level of declared types, so
-- a chain of thousands costs no stack.
holdsFunction ∷ Shape → Layout → Ty → Boolean
holdsFunction shape tables start = tailRec round
  { frontier: [ start ], seen: Set.empty }
  where
  round state
    | Array.any direct state.frontier = Done true
    | otherwise = spread shape tables state

type Spread = { frontier ∷ Array Ty, seen ∷ Set TypeId }

-- The declared types of the frontier not yet visited, and what they hold.
spread ∷ Shape → Layout → Spread → Step Spread Boolean
spread shape tables state =
  if Array.null fresh then Done false
  else Loop
    { frontier: Array.concatMap (contents shape tables) fresh
    , seen: foldl insert state.seen fresh
    }
  where
  fresh = Array.nub (Array.mapMaybe (unseen state.seen) state.frontier)
  insert seen id = Set.insert id seen

direct ∷ Ty → Boolean
direct = case _ of
  TFun _ → true
  THandler _ → true
  _ → false

unseen ∷ Set TypeId → Ty → Maybe TypeId
unseen seen = case _ of
  TData id | not (Set.member id seen) → Just id
  _ → Nothing

-- A declared type's type arguments and its constructors' field types.
contents ∷ Shape → Layout → TypeId → Array Ty
contents shape tables (TypeId index) = arguments <> fields
  where
  arguments = maybe [] typeArguments (Array.index shape.types index)
  typeArguments info = info.arguments
  fields = maybe [] memberFields (Array.index tables.types index)
  memberFields declared = Array.concatMap fieldsOf declared.members
  fieldsOf member = member.ctor.fields
