import Socket

open Lean (ToJson FromJson)
open System (FilePath)

private def Option.getOrFail (msg : String) (x? : Option α) : IO α := do
  let some x := x? | do
    IO.eprintln msg
    IO.Process.exit 1
  return x

private def String.replicate (n : Nat) (c : Char) : String :=
  ⟨List.replicate n c⟩

private def zeroPad (minWidth : Nat) (s : String) :=
  if s.length < minWidth then
    let pfx := String.replicate (minWidth - s.length) '0'
    pfx ++ s
  else
    s

private def runtimeDir : IO FilePath := do
  (← IO.getEnv "XDG_RUNTIME_DIR")
    |>.getOrFail "Error: failed to get XDG_RUNTIME_DIR!"

private def xdgDataHome : OptionT BaseIO FilePath :=
  xdgDataHomeEnv <|> dataHomeDefault
  where
    xdgDataHomeEnv  := FilePath.mk <$> (OptionT.mk <| IO.getEnv "XDG_DATA_HOME")
    home            := FilePath.mk <$> (OptionT.mk <| IO.getEnv "HOME"         )
    dataHomeDefault := home <&> (· / ".local/share")


namespace Sand

def TimerId := Nat
  deriving BEq, Repr, ToJson, FromJson

namespace TimerId

def fromNat (n : Nat) : TimerId := n

end TimerId

structure Duration where
  millis : Nat
  deriving Repr, ToJson, FromJson, BEq

instance : Add Duration where
  add | d1, d2 => { millis := d1.millis + d2.millis }

namespace Duration

def fromSeconds (seconds : Nat) : Duration := { millis := 1000 * seconds }

-- This is for formatting, not canonical representation of
-- duration
private structure HMSMs where
  hours : Nat
  minutes : Fin 60
  seconds : Fin 60
  millis : Fin 1000
  deriving Repr

private def toHMSMs (d : Duration) : HMSMs :=
  let seconds := d.millis / 1000
  let minutes := seconds / 60
  let hours   := minutes / 60
  {
    hours   := hours,
    minutes := Fin.ofNat' minutes  (Nat.zero_lt_succ _)
    seconds := Fin.ofNat' seconds  (Nat.zero_lt_succ _)
    millis  := Fin.ofNat' d.millis (Nat.zero_lt_succ _)
  }


def formatColonSeparated (d : Duration) : String :=
  let {hours, minutes, seconds, millis} := d.toHMSMs
  let h  := zeroPad 2 <| toString hours
  let m  := zeroPad 2 <| toString minutes
  let s  := zeroPad 2 <| toString seconds
  let ms := zeroPad 3 <| toString millis

  s!"{h}:{m}:{s}:{ms}"

end Duration
structure Timer where
  id : TimerId
  due : Nat
  deriving Repr, ToJson, FromJson

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
  -- TODO wrap libnotify with FFI so we can do this properly
  runCmdSimple "notify-send" #[message]

-- commands sent from client to server
inductive Command
  | addTimer (duration : Duration)
  | list
  deriving Repr, ToJson, FromJson

end Sand
