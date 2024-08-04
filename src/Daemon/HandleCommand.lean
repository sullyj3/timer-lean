import «Sand».Message
import «Daemon».Basic

open System (FilePath)
open Sand

structure CmdHandlerEnv : Type where
  state : DaemonState
  client : Socket
  clientConnectedTime : Moment
  soundPath? : Option FilePath

private abbrev CmdHandlerT (m : Type → Type) : Type → Type := ReaderT CmdHandlerEnv m

instance monadLiftReaderT [MonadLift m n] : MonadLift (ReaderT σ m) (ReaderT σ n) where
  monadLift action := λ r => liftM <| action.run r

def ReaderT.asTask (action : ReaderT σ IO α) (prio := Task.Priority.default) : ReaderT σ IO (Task (Except IO.Error α)) :=
  controlAt IO λ runInBase ↦ (runInBase action).asTask prio

def Except.get : Except α α → α
  | ok x => x
  | error x => x

/-- Run an ExceptT that returns and throws the same type.
    This is useful because returning is limited to the enclosing `do`,
    whereas `throw` propagates until it's handled
-/
def runExceptBoth [Monad m] (action : ExceptT α m α) : m α :=
  Except.get <$> action.run

private def playTimerSound : CmdHandlerT IO Unit := do
  let {soundPath?, ..} ← read
  let some soundPath := soundPath? | return ()
  -- todo look into playing the audio ourselves
  _ ← Sand.runCmdSimple "paplay" #[soundPath.toString]

private def pauseTimer
  (timerId : TimerId)
  : CmdHandlerT BaseIO PauseTimerResponse := runExceptBoth do
  let {state, clientConnectedTime, .. } ← read
  state.timers.atomically do
    let timers ← get
    let some timer := timers.find? timerId | throw .timerNotFound
    match timer with
    | .paused _ => throw .alreadyPaused
    | .running due task => do
      IO.cancel task
      let newTimers : Timers := timers.insert timerId <| .paused (remaining := due - clientConnectedTime)
      set newTimers
      return .ok

private def removeTimer (id : TimerId)
  : CmdHandlerT BaseIO CancelTimerResponse := runExceptBoth do
  let {state, ..} ← read
  state.timers.atomically do
    let timers ← get
    let some timer := timers.find? id | throw .timerNotFound
    if let .running _due task := timer then IO.cancel task
    set <| timers.erase id
    pure .ok

-- IO.sleep isn't guaranteed to be on time, I find it's usually about 10ms late
-- Therefore, we repeatedly sleep while there's enough time left that we can
-- afford to be inaccurate, and spin once we're close to the due time. This
-- strategy aims to be exactly on time (to the millisecond), while avoiding a
-- long busy wait which consumes too much cpu.
private partial def countdown (id : TimerId) (due : Moment) : CmdHandlerT IO Unit := do
  loop
  where
  loop := do
    let now ← Moment.now
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
        return
    if remaining.millis > 30 then
      IO.sleep (remaining.millis/2).toUInt32
    loop

private def resumeTimer (timerId : TimerId)
  : CmdHandlerT BaseIO ResumeTimerResponse := runExceptBoth do
  let env@{state, clientConnectedTime, ..} ← read
  state.timers.atomically do
    let timers ← get
    let some timer := timers.find? timerId | throw .timerNotFound
    match timer with
    | .running _ _ => throw .alreadyRunning
    | .paused remaining => do
      let newDueTime : Moment := clientConnectedTime + remaining
      let countdownTask ← (countdown timerId newDueTime).run env |>.asTask .dedicated
      let timers' : Timers := timers.insert timerId <| .running newDueTime countdownTask
      set timers'
      return .ok

private def addTimer (duration : Duration) : CmdHandlerT IO AddTimerResponse := do
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
  let countdownTask ← (countdown id due).asTask .dedicated
  let timer : Timer := .running due countdownTask
  state.timers.atomically <| modify (·.insert id timer)
  return .ok id

private def list : CmdHandlerT BaseIO ListResponse := do
  let {state, ..} ← read
  let timers ← state.timers.atomically get
  return .ok timers.forClient

private def handleClientCmd : (cmd : Command) → CmdHandlerT IO (ResponseFor cmd)
  | .addTimer duration => addTimer duration
  | .cancelTimer which => removeTimer which
  | .list => list
  | .pauseTimer which => pauseTimer which
  | .resumeTimer which => resumeTimer which

open Lean (Json ToJson FromJson toJson fromJson?) in
def handleClient (env : CmdHandlerEnv) : IO Unit := ReaderT.run (r := env) do
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

  -- TODO accept messages in loop, allow client to close. Requires message framing
  client.close
