module Features.Check.Argument (refused) where

import Prelude
import Data.Array as Array
import Data.Either (either)
import Data.Maybe (Maybe(..), fromMaybe, maybe)
import Domain.Checked.Internal (Open)
import Domain.Checked.Internal as Checked
import Domain.Problem (Problem(RowEquality, MustBePure), RowText)
import Domain.Row (Row(..), isPure)
import Domain.Type.Parts (rowsOf)
import Domain.Syntax (Diagnostic, Note, NoteReason(..), Sort(..))
import Domain.Type (Ty(..))
import Features.Check.Context (CheckEnv)
import Features.Check.Report (noteAt)
import Features.Check.Scheme (State, flexible)
import Features.Check.Unify (Failure(..), Flex(..), resolveRow, unify)
import Features.Check.Use (Callee, Use)

-- An argument the checker refused at a parameter of a named function: the
-- diagnostic gains the parameter as the boundary when it must be pure, and
-- the row variable as declared when two rows conflict. A conflict's tail
-- is a meta of this call, named by the callee's variable it instantiates
-- (design §6); the parameter's expected type and the argument's are
-- unified again to find it, on the failure path only.
refused
  ∷ ∀ r
  . CheckEnv r
  → State
  → Use
  → Int
  → Ty Open
  → Checked.Expr
  → Diagnostic
  → Diagnostic
refused env state use index expected actual diagnostic =
  maybe diagnostic noted use.callee
  where
  noted callee = case diagnostic.problem of
    MustBePure _ → diagnostic
      { related = diagnostic.related <> pureNote callee }
    RowEquality left right tail → conflict callee left right tail
    _ → diagnostic
  -- Only a parameter written `with pure` is the boundary: the same
  -- message also reports a closed pure argument given to a wider one.
  pureNote callee =
    if Array.any isPure (rowsOf expected) then parameter callee index
      (topRowPure expected)
    else []
  conflict callee left right tail =
    if tail == "" then maybe diagnostic (named callee left right)
      (calleeName state use callee (sharedTail callee))
    else diagnostic
      { related = diagnostic.related
          <> [ noteAt env.functionSpan (DeclaredHere ("..." <> tail)) ]
      }
  -- The conflict again, for the tail it names.
  sharedTail _ = either shared (const Nothing)
    (unify state.subst (flexible expected) (flexible (Checked.typeOf actual)))
  shared = case _ of
    RowSharedTail (Row _ tail) _ → tail
    _ → Nothing
  named callee left right name = diagnostic
    { problem = RowEquality (spelled name left) (spelled name right) name
    , related = diagnostic.related
        <> [ noteAt callee.span (DeclaredHere ("..." <> name)) ]
    }

spelled ∷ String → RowText → RowText
spelled name row = row { tail = map (const ("..." <> name)) row.tail }

-- The `with pure` annotation when the parameter's own arrow is the pure
-- one; for a pure row nested in its type, the parameter's name.
parameter ∷ Callee → Int → Boolean → Array Note
parameter callee index own = maybe [] (Array.singleton <<< pureNote)
  (Array.index callee.parameters index)
  where
  pureNote found = noteAt
    (if own then fromMaybe found.span found.rowSpan else found.span)
    MustBePureParameter

topRowPure ∷ Ty Open → Boolean
topRowPure = case _ of
  TFun _ row _ → isPure row
  _ → false

-- The callee's row variable whose meta, for this call, ended in `shared`.
calleeName ∷ State → Use → Callee → Maybe Flex → Maybe String
calleeName state use callee shared = Array.index callee.variables =<<
  Array.findIndex endsInShared positions
  where
  positions = Array.range 0 (Array.length callee.variables - 1)
  endsInShared position =
    Array.index callee.sorts position == Just RowSort
      && tailOf position == shared
  tailOf position =
    case
      resolveRow state.subst
        (Row [] (Just (Meta (use.scheme.base + position))))
      of
      Row _ tail → tail
