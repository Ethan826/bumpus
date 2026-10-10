module Style.Parser (sequencingFindings, runnerFindings) where

import Prelude
import Data.Array as Array
import Data.Foldable (foldMap)
import Data.Tuple (Tuple(..))
import PureScript.CST.Types as CST

-- G001: parser productions are applicative. Format.Parse.Grammar (the Parser
-- instances) and Format.Parse.Cursor are the only parser modules that thread
-- the token state, so they are not listed.
applicativeModules ∷ Array String
applicativeModules =
  [ "Format.Parse"
  , "Format.Parse.Literal"
  , "Format.Parse.Pattern"
  , "Format.Parse.Expression"
  , "Format.Parse.Declaration"
  , "Format.Parse.Type"
  , "Format.Parse.Lambda"
  , "Format.Parse.Block"
  ]

applicativeMessage ∷ String
applicativeMessage =
  "parser productions are applicative: no do block, bind, join or Kleisli"

-- Every Prelude and Control.Bind route to Bind, by operator or by name
-- (backticked names are identifiers in the CST, so `bind` in backticks is
-- caught as a name). The Monad helpers joined in the G001 final review (M1).
bindOperators ∷ Array String
bindOperators = [ ">>=", "=<<", ">=>", "<=<" ]

bindNames ∷ Array String
bindNames =
  [ "bind"
  , "join"
  , "discard"
  , "ap"
  , "ifM"
  , "whenM"
  , "unlessM"
  , "liftM1"
  , "bindFlipped"
  , "composeKleisli"
  , "composeKleisliFlipped"
  ]

-- Running a parser from a state and inspecting the result is sequencing, so
-- the runner is the parser entry point's alone (and Grammar's, which
-- defines it). Open and hiding imports would bring it in unnamed.
runnerModules ∷ Array String
runnerModules = [ "Format.Parse.Grammar", "Format.Parse.Cursor" ]

runnerImporters ∷ Array String
runnerImporters = [ "Format.Parse", "Format.Parse.Grammar" ]

runnerNames ∷ Array String
runnerNames = [ "run", "initialState" ]

runnerMessage ∷ String → String
runnerMessage dependency =
  "only Format.Parse runs a parser: import named values from " <> dependency
    <> " without run or initialState"

sequencingFindings ∷ String → CST.Expr Void → Array String
sequencingFindings name expression
  | Array.elem name applicativeModules = bindFindings expression
  | otherwise = []

runnerFindings ∷ String → CST.ImportDecl Void → Array String
runnerFindings name (CST.ImportDecl declaration) =
  if guarded && (openImport || Array.any runnerImport listed) then
    [ runnerMessage dependency ]
  else []
  where
  dependency = moduleText declaration.module
  guarded = Array.elem dependency runnerModules
    && not (Array.elem name runnerImporters)
  lists = Array.fromFoldable declaration.names
  openImport = Array.null lists || Array.any hiding lists
  listed = foldMap importList lists
  hiding (Tuple keyword _) = not (Array.null (Array.fromFoldable keyword))
  runnerImport imported = Array.elem imported runnerNames

moduleText ∷ CST.Name CST.ModuleName → String
moduleText (CST.Name { name: CST.ModuleName text }) = text

importList
  ∷ ∀ hiding
  . Tuple hiding (CST.DelimitedNonEmpty (CST.Import Void))
  → Array String
importList (Tuple _ (CST.Wrapped { value: CST.Separated items })) =
  importedValue items.head <> foldMap tailValue items.tail
  where
  tailValue (Tuple _ imported) = importedValue imported

importedValue ∷ CST.Import Void → Array String
importedValue imported = case imported of
  CST.ImportValue (CST.Name { name: CST.Ident text }) → [ text ]
  _ → []

bindFindings ∷ CST.Expr Void → Array String
bindFindings expression = case expression of
  CST.ExprDo _ → [ applicativeMessage ]
  CST.ExprOp _ operators → foldMap operatorFindings operators
  CST.ExprOpName operator → bindOperatorFindings operator
  CST.ExprIdent (CST.QualifiedName { name: CST.Ident text }) →
    if Array.elem text bindNames then [ applicativeMessage ] else []
  _ → []
  where
  operatorFindings (Tuple operator _) = bindOperatorFindings operator

bindOperatorFindings ∷ CST.QualifiedName CST.Operator → Array String
bindOperatorFindings (CST.QualifiedName { name: CST.Operator text }) =
  if Array.elem text bindOperators then [ applicativeMessage ] else []
