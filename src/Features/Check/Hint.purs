module Features.Check.Hint (Declared, hinted) where

import Prelude
import Data.Array as Array
import Data.Maybe (Maybe(..), maybe)
import Domain.Checked.Internal (Open(..))
import Domain.Checked.Internal as Checked
import Domain.Problem (Hint(..), Problem(..))
import Domain.Resolved (CtorId(..), CtorInfo, FunctionDecl, FunctionId(..))
import Domain.Syntax (Diagnostic)
import Domain.Type (Ty(..))
import Features.Check.Scheme (State, headOf)

-- The fields the hint needs to name a callee and count its declared arity.
type Declared r =
  (functions ∷ Array FunctionDecl, ctors ∷ Array CtorInfo | r)

-- FN001 design §4, the provenance rules: a type mismatch whose found
-- expression is, through parentheses only (which leave no node), a direct
-- partial application `f(a1…aj)`, 0 < j < n, of a named function or
-- constructor, and whose expected type is neither a function nor a meta,
-- gains `MissingArguments f (n - j)`. A type mismatch whose found
-- expression is, through parentheses only, a block made Unit by a
-- trailing `;` gains `TrailingSemicolon` (FX001 design §1), whatever was
-- expected: Unit was not. Computed after the failure from the state
-- before it, with no further unification; the problem it wraps keeps its
-- code, span and text. Anything else is returned unchanged.
hinted
  ∷ ∀ r
  . { | Declared r }
  → State
  → Ty Open
  → Checked.Expr
  → Diagnostic
  → Diagnostic
hinted env state expected actual diagnostic = case diagnostic.problem of
  TypeMismatch _ _
    | trailing actual → wrap TrailingSemicolon
    | not (functionOrMeta (headOf state expected)) → maybe diagnostic wrap
        (missing env actual)
  _ → diagnostic
  where
  wrap hint = diagnostic { problem = Hinted diagnostic.problem hint }

-- A block whose items end in `;` has the value `()` at its closing `}`
-- (Domain.Syntax `Item`), so that value ends where the block does; a
-- written value never does.
trailing ∷ Checked.Expr → Boolean
trailing (Checked.Expr expression) = case expression.node of
  Checked.Block _ value → closing value
  _ → false
  where
  closing (Checked.Expr found) = case found.node of
    Checked.UnitValue → found.span.end.offset == expression.span.end.offset
    _ → false

functionOrMeta ∷ Ty Open → Boolean
functionOrMeta = case _ of
  TFun _ _ _ → true
  TVar (Hole _) → true
  _ → false

missing ∷ ∀ r. { | Declared r } → Checked.Expr → Maybe Hint
missing env (Checked.Expr expression) = case expression.node of
  Checked.Call (FunctionId index) _ arguments →
    Array.index env.functions index >>= function arguments
  Checked.Construct (CtorId index) _ arguments →
    Array.index env.ctors index >>= ctor arguments
  _ → Nothing
  where
  function arguments declared = short declared.name
    (Array.length declared.parameters)
    (Array.length arguments)
  ctor arguments info = short info.name (Array.length info.fields)
    (Array.length arguments)

short ∷ String → Int → Int → Maybe Hint
short name arity supplied =
  if supplied > 0 && supplied < arity then
    Just (MissingArguments name (arity - supplied))
  else Nothing
