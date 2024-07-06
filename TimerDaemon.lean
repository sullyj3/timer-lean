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


partial def busyWaitTil (due : Nat) : IO Unit := do
  while (← IO.monoMsNow) < due do
    pure ()

-- IO.sleep isn't guaranteed to be on time, I find it's usually about 10ms late
-- this strategy aims to be exactly on time (to the millisecond), while
-- avoiding a long busy wait which consumes too much cpu.
partial def waitTil (due : Nat) : IO Unit := do
  let remaining_ms := due - (← IO.monoMsNow)
  -- We sleep while there's enough time left that we can afford to be inaccurate
  if remaining_ms > 50 then do
    IO.sleep (remaining_ms/2).toUInt32
    waitTil due
  -- then busy wait when we need to be on time
  else do
    busyWaitTil due

def handleClient
  (client : Socket)
  (counter : IO.Mutex Nat)
  -- (timers : IO.Mutex (Array Nat))
  : IO Unit := do
  let now ← IO.monoMsNow

  _ ← counter.atomically inc
  let bytes ← client.recv (maxBytes := 1024)
  let msg := String.fromUTF8! bytes

  let some n := msg.trim.toNat? | do
    let msg := "failed to parse client message as a Nat"
    IO.eprintln msg
    _ ← Timer.notify msg

  let msg := s!"Starting timer for {n}ms"
  IO.eprintln msg
  _ ← Timer.notify msg

  let timerDue := now + n
  waitTil timerDue
  let now2 ← IO.monoMsNow
  let diff := Int.subNatNat now2 timerDue
  _ ← Timer.notify s!"Time's up! (late by {diff}ms)"
  playTimerSound

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
