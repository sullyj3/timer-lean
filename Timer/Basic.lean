import Socket
open System (FilePath)

def Option.getOrFail (msg : String) (x? : Option α) : IO α := do
  let some x := x? | do
    IO.eprintln msg
    IO.Process.exit 1
  return x

private def runtimeDir : IO FilePath := do
  (← IO.getEnv "XDG_RUNTIME_DIR")
    |>.getOrFail "Error: failed to get XDG_RUNTIME_DIR!"

infixr:100 " <$$> " => Functor.map ∘ Functor.map

private def xdgDataHome : IO (Option FilePath) := do
  let xdgDataHomeEnv? ← FilePath.mk <$$> IO.getEnv "XDG_DATA_HOME"
  let home?           ← FilePath.mk <$$> IO.getEnv "HOME"
  let dataHomeFallback? := home? <&> (· / ".local/share")
  return xdgDataHomeEnv? <|> dataHomeFallback?

namespace Timer

def dataDir : IO (Option FilePath) := (· / "timer") <$$> xdgDataHome

def getSockPath : IO FilePath :=
  runtimeDir <&> (· / "timerd.sock")

inductive DaemonMode
  | standalone | systemd

def getSocket : DaemonMode → IO Socket
  | .standalone => do
    let sockPath ← getSockPath
    IO.println s!"sockPath is {sockPath}"

    if (← sockPath.pathExists) then do
      IO.FS.removeFile sockPath

    let addr := Socket.SockAddrUnix.unix sockPath
    let sock : Socket ← Socket.mk .unix .stream

    sock.bind addr
    sock.listen 5
    return sock

  | .systemd =>
    let systemdSocketActivationFd : UInt32 := 3
    Socket.fromFd systemdSocketActivationFd

def runCmdSimple
  (cmd : String) (args : Array String := #[]) : IO UInt32 := do

  let child ← IO.Process.spawn
    { cmd := cmd,
      args := args,

      stdin := .null,
      stdout := .null,
      stderr := .null,
    }
  child.wait

def notify (message : String) : IO UInt32 :=
  runCmdSimple "notify-send" #[message]

-- commands sent from client to server
inductive Command
  | addTimer (durationMs : Nat)
  -- | list -- TODO
  deriving Repr

namespace Command

def parse (str : String) : Option Command :=
  match str.split Char.isWhitespace with
  | ["add", nStr] => do
    let n ← nStr.toNat?
    return .addTimer n
  -- | ["list"] => sorry -- TODO
  | _ => none


def toString : Command → String
  | addTimer ms => s!"add {ms}"
  -- | list => sorry -- TODO

end Command

end Timer
