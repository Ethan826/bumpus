module Features.Check.Failure (failExpression, settleKeys) where

import Prelude
import Data.Array as Array
import Data.Either (Either(..), either)
import Data.Maybe (Maybe(..), maybe')
import Data.Tuple (Tuple(..))
import Domain.Checked.Internal as Checked
import Domain.Problem (Problem(..))
import Domain.Resolved as Resolved
import Domain.Row (EffectRef(..), Label(..), Row(..))
import Domain.Syntax (Diagnostic, Span, problemAt)
import Domain.Type (Ty(..))
import Domain.Type.Parts (typeHead)
import Features.Check.Context (CheckEnv, Infer, Locals)
import Features.Check.Consume (consumeAt)
import Features.Check.Provenance (Consumed(FailOf))
import Features.Check.Reject (rejected)
import Features.Check.Scheme (State, Threaded, opened, resolved)
import Features.Check.TypeName (typeName)
import Features.Check.Unify (Failure(..), Flex, Subst(..), settleRows)

type Result = Either Diagnostic (Threaded Checked.Expr)
type Env r = CheckEnv (locals ∷ Locals | r)

failExpression
  ∷ ∀ r
  . Infer (locals ∷ Locals | r)
  → Env r
  → State
  → Span
  → Resolved.Expr
  → Result
failExpression infer env state span value = do
  payload ← infer env state value
  consumed ← consumeAt env payload.state span (FailOf env.functionName)
    (Row [ Label FailEffect [ Checked.typeOf payload.value ] ] Nothing)
  pure
    { value: Checked.Expr
        { ty: TVar (Checked.Hole consumed.next)
        , span
        , node: Checked.Fail payload.value
        }
    , state: consumed { next = consumed.next + 1 }
    }

settleKeys
  ∷ ∀ r. CheckEnv r → State → Checked.Expr → Either Diagnostic Subst
settleKeys env state body = either failed checked (settleRows state.subst)
  where
  failed failure = failureDiagnostic env state body failure
  checked settled = maybe' (noUnkeyed settled) unresolved
    (firstUnkeyed settled body)
  -- A pair still set aside met a Fail key that stays unknown (a rigid
  -- variable); it is rejected, never dropped (FX009).
  noUnkeyed settled@(Subst bindings) _ =
    if Array.null bindings.postponed then Right settled
    else unresolved (failureSpan body)
  unresolved span = Left (problemAt FailNeedsConcrete span)

failureSpan ∷ Checked.Expr → Span
failureSpan body = maybe' noFailure identity (firstFail body)
  where
  noFailure _ = Checked.spanOf body

failureDiagnostic
  ∷ ∀ r
  . CheckEnv r
  → State
  → Checked.Expr
  → Failure
  → Either Diagnostic Subst
failureDiagnostic env state body failure = case failure of
  Mismatch found expected → mismatch found expected
  _ → rejected env state origin failure
  where
  span = failureSpan body
  origin = { span, consumed: FailOf env.functionName, via: Nothing }
  mismatch found expected = do
    let Tuple expectedPart foundPart = firstDifferent expected found
    expectedName ← typeName env span (opened expectedPart)
    foundName ← typeName env span (opened foundPart)
    Left (problemAt (TypeMismatch expectedName foundName) span)

firstFail ∷ Checked.Expr → Maybe Span
firstFail (Checked.Expr expression) = case expression.node of
  Checked.Fail _ → Just expression.span
  Checked.Handler _ _ clauses → firstIn (map handlerBody clauses)
  Checked.With handler body → firstIn [ handler, body ]
  Checked.Handle body clauses → firstIn
    (Array.cons body (map failureBody clauses))
  Checked.Call _ _ arguments → firstIn arguments
  Checked.Construct _ _ arguments → firstIn arguments
  Checked.Add left right → firstIn [ left, right ]
  Checked.Compare _ left right → firstIn [ left, right ]
  Checked.If condition yes no → firstIn [ condition, yes, no ]
  Checked.Match scrutinee arms → firstIn
    (Array.cons scrutinee (map armBody arms))
  Checked.Apply callee arguments → firstIn (Array.cons callee arguments)
  Checked.Lambda _ body → firstFail body
  Checked.Pipe left right → firstIn [ left, right ]
  Checked.Print value → firstFail value
  Checked.Crash value → firstFail value
  Checked.Perform _ _ _ arguments → firstIn arguments
  Checked.Block items value → firstIn (Checked.blockParts items value)
  _ → Nothing
  where
  firstIn expressions = Array.head (Array.mapMaybe firstFail expressions)
  handlerBody clause = clause.body
  failureBody clause = clause.body
  armBody arm = arm.body

firstDifferent ∷ Ty Flex → Ty Flex → Tuple (Ty Flex) (Ty Flex)
firstDifferent expected found = case expected, found of
  TData expectedId expectedArguments _, TData foundId foundArguments _
    | expectedId == foundId && Array.length expectedArguments ==
        Array.length foundArguments → maybe' unchanged
        identity
        (Array.find differs (Array.zip expectedArguments foundArguments))
  _, _ → Tuple expected found
  where
  unchanged _ = Tuple expected found
  differs (Tuple left right) = left /= right

firstUnkeyed ∷ Subst → Checked.Expr → Maybe Span
firstUnkeyed subst (Checked.Expr expression) = case expression.node of
  Checked.Fail payload → maybe'
    (unkeyedPayload payload expression.span)
    Just
    (firstUnkeyed subst payload)
  Checked.Handler _ _ clauses → firstIn (map handlerBody clauses)
  Checked.With handler body → firstIn [ handler, body ]
  Checked.Handle body clauses → firstIn
    (Array.cons body (map failureBody clauses))
  Checked.Call _ _ arguments → firstIn arguments
  Checked.Construct _ _ arguments → firstIn arguments
  Checked.Add left right → firstIn [ left, right ]
  Checked.Compare _ left right → firstIn [ left, right ]
  Checked.If condition yes no → firstIn [ condition, yes, no ]
  Checked.Match scrutinee arms → firstIn
    (Array.cons scrutinee (map armBody arms))
  Checked.Apply callee arguments → firstIn (Array.cons callee arguments)
  Checked.Lambda _ body → firstUnkeyed subst body
  Checked.Pipe left right → firstIn [ left, right ]
  Checked.Print value → firstUnkeyed subst value
  Checked.Crash value → firstUnkeyed subst value
  Checked.Perform _ _ _ arguments → firstIn arguments
  Checked.Block items value → firstIn (Checked.blockParts items value)
  _ → Nothing
  where
  firstIn expressions = Array.head
    (Array.mapMaybe (firstUnkeyed subst) expressions)
  unkeyed ty span = maybe' (noHead span) keyed (typeHead (resolved subst ty))
  noHead span _ = Just span
  keyed _ = Nothing
  unkeyedPayload payload span _ = unkeyed (Checked.typeOf payload) span
  handlerBody clause = clause.body
  failureBody clause = clause.body
  armBody arm = arm.body
