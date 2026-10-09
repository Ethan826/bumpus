module Features.Check.Unlowered (reject) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..))
import Data.Foldable (any)
import Data.Maybe (Maybe(..), maybe')
import Domain.Checked.Internal as Checked
import Domain.Problem (Problem(..))
import Domain.Resolved as Resolved
import Domain.Syntax (Diagnostic, Span, problemAt)
import Domain.Type (Ty(..), TyRow)
import Domain.Type.Parts as Parts

-- User effects and handlers need runtime evidence, which Task 7 lowers.
reject ∷ Checked.Program → Either Diagnostic Unit
reject (Checked.Program program) = maybe' noEffects effectDeclared
  (Array.head program.effects)
  where
  noEffects _ = maybe' clean unlowered
    (firstProgramSpecial (Checked.Program program))
  effectDeclared effect = unlowered effect.span
  clean _ = Right unit
  unlowered span = Left (problemAt (Internal "unlowered effect") span)

firstProgramSpecial ∷ Checked.Program → Maybe Span
firstProgramSpecial (Checked.Program program) = firstOf
  [ firstArray (map ctorSpecial program.ctors)
  , firstArray (map effectSpecial program.effects)
  , firstArray (map functionSpecial program.functions)
  ]

ctorSpecial ∷ Resolved.CtorInfo → Maybe Span
ctorSpecial ctor = firstArray (map (typeAt ctor.span) ctor.fields)

effectSpecial ∷ Resolved.EffectInfo → Maybe Span
effectSpecial effect = firstArray (map operationSpecial effect.operations)

operationSpecial ∷ Resolved.OperationInfo → Maybe Span
operationSpecial operation = firstOf
  [ firstArray (map (parameterAt operation.span) operation.parameters)
  , firstTypeAt (Just operation.result) operation.span
  ]

functionSpecial ∷ Checked.FunctionDecl → Maybe Span
functionSpecial function = firstOf
  [ firstArray (map (typeAt function.span) function.parameters)
  , firstTypeAt (Just function.result) function.span
  , rowAt function.span function.row
  , firstSpecial function.body
  ]

typeAt ∷ ∀ v. Span → Ty v → Maybe Span
typeAt span ty = firstTypeAt (Just ty) span

parameterAt ∷ Span → Resolved.Parameter → Maybe Span
parameterAt span parameter = typeAt span parameter.ty

firstTypeAt ∷ ∀ v. Maybe (Ty v) → Span → Maybe Span
firstTypeAt found span = maybe' absent present found
  where
  absent _ = Nothing
  present ty = if containsHandler ty then Just span else Nothing

containsHandler ∷ ∀ v. Ty v → Boolean
containsHandler ty = case ty of
  THandler _ _ → true
  _ → any containsHandler (Parts.children ty)
    || any rowContainsHandler (Parts.rowsOf ty)

rowContainsHandler ∷ ∀ v. TyRow v → Boolean
rowContainsHandler row = any containsHandler (Parts.rowArguments row)

rowAt ∷ Span → TyRow Checked.Open → Maybe Span
rowAt span row = if rowContainsHandler row then Just span else Nothing

firstSpecial ∷ Checked.Expr → Maybe Span
firstSpecial (Checked.Expr expression) = case expression.node of
  Checked.OperationRef _ _ _ → Just expression.span
  Checked.Perform _ _ _ _ → Just expression.span
  Checked.Handler _ _ _ → Just expression.span
  Checked.With _ _ → Just expression.span
  Checked.Handle _ _ → Just expression.span
  Checked.Fail _ → Just expression.span
  node → firstOf
    [ firstTypeAt (Just expression.ty) expression.span
    , firstArray (map firstSpecial (children node))
    ]

children ∷ Checked.Node → Array Checked.Expr
children = case _ of
  Checked.Call _ _ arguments → arguments
  Checked.Construct _ _ arguments → arguments
  Checked.Add left right → [ left, right ]
  Checked.Compare _ left right → [ left, right ]
  Checked.If condition yes no → [ condition, yes, no ]
  Checked.Match scrutinee arms → Array.cons scrutinee (map armBody arms)
  Checked.Apply callee arguments → Array.cons callee arguments
  Checked.Lambda _ body → [ body ]
  Checked.Pipe left right → [ left, right ]
  Checked.Print value → [ value ]
  Checked.Block items value → Checked.blockParts items value
  _ → []

armBody ∷ Checked.Arm → Checked.Expr
armBody arm = arm.body

firstArray ∷ Array (Maybe Span) → Maybe Span
firstArray = Array.head <<< Array.catMaybes

firstOf ∷ Array (Maybe Span) → Maybe Span
firstOf = Array.head <<< Array.catMaybes
