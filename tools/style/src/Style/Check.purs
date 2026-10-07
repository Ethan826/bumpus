module Style.Check (check) where

import Prelude
import Data.Array as Array
import Data.Foldable (foldMap)
import Data.Tuple (Tuple(..))
import PureScript.CST (RecoveredParserResult(..), parseModule)
import PureScript.CST.Traversal (defaultMonoidalVisitor, foldMapModule)
import PureScript.CST.Types as CST
import Style.Parser (runnerFindings, sequencingFindings)

-- Fail closed on damaged syntax; never lint a recovered partial tree.
check ∷ String → Array String
check source = case parseModule source of
  ParseSucceeded parsed → inspect parsed
  ParseSucceededWithErrors _ _ → [ "style input has parse errors" ]
  ParseFailed _ → [ "style input did not parse" ]

inspect ∷ CST.Module Void → Array String
inspect parsed = foldMapModule visitor parsed
  <> foldMap (runnerFindings name) (moduleImports parsed)
  where
  name = moduleName parsed
  visitor = defaultMonoidalVisitor
    { onExpr = expressionFindings <> sequencingFindings name }

moduleImports ∷ CST.Module Void → Array (CST.ImportDecl Void)
moduleImports (CST.Module { header: CST.ModuleHeader header }) =
  header.imports

moduleName ∷ CST.Module Void → String
moduleName (CST.Module { header: CST.ModuleHeader header }) = text header.name
  where
  text (CST.Name { name: CST.ModuleName name }) = name

expressionFindings ∷ CST.Expr Void → Array String
expressionFindings expression = case expression of
  CST.ExprLet _ → [ "use where instead of let-in" ]
  CST.ExprLambda _ → [ "name transformations in where; no anonymous lambda" ]
  CST.ExprCase branches → caseFindings branches
  CST.ExprIf branches → conditionalFindings branches
  _ → []
  where
  caseFindings branches = maybeCaseFindings branches
    <> foldMap caseBranchFindings branches.branches
  conditionalFindings branches = branchBlockFindings branches.true
    <> branchBlockFindings branches.false

maybeCaseFindings ∷ CST.CaseOf Void → Array String
maybeCaseFindings branches =
  if Array.any isOptionalConstructor constructors then
    [ "use maybe/either with named where helpers" ]
  else []
  where
  constructors = foldMap armConstructors branches.branches

armConstructors
  ∷ Tuple (CST.Separated (CST.Binder Void)) (CST.Guarded Void) → Array String
armConstructors (Tuple (CST.Separated patterns) _) =
  binderConstructors patterns.head <> foldMap tailConstructors patterns.tail
  where
  tailConstructors (Tuple _ binder) = binderConstructors binder

binderConstructors ∷ CST.Binder Void → Array String
binderConstructors binder = case binder of
  CST.BinderConstructor (CST.QualifiedName constructor) _ → constructorName
    constructor.name
  CST.BinderParens (CST.Wrapped wrapped) → binderConstructors wrapped.value
  CST.BinderTyped inner _ _ → binderConstructors inner
  _ → []

constructorName ∷ CST.Proper → Array String
constructorName (CST.Proper name) = [ name ]

isOptionalConstructor ∷ String → Boolean
isOptionalConstructor name = Array.elem name
  [ "Just", "Nothing", "Left", "Right" ]

branchBlockFindings ∷ CST.Expr Void → Array String
branchBlockFindings expression = case expression of
  CST.ExprDo _ → [ "move branch work into a named helper" ]
  CST.ExprParens (CST.Wrapped wrapped) → branchBlockFindings wrapped.value
  _ → []

caseBranchFindings
  ∷ Tuple (CST.Separated (CST.Binder Void)) (CST.Guarded Void) → Array String
caseBranchFindings (Tuple _ guarded) = case guarded of
  CST.Unconditional _ (CST.Where body) → branchBlockFindings body.expr
  CST.Guarded branches → foldMap guardedBranchFindings branches

guardedBranchFindings ∷ CST.GuardedExpr Void → Array String
guardedBranchFindings (CST.GuardedExpr branch) = whereBranchFindings
  branch.where

whereBranchFindings ∷ CST.Where Void → Array String
whereBranchFindings (CST.Where body) = branchBlockFindings body.expr
