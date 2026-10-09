module Features.Specialize.Seeds (environment, seeded) where

import Prelude
import Data.Array as Array
import Data.Map as Map
import Data.Maybe (Maybe(..), isJust)
import Data.Tuple (Tuple(..))
import Domain.Checked.Internal as Checked
import Domain.IR.Internal as IR
import Domain.Resolved (CtorId(..), CtorInfo, FunctionId(..), TypeInfo)
import Domain.Type (Ty, TypeId(..))
import Domain.Type.Parts (ground)
import Features.Specialize.Intern (noArrows)
import Features.Specialize.Keys (Env, State, Work)

-- Design §6: monomorphic types and functions keep their relative order and
-- take the first output ids, so a program without type variables comes out
-- with every id unchanged (the identity the bootstrap snapshots rely on).
environment ∷ Ty Void → Checked.Program → Env
environment representative (Checked.Program program) =
  { types: program.types
  , ctors: program.ctors
  , functions: program.functions
  , monoTypes
  , monoFunctions: ranks (map monomorphic program.functions)
  , positions: positionsOf program.types program.ctors
  , representative
  }
  where
  monoTypes = ranks (map unparameterized program.types)
  unparameterized info = Array.null info.parameters

-- The seeds, in order: every monomorphic type (its fields may reference
-- applications), then every monomorphic function, whether used or not.
seeded ∷ Env → State
seeded env =
  { typeKeys: Map.empty
  , functionKeys: Map.empty
  , types: Map.fromFoldable (Array.mapMaybe typeEntry indexedTypes)
  , ctors: Map.empty
  , functions: Map.empty
  , work: Map.fromFoldable (Array.mapWithIndex Tuple work)
  , arrows: noArrows
  , counts:
      { types: Array.length typeWork
      , ctors: Array.length (Array.filter isJust monoCtors)
      , functions: Array.length work - Array.length typeWork
      , work: Array.length work
      , polymorphic: 0
      }
  }
  where
  indexedTypes = Array.zip env.monoTypes env.types
  typeWork = Array.catMaybes (Array.mapWithIndex typeSeed indexedTypes)
  work = typeWork <> Array.catMaybes
    (Array.zipWith functionSeed env.monoFunctions env.functions)
  monoCtors = ranks (map (ownedBy env) env.ctors)
  typeEntry (Tuple rank info) = map (entry info) rank
  entry info output = Tuple output (outputType monoCtors info)

-- Each flagged item's rank among the flagged ones.
ranks ∷ Array Boolean → Array (Maybe Int)
ranks flags = Array.zipWith ranked flags (Array.scanl counted 0 flags)
  where
  counted total flag = if flag then total + 1 else total
  ranked flag total = if flag then Just (total - 1) else Nothing

monomorphic ∷ Checked.FunctionDecl → Boolean
monomorphic function = Array.all isGround
  (Array.snoc function.parameters function.result)
  where
  isGround ty = isJust (ground ty)

ownedBy ∷ Env → CtorInfo → Boolean
ownedBy env ctor = isJust (join (Array.index env.monoTypes (owner ctor.owner)))
  where
  owner (TypeId index) = index

-- A monomorphic type's constructors are monomorphic by definition, so
-- every one has a rank.
outputType ∷ Array (Maybe Int) → TypeInfo → IR.TypeInfo
outputType monoCtors info =
  { name: info.name
  , ctors: Array.mapMaybe renumbered info.ctors
  , span: info.span
  }
  where
  renumbered (CtorId index) = map CtorId (join (Array.index monoCtors index))

typeSeed ∷ Int → Tuple (Maybe Int) TypeInfo → Maybe Work
typeSeed declaration (Tuple rank info) = map seed rank
  where
  seed output =
    { output, declaration, arguments: [], function: false, span: info.span }

functionSeed ∷ Maybe Int → Checked.FunctionDecl → Maybe Work
functionSeed rank function = map seed rank
  where
  seed output =
    { output
    , declaration: functionIndex function.id
    , arguments: []
    , function: true
    , span: function.span
    }
  functionIndex (FunctionId index) = index

-- Each constructor's position in its owner's declaration.
positionsOf ∷ Array TypeInfo → Array CtorInfo → Array (Maybe Int)
positionsOf types ctors = Array.mapWithIndex position ctors
  where
  table = Map.fromFoldable (Array.concatMap positioned types)
  positioned info = Array.mapWithIndex pair info.ctors
  pair index (CtorId id) = Tuple id index
  position id _ = Map.lookup id table
