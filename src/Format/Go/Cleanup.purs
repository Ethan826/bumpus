-- The cleanup and defect runtime (FX001 design §3, §4, §5), emitted only
-- by a program that uses `defer` or `crash`, so every other program keeps
-- its Go byte for byte, and with no context: these pieces never read one.
--
-- A block with `defer` registers closures in a slice and runs
-- waxwingCleanup as a Go `defer`, which recovers directly (as Go
-- requires), keeps the pending cause as the first, runs every closure
-- LIFO, each in waxwingRun so that a defect in one does not stop the rest,
-- and records their causes in order. With none it re-raises the pending
-- panic unchanged, so a typed abort still reaches its own `handle`;
-- otherwise it raises one waxwingDefect holding all the causes. `main`
-- recovers it once, prints one cause per line, newlines escaped, the first
-- as it is and each later one after `cleanup failed: `, and exits 1.
module Format.Go.Cleanup
  ( usesDefects
  , cleanupRuntime
  , guardedMain
  ) where

import Prelude
import Data.Array as Array
import Data.String.Common (joinWith)
import Domain.IR.Internal as IR
import Format.Go.Context (children)

-- Whether the emitted IR holds a `defer` or a `crash` anywhere. Only then
-- can a typed abort become part of a report (nothing else raises while an
-- abort unwinds), so only then do `fail` sites describe their payload.
usesDefects ∷ IR.Program → Boolean
usesDefects (IR.Program program) = Array.any inFunction program.functions
  where
  inFunction function = defective function.body

defective ∷ IR.Expr → Boolean
defective (IR.Expr expression) = case expression.node of
  IR.Crash _ → true
  IR.Block items value → Array.any isDefer items
    || Array.any defective (IR.blockParts items value)
  node → Array.any defective (children node <> IR.effectParts node)
  where
  isDefer = case _ of
    IR.Defer _ → true
    _ → false

-- `main` reports a defect before it exits, whatever the entry returns.
guardedMain ∷ Boolean → String → String
guardedMain defects call
  | defects = "defer waxwingReport(); " <> call
  | otherwise = call

-- A typed abort exists only in the context mode, which is when
-- waxwingCauses may name one.
cleanupRuntime ∷ Boolean → String
cleanupRuntime context =
  joinWith "\n"
    ( [ "type waxwingDefect struct{ causes []string }"
      , ""
      , "func waxwingCrash[R any](value string) R {"
      , "\tpanic(&waxwingDefect{causes: []string{\"crash: \" + value}})"
      , "}"
      , ""
      , "func waxwingCauses(pending any) []string {"
      , "\tswitch cause := pending.(type) {"
      , "\tcase *waxwingDefect:"
      , "\t\treturn cause.causes"
      ]
        <> abortCase context
        <>
          [ "\tcase string:"
          , "\t\tif len(cause) >= 14 && cause[:14] == \"no handler for\" {"
          , "\t\t\treturn []string{cause}"
          , "\t\t}"
          , "\t\treturn []string{\"panic: \" + cause}"
          , "\tcase error:"
          , "\t\treturn []string{\"panic: \" + cause.Error()}"
          , "\t}"
          , "\treturn []string{\"panic: \" + fmt.Sprint(pending)}"
          , "}"
          , ""
          , "func waxwingRun(cleanup func()) (failure any) {"
          , "\tdefer func() { failure = recover() }()"
          , "\tcleanup()"
          , "\treturn nil"
          , "}"
          , ""
          , "func waxwingCleanup(cleanups *[]func()) {"
          , "\tpending := recover()"
          , "\tvar causes []string"
          , "\tif pending != nil {"
          , "\t\tcauses = waxwingCauses(pending)"
          , "\t}"
          , "\tfailed := false"
          , "\tfor index := len(*cleanups) - 1; index >= 0; index-- {"
          , "\t\tif failure := waxwingRun((*cleanups)[index]); failure != nil {"
          , "\t\t\tcauses = append(causes, waxwingCauses(failure)...)"
          , "\t\t\tfailed = true"
          , "\t\t}"
          , "\t}"
          , "\tif failed {"
          , "\t\tpanic(&waxwingDefect{causes: causes})"
          , "\t}"
          , "\tif pending != nil {"
          , "\t\tpanic(pending)"
          , "\t}"
          , "}"
          , ""
          , "func waxwingEscape(text string) string {"
          , "\tescaped := []byte{}"
          , "\tfor index := 0; index < len(text); index++ {"
          , "\t\tif text[index] == '\\n' {"
          , "\t\t\tescaped = append(escaped, '\\\\', 'n')"
          , "\t\t} else {"
          , "\t\t\tescaped = append(escaped, text[index])"
          , "\t\t}"
          , "\t}"
          , "\treturn string(escaped)"
          , "}"
          , ""
          , "func waxwingReport() {"
          , "\tpending := recover()"
          , "\tif pending == nil {"
          , "\t\treturn"
          , "\t}"
          , "\tfor index, cause := range waxwingCauses(pending) {"
          , "\t\tline := waxwingEscape(cause)"
          , "\t\tif index > 0 {"
          , "\t\t\tline = \"cleanup failed: \" + line"
          , "\t\t}"
          , "\t\tos.Stderr.WriteString(line + \"\\n\")"
          , "\t}"
          , "\tos.Exit(1)"
          , "}"
          ]
    )
    <> "\n\n"

abortCase ∷ Boolean → Array String
abortCase context
  | context =
      [ "\tcase *waxwingAbort:"
      , "\t\treturn []string{cause.report(cause.payload)}"
      ]
  | otherwise = []
