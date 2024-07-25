import «Sand».Basic

open System (FilePath)
open Lean (Json toJson fromJson?)
open Sand (Timer TimerId Command Duration)

structure SanddState where
  nextTimerId : IO.Mutex Nat
  timers : IO.Mutex (Array Timer) -- TODO switch to hashmap or something

namespace SanddState

def initial : IO SanddState := do
  return {
    nextTimerId := (← IO.Mutex.new 1),
    timers := (← IO.Mutex.new #[])
  }

def addTimer (state : SanddState) (due : Nat) : BaseIO TimerId := do
  let id : TimerId ← state.nextTimerId.atomically (getModify Nat.succ)
  let timer : Timer := ⟨id, due⟩
  state.timers.atomically <| modify (·.push timer)
  return id

-- No-op if timer with TimerId `id` doesn't exist,
def removeTimer (state : SanddState) (id : TimerId) : BaseIO Unit := do
  state.timers.atomically <| modify λ timers ↦
    match timers.findIdx? (λ timer ↦ timer.id == id) with
    | some idx => timers.eraseIdx idx
    | none => timers

end SanddState

private def xdgDataHome : OptionT BaseIO FilePath :=
  xdgDataHomeEnv <|> dataHomeDefault
  where
    xdgDataHomeEnv  := FilePath.mk <$> (OptionT.mk <| IO.getEnv "XDG_DATA_HOME")
    home            := FilePath.mk <$> (OptionT.mk <| IO.getEnv "HOME"         )
    dataHomeDefault := home <&> (· / ".local/share")

def dataDir : OptionT BaseIO FilePath := xdgDataHome <&> (· / "sand")

def playTimerSound : IO Unit := do
  let some dir ← ↑(OptionT.run dataDir) | do
    IO.eprintln "Warning: failed to locate XDG_DATA_HOME. Audio will not work."
  let soundPath := dir / "timer_sound.opus"
  if not (← soundPath.pathExists) then do
    IO.eprintln "Warning: failed to locate notification sound. Audio will not work"
    return ()

  -- todo choose most appropriate media player, possibly record a dependency for package
  _ ← Sand.runCmdSimple "paplay" #[soundPath.toString]

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

def addTimer (state : SanddState) (startTime : Nat) (duration : Duration) : IO Unit := do
  -- run timer
  let msg := s!"Starting timer for {duration.formatColonSeparated}"

  IO.eprintln msg
  _ ← Sand.notify msg

  -- TODO: problem with this approach - time spent suspended is not counted.
  -- eg if I set a 1 minute timer, then suspend at 30s, the timer will
  -- go off 30s after wake.
  let timerDue := startTime + duration.millis

  let addTimerTask : Task TimerId ← BaseIO.asTask <|
    state.addTimer timerDue

  waitTil timerDue
  _ ← Sand.notify s!"Time's up!"

  playTimerSound

  let timerId := addTimerTask.get
  state.removeTimer timerId

def serializeTimers (timers : Array Timer) : ByteArray :=
  String.toUTF8 <| toString <| toJson timers

def list (state : SanddState) (client : Socket) : IO Unit := do
  let timers ← state.timers.atomically get
  _ ← client.send <| serializeTimers timers


def handleClient
  (client : Socket)
  (state : SanddState)
  : IO Unit := do

  -- IO.monoMsNow is an ffi call to `std::chrono::steady_clock::now()`
  -- Technically this clock is not guaranteed to be the same between
  -- processes, but it seems to be in practice on linux
  let startTime ← IO.monoMsNow

  -- receive and parse message
  let bytes ← client.recv (maxBytes := 1024)
  let clientMsg := String.fromUTF8! bytes

  let .ok (cmd : Command) := fromJson? =<< Json.parse clientMsg | do
    let errMsg := s!"failed to parse client message: invalid command \"{clientMsg}\""
    IO.eprintln errMsg
    _ ← Sand.notify errMsg

  match cmd with
  | .addTimer durationMs => addTimer state startTime durationMs
  | .list => list state client

partial def forever (act : IO α) : IO β := act *> forever act

namespace SandDaemon
def main (_args : List String) : IO α := do
  let systemdSockFd := 3
  let sock ← Socket.fromFd systemdSockFd

  IO.eprintln "sandd started"
  IO.eprintln "listening..."

  let state ← SanddState.initial

  forever do
    let (client, _clientAddr) ← sock.accept
    let _tsk ← IO.asTask <|
      handleClient client state
end SandDaemon