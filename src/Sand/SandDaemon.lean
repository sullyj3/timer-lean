import «Sand».Basic
import «Sand».Time
import «Sand».Message
import Batteries

open System (FilePath)
open Lean (Json ToJson FromJson toJson fromJson?)

open Batteries (HashMap)

open Sand

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

def Timers.erase (timers : Timers) (id : TimerId) : Timers := HashMap.erase timers id

structure DaemonState where
  nextTimerId : IO.Mutex Nat
  timers : IO.Mutex Timers

structure CmdHandlerEnv where
  state : DaemonState
  client : Socket
  clientConnectedTime : Moment

abbrev CmdHandlerT (m : Type → Type) : Type → Type := ReaderT CmdHandlerEnv m

instance monadLiftReaderT [MonadLift m n] : MonadLift (ReaderT σ m) (ReaderT σ n) where
  monadLift action := λ r => liftM <| action.run r

def ReaderT.asTask (action : ReaderT σ IO α) : ReaderT σ IO (Task (Except IO.Error α)) :=
  controlAt IO λ runInBase ↦ (runInBase action).asTask

def pauseTimer
  (timerId : TimerId)
  : CmdHandlerT BaseIO PauseTimerResponse := do
  let {state, clientConnectedTime, .. } ← read
  state.timers.atomically do
    let timers ← get
    let some (timer, timerstate) := timers.find? timerId | do
      return .timerNotFound
    match timerstate with
    | .paused _ => return .alreadyPaused
    | .running task => do
      IO.cancel task
      let remaining : Duration := timer.due - clientConnectedTime
      let newTimerstate := .paused remaining
      let newTimers : Timers := timers.insert timerId (timer, newTimerstate)
      set newTimers
      return .ok

def removeTimer (id : TimerId)
  : CmdHandlerT BaseIO CancelTimerResponse := do
  let {state, ..} ← read
  state.timers.atomically do
    let timers ← get
    match timers.find? id with
    | some (_, timerstate) => do
      if let .running task := timerstate then IO.cancel task
      set <| timers.erase id
      pure .ok
    | none => do
      pure .timerNotFound

-- IO.sleep isn't guaranteed to be on time, I find it's usually about 10ms late
-- Therefore, we repeatedly sleep while there's enough time left that we can
-- afford to be inaccurate, and spin once we're close to the due time. This
-- strategy aims to be exactly on time (to the millisecond), while avoiding a
-- long busy wait which consumes too much cpu.
partial def countdown (id : TimerId) (due : Moment) : CmdHandlerT IO Unit := do
  loop
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
      match ← removeTimer id with
      | .ok => return
      | .timerNotFound => do
        IO.eprintln s!"BUG: countdown tried to remove nonexistent timer {repr id.id}"
    if remaining.millis > 30 then
      IO.sleep (remaining.millis/2).toUInt32
    loop

def resumeTimer (timerId : TimerId)
  : CmdHandlerT BaseIO ResumeTimerResponse := do
  let env@{state, clientConnectedTime, ..} ← read
  state.timers.atomically do
    let timers ← get
    let some (timer, timerstate) := timers.find? timerId | do
      return .timerNotFound
    match timerstate with
    | .running _ => return .alreadyRunning
    | .paused remaining => do
      let newDueTime : Moment := clientConnectedTime + remaining
      let countdownTask ← IO.asTask <| (countdown timerId newDueTime).run env
      let newTimerstate := .running countdownTask
      let newTimer := {timer with due := newDueTime}
      let timers' : Timers := timers.insert timerId (newTimer, newTimerstate)
      set timers'
      return .ok

def DaemonState.initial : IO DaemonState := do
  return {
    nextTimerId := (← IO.Mutex.new 1),
    timers := (← IO.Mutex.new ∅)
  }

partial def busyWaitTil (due : Nat) : IO Unit := do
  while (← IO.monoMsNow) < due do
    pure ()

def addTimer (duration : Duration) : CmdHandlerT IO Unit := do
  let {clientConnectedTime, state, ..} ← read

  let msg := s!"Starting timer for {duration.formatColonSeparated}"
  IO.eprintln msg
  _ ← Sand.notify msg

  -- TODO: problem with this approach - time spent suspended is not counted.
  -- eg if I set a 1 minute timer, then suspend at 30s, the timer will
  -- go off 30s after wake.{}
  let due := clientConnectedTime + duration
  let id : TimerId ←
    TimerId.mk <$> state.nextTimerId.atomically (getModify Nat.succ)
  let timer : Timer := {id, due}
  let countdownTask ← (countdown id due).asTask

  state.timers.atomically <| modify (·.insert id (timer, .running countdownTask))

def handleClientCmd (cmd : Command) : CmdHandlerT IO (ResponseFor cmd) := do
  let {state, ..} ← read
  match cmd with
  | .addTimer duration => do
    addTimer duration
    return .ok
  | .cancelTimer which => removeTimer which
  | .list => do
    let timers ← state.timers.atomically get
    return .ok <| Sand.timersForClient timers
  | .pauseTimer which => pauseTimer which
  | .resumeTimer which => resumeTimer which

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
  _ ← client.send <| serializeResponse resp

partial def forever (act : IO α) : IO β := act *> forever act

def SandDaemon.main (_args : List String) : IO α := do
  let systemdSockFd := 3
  let sock ← Socket.fromFd systemdSockFd

  IO.eprintln "sandd started"
  IO.eprintln "listening..."

  let state ← DaemonState.initial

  forever do
    let (client, _clientAddr) ← sock.accept
    let _tsk ← IO.asTask <| do
      let clientConnectedTime ← Moment.mk <$> IO.monoMsNow
      let env := {state, client, clientConnectedTime}
      handleClient.run env
