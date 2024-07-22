import Lean
import Socket

open Lean (ToJson FromJson)
open System (FilePath)

def Option.getOrFail (msg : String) (x? : Option α) : IO α := do
  let some x := x? | do
    IO.eprintln msg
    IO.Process.exit 1
  return x

private def runtimeDir : IO FilePath := do
  (← IO.getEnv "XDG_RUNTIME_DIR")
    |>.getOrFail "Error: failed to get XDG_RUNTIME_DIR!"

private def xdgDataHome : OptionT BaseIO FilePath :=
  xdgDataHomeEnv <|> dataHomeDefault
  where
    xdgDataHomeEnv  := FilePath.mk <$> (OptionT.mk <| IO.getEnv "XDG_DATA_HOME")
    home            := FilePath.mk <$> (OptionT.mk <| IO.getEnv "HOME"         )
    dataHomeDefault := home <&> (· / ".local/share")

def TimerId := Nat
  deriving BEq, Repr, ToJson, FromJson

namespace TimerId

def fromNat (n : Nat) : TimerId := n

end TimerId

structure Timer where
  id : TimerId
  due : Nat
  deriving Repr, ToJson, FromJson

namespace Sand

def dataDir : OptionT BaseIO FilePath := xdgDataHome <&> (· / "sand")

def getSockPath : IO FilePath :=
  runtimeDir <&> (· / "sandd.sock")

def getSocket : IO Socket :=
  let systemdSocketActivationFd : UInt32 := 3
  Socket.fromFd systemdSocketActivationFd

def nullStdioConfig : IO.Process.StdioConfig := ⟨.null, .null, .null⟩
def SimpleChild : Type := IO.Process.Child nullStdioConfig

def runCmdSimple (cmd : String) (args : Array String := #[]) : IO SimpleChild :=
  IO.Process.spawn
    { cmd := cmd,
      args := args,

      stdin := .null,
      stdout := .null,
      stderr := .null,
    }

def notify (message : String) : IO SimpleChild :=
  runCmdSimple "notify-send" #[message]

-- commands sent from client to server
inductive Command
  | addTimer (durationMs : Nat)
  | list
  deriving Repr, ToJson, FromJson

end Sand
