import Socket
import Timer

open System (FilePath)
open Socket (SockAddr)
open Timer (DaemonMode)

def inc [MonadState Nat m] : m Nat :=
  modifyGet λ n ↦ (n, n + 1)

def playTimerSound : IO Unit := do
  _ ← Timer.runCmdSimple
    "mpv" #["/home/james/.local/share/timer/simple-notification-152054.mp3"]

def handleClient (client : Socket) (counter : IO.Mutex Nat) : IO Unit := do
  _ ← counter.atomically inc
  let bytes ← client.recv (maxBytes := 1024)
  let msg := String.fromUTF8! bytes

  if let some n := msg.trim.toNat? then do
    let msg := s!"Starting timer for {n}ms"
    IO.eprintln msg
    _ ← Timer.notify msg

    IO.sleep n.toUInt32
    _ ← Timer.notify "Time's up!"
    playTimerSound
  else
    let msg := "failed to parse client message as a Nat"
    IO.eprintln msg
    _ ← Timer.notify msg

partial def forever (act : IO α) : IO β := act *> forever act

def parseMode (args : List String) : Option DaemonMode :=
  match args with
  | [] => some .standalone
  | ["--systemd"] => some .systemd
  | _ => .none

def timerDaemon (args : List String) : IO α := do
  let mode ← (parseMode args).getOrFail "bad args"
  let sock ← Timer.getSocket mode

  IO.eprintln "timerd started"
  IO.eprintln "listening..."

  let counter ← IO.Mutex.new 1

  forever do
    let (client, _clientAddr) ← sock.accept
    let _tsk ← IO.asTask <|
      handleClient client counter

def main (args : List String) : IO UInt32 := do
  timerDaemon args
  return 0
