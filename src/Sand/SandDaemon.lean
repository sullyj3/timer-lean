import «Sand».Basic
import «Sand».Time
import «Sand».Message
import Batteries

open System (FilePath)
open Lean (Json ToJson FromJson toJson fromJson?)

open Batteries (HashMap)

open Sand (
  Timer TimerId TimerState TimerInfoForClient Command CmdResponse Duration
  Moment
  )

inductive TimerOpError
  | notFound
  -- returned when calling pause on a paused timer, or resume on a running timer
  | noop
  deriving Repr

-- TODO this should maybe be subsumed by CmdResponse?
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

def Timers := HashMap TimerId (Timer × TimerState)
  deriving EmptyCollection

structure SanddState where
  nextTimerId : IO.Mutex Nat
  timers : IO.Mutex Timers

structure CmdHandlerEnv where
  state : SanddState
  client : Socket
  clientConnectedTime : Moment

abbrev CmdHandlerT (m : Type → Type) : Type → Type := ReaderT CmdHandlerEnv m

def SanddState.pauseTimer
  (timerId : TimerId)
  : CmdHandlerT BaseIO (TimerOpResult Unit) := do
  let {state, clientConnectedTime, .. } ← read
  state.timers.atomically do
    let timers ← get
    let some (timer, timerstate) := timers.find? timerId | do
      return .error .notFound
    match timerstate with
    | .paused _ => return .error .noop
    | .running task => do
      IO.cancel task
      let remaining : Duration := timer.due - clientConnectedTime
      let newTimerstate := .paused remaining
      let newTimers : Timers := timers.insert timerId (timer, newTimerstate)
      set newTimers
      return .ok ()

def SanddState.removeTimer (state : SanddState) (id : TimerId) : BaseIO (TimerOpResult Unit) := do
  state.timers.atomically do
    let timers ← get
    match timers.find? id with
    | some (_, timerstate) => do
      if let .running task := timerstate then do
        IO.cancel task
      let timers' : Timers := timers.erase id
      set timers'
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
  (state : SanddState) (id : TimerId) (due : Moment) : IO Unit := loop
  where
  loop := do
    let now ← Moment.mk <$> IO.monoMsNow
    let remaining := due - now
    -- This task will be cancelled if the timer is cancelled or paused.
    -- in case of resumed, a new separate task will be spawned.
    if ← IO.checkCanceled then return
    if remaining.millis == 0 then
      _ ← Sand.notify s!"Time's up!"
      playTimerSound
      _ ← state.removeTimer id
      return
    if remaining.millis > 30 then
      IO.sleep (remaining.millis/2).toUInt32
    loop

def SanddState.resumeTimer
  (state : SanddState) (timerId : TimerId) (clientConnectedTime : Moment)
  : BaseIO (TimerOpResult Unit) := state.timers.atomically do
  let timers ← get
  let some (timer, timerstate) := timers.find? timerId | do
    return .error .notFound
  match timerstate with
  | .running _ => return .error .noop
  | .paused remaining => do
    let newDueTime : Moment := clientConnectedTime + remaining
    let countdownTask ← IO.asTask <| countdown state timerId newDueTime
    let newTimerstate := .running countdownTask
    let newTimer := {timer with due := newDueTime}
    let timers' : Timers := timers.insert timerId (newTimer, newTimerstate)
    set timers'
    return .ok ()

def SanddState.initial : IO SanddState := do
  return {
    nextTimerId := (← IO.Mutex.new 1),
    timers := (← IO.Mutex.new ∅)
  }

def SanddState.addTimer (state : SanddState) (due : Moment) : BaseIO Unit := do
  let id : TimerId ←
    TimerId.mk <$> state.nextTimerId.atomically (getModify Nat.succ)
  let timer : Timer := ⟨id, due⟩
  let countdownTask ← IO.asTask <| countdown state id due
  state.timers.atomically <| modify (·.insert id (timer, .running countdownTask))

partial def busyWaitTil (due : Nat) : IO Unit := do
  while (← IO.monoMsNow) < due do
    pure ()

def addTimer (state : SanddState) (startTime : Moment) (duration : Duration) : IO Unit := do
  -- run timer
  let msg := s!"Starting timer for {duration.formatColonSeparated}"

  IO.eprintln msg
  _ ← Sand.notify msg

  -- TODO: problem with this approach - time spent suspended is not counted.
  -- eg if I set a 1 minute timer, then suspend at 30s, the timer will
  -- go off 30s after wake.{}
  let timerDue := startTime + duration

  state.addTimer timerDue

def handleClientCmd (cmd : Command) : CmdHandlerT IO CmdResponse := do
  let {state, client, clientConnectedTime} ← read
  match cmd with
  | .addTimer durationMs => do
    _ ← IO.asTask <| addTimer state clientConnectedTime durationMs
    return CmdResponse.ok
  | .cancelTimer which => do
    match ← state.removeTimer which with
    | .error .notFound => do
      return CmdResponse.timerNotFound which
    -- TODO yuck
    | .error err@(.noop) => do
      let errMsg  := s!"BUG: Unexpected error \"{repr err}\" from removeTimer."
      IO.eprintln errMsg
      return .serviceError errMsg
    | .ok () => pure CmdResponse.ok
  | .list => do
    let timers ← state.timers.atomically get
    return CmdResponse.list <| Sand.timersForClient timers
  | .pause which => do
    let result ← (SanddState.pauseTimer which).run {state, client, clientConnectedTime}
    return responseForResult which result
  | .resume which => do
    let result ← state.resumeTimer which clientConnectedTime
    return responseForResult which result
  where
  responseForResult (timerId : TimerId) result :=
    match result with
    | .ok () => CmdResponse.ok
    | .error .notFound => CmdResponse.timerNotFound timerId
    | .error .noop => CmdResponse.noop

def handleClient : CmdHandlerT IO Unit := do
  let {client, ..} ← read
  -- receive and parse message
  let bytes ← client.recv (maxBytes := 1024)
  let clientMsg := String.fromUTF8! bytes

  let .ok (cmd : Command) := fromJson? =<< Json.parse clientMsg | do
    let errMsg := s!"failed to parse client message: invalid command \"{clientMsg}\""
    IO.eprintln errMsg
    _ ← Sand.notify errMsg

  let resp ← handleClientCmd cmd
  _ ← client.send resp.serialize

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
    let _tsk ← IO.asTask <| do
      let clientConnectedTime ← Moment.mk <$> IO.monoMsNow
      let env := {state, client, clientConnectedTime}
      handleClient.run env
end SandDaemon
