import Socket
import Timer

open System (FilePath)
open Socket (SockAddr)
open Timer (DaemonMode)

def inc [MonadState Nat m] : m Nat :=
  modifyGet λ n ↦ (n, n + 1)

def handleClient (client : Socket) (counter : IO.Mutex Nat) : IO Unit := do
  let n ← counter.atomically inc
  let bytes ← client.recv (maxBytes := 1024)
  let msg := String.fromUTF8! bytes

  let logMsg := s!"received message from client #{n}: {msg}"
  IO.eprintln logMsg
  _ ← Timer.notify logMsg

partial def forever (act : IO α) : IO β := do
  _ ← act
  forever act

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
