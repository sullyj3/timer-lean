import Socket
import Timer

open System (FilePath)
open Socket (SockAddr)

def inc [MonadState Nat m] : m Nat :=
  modifyGet λ n ↦ (n, n + 1)

def handleClient 
  (client : Socket)
  (_clientAddr : SockAddr)
  (counter : IO.Mutex Nat)
  : IO Unit := do
  let n ← counter.atomically inc
  let bytes ← client.recv (maxBytes := 1024)
  let msg := String.fromUTF8! bytes

  let logMsg := s!"received message from client #{n}: {msg}" 
  IO.eprintln logMsg
  _ ← Timer.notify logMsg

def timerDaemon : IO Unit := do
  IO.eprintln "timerd started"

  let sock ← Timer.getSocket .systemd

  IO.eprintln "listening..."

  let counter ← IO.Mutex.new 1

  while true do
    let (client, clientAddr) ← sock.accept
    let _tsk ← IO.asTask <|
      handleClient client clientAddr counter

def main := timerDaemon
