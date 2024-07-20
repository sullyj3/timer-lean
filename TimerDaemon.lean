import Timer

open Lean (Json toJson)
open Timer (DaemonMode Command)

structure TimerdState where
  nextTimerId : IO.Mutex Nat
  timers : IO.Mutex (Array Timer) -- TODO switch to hashmap or something

namespace TimerdState

def initial : IO TimerdState := do
  return {
    nextTimerId := (← IO.Mutex.new 1),
    timers := (← IO.Mutex.new #[])
  }

def addTimer (state : TimerdState) (due : Nat) : BaseIO TimerId := do
  let id : TimerId ← state.nextTimerId.atomically (getModify Nat.succ)
  let timer : Timer := ⟨id, due⟩
  state.timers.atomically <| modify (·.push timer)
  return id

-- No-op if timer with TimerId `id` doesn't exist,
def removeTimer (state : TimerdState) (id : TimerId) : BaseIO Unit := do
  state.timers.atomically <| modify λ timers ↦
    match timers.findIdx? (λ timer ↦ timer.id == id) with
    | some idx => timers.eraseIdx idx
    | none => timers

end TimerdState

def playTimerSound : IO Unit := do
  let some dir ← Timer.dataDir | do
    IO.eprintln "Warning: failed to locate XDG_DATA_HOME. Audio will not work."
  let soundPath := dir / "simple-notification-152054.mp3"

  -- todo choose most appropriate media player, possibly record a dependency for package
  _ ← Timer.runCmdSimple "mpv" #[soundPath.toString]


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

def addTimer (state : TimerdState) (startTime : Nat) (durationMs : Nat) : IO Unit := do
  -- run timer
  let msg := s!"Starting timer for {durationMs}ms"

  IO.eprintln msg
  _ ← Timer.notify msg

  -- TODO: problem with this approach - time spent suspended is not counted.
  -- eg if I set a 1 minute timer, then suspend at 30s, the timer will
  -- go off 30s after wake.
  let timerDue := startTime + durationMs

  let addTimerTask : Task TimerId ← BaseIO.asTask <|
    state.addTimer timerDue

  waitTil timerDue
  let now2 ← IO.monoMsNow
  let diff := Int.subNatNat now2 timerDue
  _ ← Timer.notify s!"Time's up! (late by {diff}ms)"
  playTimerSound

  let timerId := addTimerTask.get
  state.removeTimer timerId

def serializeTimers (timers : Array Timer) : ByteArray :=
  String.toUTF8 <| toString <| toJson timers

def list (state : TimerdState) (client : Socket) : IO Unit := do
  let timers ← state.timers.atomically get
  _ ← client.send <| serializeTimers timers


def handleClient
  (client : Socket)
  (state : TimerdState)
  : IO Unit := do
  let startTime ← IO.monoMsNow

  -- receive and parse message
  let bytes ← client.recv (maxBytes := 1024)
  let clientMsg := String.fromUTF8! bytes

  let some (cmd : Command) := Command.parse clientMsg | do
    let errMsg := s!"failed to parse client message: invalid command \"{clientMsg}\""
    IO.eprintln errMsg
    _ ← Timer.notify errMsg

  match cmd with
  | .addTimer durationMs => addTimer state startTime durationMs
  | .list => list state client

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

  let state ← TimerdState.initial

  forever do
    let (client, _clientAddr) ← sock.accept
    let _tsk ← IO.asTask <|
      handleClient client state

def main (args : List String) : IO UInt32 := do
  timerDaemon args
  return 0
