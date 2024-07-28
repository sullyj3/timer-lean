import «Sand».Basic
import Batteries

open System (FilePath)
open Lean (Json ToJson FromJson toJson fromJson?)

open Batteries (HashMap)

open Sand (Timer TimerId TimerState TimerInfoForClient Command CmdResponse Duration)

inductive TimerOpError
  | notFound
  -- returned when calling pause on a paused timer, or resume on a running timer
  | noop
  deriving Repr

def TimerOpResult α := Except TimerOpError α

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

structure SanddState where
  nextTimerId : IO.Mutex Nat
  timers : IO.Mutex (HashMap Nat (Timer × TimerState))

def SanddState.pauseTimer
  (state : SanddState) (timerId : TimerId) (clientConnectedTime : Nat)
  : BaseIO (TimerOpResult Unit) := state.timers.atomically do
  let timers ← get
  let some (timer, timerstate) := timers.find? timerId | do
    return .error .notFound
  match timerstate with
  | .paused _ => return .error .noop
  | .running task => do
    IO.cancel task
    let remaining := ⟨timer.due - clientConnectedTime⟩
    let newTimerstate := .paused remaining
    let newTimers := timers.insert timerId (timer, newTimerstate)
    set newTimers
    return .ok ()

def SanddState.removeTimer (state : SanddState) (id : TimerId) : BaseIO (TimerOpResult Unit) := do
  state.timers.atomically do
    let timers ← get
    match timers.find? id with
    | some (_, timerstate) => do
      if let .running task := timerstate then do
        IO.cancel task
      set <| timers.erase id
      pure <| .ok ()
    | none => do
      pure <| .error .notFound

def SanddState.timerExists (state : SanddState) (id : TimerId) : BaseIO Bool := do
  let timers ← state.timers.atomically get
  return timers.find? id |>.isSome

-- IO.sleep isn't guaranteed to be on time, I find it's usually about 10ms late
-- Therefore, we repeatedly sleep while there's enough time left that we can
-- afford to be inaccurate, and spin once we're close to the due time. This
-- strategy aims to be exactly on time (to the millisecond), while avoiding a
-- long busy wait which consumes too much cpu.
partial def countdown
  (state : SanddState) (id : TimerId) (due : Nat) : IO Unit := loop
  where
  loop := do
    let remaining_ms := due - (← IO.monoMsNow)
    -- This task will be cancelled if the timer is cancelled or paused.
    -- in case of resumed, a new separate task will be spawned.
    if ← IO.checkCanceled then return
    if remaining_ms == 0 then
      _ ← Sand.notify s!"Time's up!"
      playTimerSound
      _ ← state.removeTimer id
      return
    if remaining_ms > 30 then
      IO.sleep (remaining_ms/2).toUInt32
    loop

def SanddState.resumeTimer
  (state : SanddState) (timerId : TimerId) (clientConnectedTime : Nat)
  : BaseIO (TimerOpResult Unit) := state.timers.atomically do
  let timers ← get
  let some (timer, timerstate) := timers.find? timerId | do
    return .error .notFound
  match timerstate with
  | .running _ => return .error .noop
  | .paused remaining => do
    let newDueTime := clientConnectedTime + remaining.millis
    let countdownTask ← IO.asTask <| countdown state timerId newDueTime
    let newTimerstate := .running countdownTask
    let newTimer := {timer with due := newDueTime}
    set <| timers.insert timerId (newTimer, newTimerstate)
    return .ok ()

def SanddState.initial : IO SanddState := do
  return {
    nextTimerId := (← IO.Mutex.new 1),
    timers := (← IO.Mutex.new ∅)
  }

def SanddState.addTimer (state : SanddState) (due : Nat) : BaseIO Unit := do
  let id : TimerId ← state.nextTimerId.atomically (getModify Nat.succ)
  let timer : Timer := ⟨id, due⟩
  let countdownTask ← IO.asTask <| countdown state id due
  state.timers.atomically <| modify (·.insert id (timer, .running countdownTask))

partial def busyWaitTil (due : Nat) : IO Unit := do
  while (← IO.monoMsNow) < due do
    pure ()

def addTimer (state : SanddState) (startTime : Nat) (duration : Duration) : IO Unit := do
  -- run timer
  let msg := s!"Starting timer for {duration.formatColonSeparated}"

  IO.eprintln msg
  _ ← Sand.notify msg

  -- TODO: problem with this approach - time spent suspended is not counted.
  -- eg if I set a 1 minute timer, then suspend at 30s, the timer will
  -- go off 30s after wake.{}
  let timerDue := startTime + duration.millis

  state.addTimer timerDue

def handleClientCmd
  (client : Socket) (state : SanddState) (clientConnectedTime : Nat)
  : Command → IO Unit

  | .addTimer durationMs => do
    _ ← IO.asTask <| addTimer state clientConnectedTime durationMs
    _ ← client.send CmdResponse.ok.serialize
  | .cancelTimer which => do
    match ← state.removeTimer which with
    | .error .notFound => do
      _ ← client.send <| (CmdResponse.timerNotFound which).serialize
    -- TODO yuck
    | .error err@(.noop) => do
      IO.eprintln s!"BUG: Unexpected error \"{repr err}\" from removeTimer."
    | .ok () => do
      _ ← client.send CmdResponse.ok.serialize
  | .list => do
    let timers ← state.timers.atomically get

    _ ← client.send <| (CmdResponse.list <| Sand.timersForClient timers).serialize

  -- TODO factor repetition
  | .pause which => do
    let result ← state.pauseTimer which clientConnectedTime
    match result with
    | .ok () => do
      _ ← client.send CmdResponse.ok.serialize
    | .error .notFound => do
      _ ← client.send (CmdResponse.timerNotFound which).serialize
    | .error .noop => do
      _ ← client.send CmdResponse.noop.serialize
  | .resume which => do
    let result ← state.resumeTimer which clientConnectedTime
    match result with
    | .ok () => do
      _ ← client.send CmdResponse.ok.serialize
    | .error .notFound => do
      _ ← client.send (CmdResponse.timerNotFound which).serialize
    | .error .noop => do
      _ ← client.send CmdResponse.noop.serialize

def handleClient
  (client : Socket)
  (state : SanddState)
  : IO Unit := do

  -- IO.monoMsNow is an ffi call to `std::chrono::steady_clock::now()`
  -- Technically this clock is not guaranteed to be the same between
  -- processes, but it seems to be in practice on linux
  let clientConnectedTime ← IO.monoMsNow

  -- receive and parse message
  let bytes ← client.recv (maxBytes := 1024)
  let clientMsg := String.fromUTF8! bytes

  let .ok (cmd : Command) := fromJson? =<< Json.parse clientMsg | do
    let errMsg := s!"failed to parse client message: invalid command \"{clientMsg}\""
    IO.eprintln errMsg
    _ ← Sand.notify errMsg

  handleClientCmd client state clientConnectedTime cmd

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
