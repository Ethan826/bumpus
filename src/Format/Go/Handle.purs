-- `with`, `handle` and `fail` (FX001 design §3, §4). Each of `with` and
-- `handle` is lifted, as a match is (E005), to a top-level function of
-- the locals its body reads; the k-th is waxwingFn{f}With{k} or
-- waxwingFn{f}Handle{k}, numbered in pre-order with the node before its
-- parts and sharing the counter with matches, lambdas and blocks.
--
-- `with h { body }` evaluates `h` at the call site, before the helper
-- runs; the helper pushes it onto its own `ctx` and runs the body, so
-- leaving needs no pop. `handle` allocates one fresh marker per family
-- and frame, runs the body in waxwingHandle (which recovers only aborts
-- aimed at those markers) and, after it returns, runs the matching clause
-- in the context of the `handle` itself. `fail(e)` evaluates `e`, then
-- panics at the innermost frame of e's family.
module Format.Go.Handle (lowerInstall, lowerHandle, lowerAbort) where

import Prelude
import Data.Array as Array
import Data.Foldable (foldl)
import Data.Tuple (Tuple(..))
import Data.String.Common (joinWith)
import Domain.IR.Internal as IR
import Data.Maybe (maybe)
import Domain.IR.Internal (Ty(..))
import Domain.Resolved (LocalId)
import Domain.Row (TypeHead)
import Format.Go.Capture (Free, union, without)
import Format.Go.Context (contextParameter, failKey)
import Format.Go.Data (functionName, goType, localName, malformed)
import Format.Go.Report (abortReport)
import Format.Go.Lowered
  ( Lowered
  , Lowering
  , Scope
  , Shape
  , effectShape
  , several
  )

lowerInstall
  ∷ Scope → Lowering → Int → Ty → IR.Expr → IR.Expr → Lowered
lowerInstall scope lower next result handler body =
  { code: name <> "("
      <> joinWith ", "
        ([ "ctx" ] <> map capturedName captured <> [ held.code ])
      <> ")"
  , next: inner.next
  , lifted: [ lifted ] <> held.lifted <> inner.lifted
  , free: union [ inner.free, held.free ]
  , wrappers: held.wrappers <> inner.wrappers
  }
  where
  name = functionName scope.owner <> "With" <> show next
  held = lower (next + 1) handler
  inner = lower held.next body
  captured = inner.free
  key = installKey scope.shape (IR.typeOf handler)
  lifted = "func " <> name <> "("
    <> joinWith ", "
      ( [ contextParameter ] <> map parameter captured
          <> [ "waxwingHandler " <> goType (IR.typeOf handler) ]
      )
    <> ") "
    <> goType result
    <> " {\nctx = waxwingInstall(ctx, "
    <> key
    <> ", waxwingHandler)\nreturn "
    <> inner.code
    <> "\n}\n"

-- The key's Go text. A non-handler type or a missing layout is a compiler
-- bug: the install panics as a malformed value would (Format.Go.Data).
installKey ∷ Shape → Ty → String
installKey shape = case _ of
  THandler key → maybe malformedKey (show <<< layoutKey)
    (effectShape shape key)
  _ → malformedKey
  where
  layoutKey layout = layout.key
  malformedKey = "func() int { " <> malformed <> " }()"

lowerHandle
  ∷ Scope → Lowering → Int → Ty → IR.Expr → Array IR.FailClause → Lowered
lowerHandle scope lower next result body clauses =
  { code: name <> "("
      <> joinWith ", " ([ "ctx" ] <> map capturedName captured)
      <> ")"
  , next: parts.next
  , lifted: [ lifted ] <> inner.lifted <> parts.lifted
  , free: captured
  , wrappers: inner.wrappers <> parts.wrappers
  }
  where
  name = functionName scope.owner <> "Handle" <> show next
  inner = lower (next + 1) body
  parts = several lower inner.next (map clauseBody clauses)
  clauseBody found = found.body
  captured = union ([ inner.free ] <> Array.zipWith unbound clauses parts.frees)
  unbound found free = without found.local free
  lifted = handleFunction name result captured inner.code
    (Array.zipWith Branch clauses parts.codes)

-- A failure clause and its lowered body.
data Branch = Branch IR.FailClause String

handleFunction ∷ String → Ty → Free → String → Array Branch → String
handleFunction name result captured body branches =
  "func " <> name <> "("
    <> joinWith ", " ([ contextParameter ] <> map parameter captured)
    <> ") "
    <> goType result
    <> " {\n"
    <> joinWith "" (Array.mapWithIndex markerLine branches)
    <> "result, caught := waxwingHandle([]*waxwingMarker{"
    <> joinWith ", " (Array.mapWithIndex markerName branches)
    <> "}, "
    <> frames branches
    <> ", func(ctx *waxwingCtx) "
    <> goType result
    <> " { return "
    <> body
    <> " })\nif caught != nil {\nswitch caught.target {\n"
    <> joinWith "" (Array.mapWithIndex branchCase branches)
    <> "}\n}\nreturn result\n}\n"

markerName ∷ ∀ a. Int → a → String
markerName index _ = "marker" <> show index

markerLine ∷ Int → Branch → String
markerLine index branch = markerName index branch
  <> " := &waxwingMarker{}\n"

-- The context the body runs in: one frame per family over the `handle`'s
-- own context, the first clause innermost: the checker types the body
-- against the first clause of a family (first occurrence wins, design §2).
-- The clauses run outside it.
frames ∷ Array Branch → String
frames branches = foldl push "ctx"
  (Array.reverse (Array.mapWithIndex Tuple branches))
  where
  push inner (Tuple index branch) = "waxwingFrame(" <> inner <> ", "
    <> show (failKey (familyOf branch))
    <> ", "
    <> markerName index branch
    <> ")"

familyOf ∷ Branch → TypeHead
familyOf (Branch clause _) = clause.family

branchCase ∷ Int → Branch → String
branchCase index branch@(Branch clause code) =
  "case " <> markerName index branch <> ":\n"
    <> localName clause.local
    <> " := caught.payload.("
    <> goType clause.payload
    <> ")\n_ = "
    <> localName clause.local
    <> "\nreturn "
    <> code
    <> "\n"

capturedName ∷ ∀ r. { id ∷ LocalId | r } → String
capturedName local = localName local.id

parameter ∷ ∀ r. { id ∷ LocalId, ty ∷ Ty | r } → String
parameter local = localName local.id <> " " <> goType local.ty

lowerAbort ∷ Scope → Lowering → Int → Ty → TypeHead → IR.Expr → Lowered
lowerAbort scope lower next result head value = payload
  { code = "waxwingFail[" <> goType result <> "](ctx, "
      <> show (failKey head)
      <> ", "
      <> payload.code
      <> ", "
      <> abortReport scope (IR.typeOf value)
      <> ")"
  }
  where
  payload = lower next value
