import Socket
import «Sand».Time

open Lean (ToJson FromJson toJson)
open System (FilePath)
open Sand (Moment)

namespace Sand

elab "get_version" : term => do
  let version ← do
    -- this is necessary in CI
    if let some version ← IO.getEnv "GIT_DESCRIBE" then
      pure version
    else
      String.trimRight <$> IO.Process.run { cmd := "git", args := #["describe"] }
  return .lit <| .strVal version

def version : String := get_version

def nullStdioConfig : IO.Process.StdioConfig := ⟨.null, .null, .null⟩
def SimpleChild : Type := IO.Process.Child nullStdioConfig

def runCmdSimple (cmd : String) (args : Array String := #[]) : IO Unit := do
  let child ← IO.Process.spawn
    { cmd := cmd,
      args := args,

      stdin := .null,
      stdout := .null,
      stderr := .null,
    }
  _ ← (child.wait).asTask

def notify (message : String) : IO Unit := do
  -- TODO wrap libnotify with FFI so we can do this properly
  runCmdSimple "notify-send" #[message]

end Sand
