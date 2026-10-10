module Features.Check (check) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..), either, hush)
import Data.Map as Map
import Data.Maybe (Maybe(..), maybe, maybe')
import Data.Traversable (traverse)
import Data.Tuple (Tuple(..))
import Domain.Checked.Internal (rigid, Open(..))
import Domain.Row (Row(..))
import Domain.Type (Ty(..), TyRow, VarId(..))
import Features.Check.Entry as Entry
import Features.Check.Printable (printable)
import Domain.Checked.Internal as Checked
import Domain.Resolved as Resolved
import Domain.Problem (EntryKind(..), Problem(..))
import Domain.Syntax (Diagnostic, origin, problemAt)
import Features.Check.Comparable (comparable)
import Features.Check.Coverage (coverage)
import Features.Check.Functional (Functional, containsFunction, functional)
import Features.Check.Infer (Env, infer)
import Features.Check.Instantiation (instantiationRule)
import Features.Check.Require (require, tooDeepAt)
import Features.Check.Scheme (State, firstTooDeep, holes, resolved, start)
import Features.Check.Unify (Subst, isEmpty)
import Features.Check.Walk (retype)
import Features.Check.Defer (settleDeferred)
import Features.Check.Failure (settleKeys)
import Features.Check.Path (expandPath)

check ∷ Resolved.Program → Either Diagnostic Checked.Program
check program = do
  printableEntry holders program
  functions ← traverse checkDefinition program.functions
  let
    checked = Checked.Program
      { effects: program.effects
      , types: program.types
      , ctors: program.ctors
      , functions
      , entry: program.entry
      }
  -- The instantiation rule needs every body's final types; coverage runs
  -- last, on a program whose specialization is known to be finite.
  instantiationRule checked
  coverage checked
  pure checked
  where
  holders = functional program.ctors
  checkDefinition definition = either explained (Right <<< _.function)
    (rechecked definition)
  rechecked definition = checkFunction holders
    (environment program definition)
    definition
  -- A rejection's notes may end in a call: the callee's own check says
  -- where in its body the label arose (design §6).
  explained diagnostic = Left
    (diagnostic { related = expandPath locate diagnostic.related })
  locate name = relocated =<< Array.find (named name) program.functions
  named name definition = definition.name == name
  relocated definition = located definition <$> hush (rechecked definition)
  located definition result =
    { name: definition.name, span: definition.span, state: result.state }

-- `main`'s result is printed, so it may hold no function, directly or
-- through a declared type's fields (FN001 design §3). Resolve has already
-- made it ground; judged before any body, as Resolve judges `main` first.
printableEntry ∷ Functional → Resolved.Program → Either Diagnostic Unit
printableEntry holders program =
  maybe' missing judged (Array.index program.functions (index program.entry))
  where
  index (Resolved.FunctionId entry) = entry
  missing _ = Left (problemAt (Internal "Invalid entry") nowhere)
  nowhere = { start: origin, end: origin }
  judged main =
    if containsFunction holders main.result then Left
      (problemAt (EntryProblem EntryFunction) main.span)
    else Right unit

environment ∷ Resolved.Program → Resolved.FunctionDecl → Env
environment program function =
  { current: row
  , sites: [ { span: function.span, count: labelCount row } ]
  , functionName: function.name
  , functionSpan: function.span
  , effects: program.effects
  , functions: program.functions
  , types: program.types
  , ctors: program.ctors
  , variables: function.variables
  , locals: Map.fromFoldable
      (Array.mapWithIndex parameterLocal function.parameters)
  }
  where
  row = current function
  labelCount (Row labels _) = Array.length labels
  parameterLocal index parameter =
    Tuple (Resolved.LocalId index) (rigid parameter.ty)

-- Parameters bind rigid types; the body is inferred; then the result
-- unifies; then every type in the body is bounded again (a type bounded
-- when built deepens as its metas are bound); then the body's comparisons
-- must be ground; then the metas still unsolved become holes.
checkFunction
  ∷ Functional
  → Env
  → Resolved.FunctionDecl
  → Either Diagnostic { function ∷ Checked.FunctionDecl, state ∷ State }
checkFunction holders env function = do
  body ← infer env (start { next = Array.length function.variables })
    function.body
  finished ← require env body.state (rigid function.result) body.value
  maybe (Right unit) tooDeepAt (firstTooDeep finished.subst body.value)
  firstSubst ← settleKeys env finished body.value
  laterSubst ← settleDeferred env (finished { subst = firstSubst })
  settledSubst ← settleKeys env (finished { subst = laterSubst }) body.value
  let settled = settle settledSubst body.value
  let ended = finished { subst = settledSubst }
  comparable holders env settled
  printable holders env settled
  Entry.check env ended function
  pure
    { function:
        { id: function.id
        , name: function.name
        , parameters: map parameterType function.parameters
        , result: rigid function.result
        , row: Entry.resolvedRow settledSubst env.current
        , body: holes settled
        , span: function.span
        }
    , state: ended
    }
  where
  parameterType parameter = rigid parameter.ty

-- Every type in the body, resolved. An empty substitution resolves each
-- type to itself, so a body that bound no meta (every monomorphic one) is
-- kept rather than rebuilt (T003).
settle ∷ Subst → Checked.Expr → Checked.Expr
settle subst body =
  if isEmpty subst then body else retype (resolved subst) body

current ∷ Resolved.FunctionDecl → TyRow Open
current function = case rigid (TFun TUnit function.row TUnit) of
  TFun _ row _ → if function.name == "main" then mainRow row else row
  _ → Row [] Nothing
  where
  mainRow (Row labels tail) = Row labels (map flexible tail)
  flexible (Rigid (VarId index)) = Hole index
  flexible hole = hole
