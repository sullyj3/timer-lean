import Socket
import «Sand».Basic
import «Sand».Message
import «Client».CLI

open Sand

def withUnixSocket path (action : Socket → IO a) := do
  let addr := Socket.SockAddrUnix.unix path
  let sock : Socket ← Socket.mk .unix .stream
  sock.connect addr

  let result ← action sock

  sock.close
  return result

open System (FilePath)

def showTimer (now : Moment) : TimerInfoForClient → String
  | {id, state} =>
    match state with
    | .running due =>
      let remaining : Duration := due - now
      let formatted := remaining.formatColonSeparated
      s!"#{repr id.id} | {formatted} remaining"
    | .paused remaining =>
      let formatted := remaining.formatColonSeparated
      s!"#{repr id.id} | {formatted} remaining (PAUSED)"

def unlines := String.intercalate "\n"

def showTimers (timers : List TimerInfoForClient) (now : Moment) : String :=
  if timers.isEmpty then
    "No running timers."
  else
    unlines <| List.map (showTimer now) <| timers

open Lean (fromJson? toJson) in
def handleCmd (server : Socket) (cmd : Command) : IO Unit := do
  let msg : String := toString <| toJson cmd
  let _nBytes ← server.send msg.toUTF8

  -- TODO: need a way to recv with timeout in case of daemon failure
  -- TODO: think more about receive buffer size.
  --   in particular, list response can be arbitrarily long
  --   we should handle that correctly without allocating such a large
  --   buffer in the common case
  let respStr ← String.fromUTF8! <$> server.recv 10240
  let resp? : Except String (ResponseFor cmd) :=
    fromJson? =<< Lean.Json.parse respStr
  let .ok resp := resp? | do
    IO.println "Failed to parse message from server:"
    println! "    \"{respStr}\""
    IO.Process.exit 1

  -- Handle response
  match cmd with
  | Command.addTimer timer => do
    let .ok id := resp
    println! "Timer #{repr id.id} created for {timer.formatColonSeparated}."
  | Command.cancelTimer timerId => match resp with
    | .ok =>
      println! "Timer #{repr timerId.id} cancelled."
    | .timerNotFound => timerNotFound timerId
  | Command.list => do
    let .ok timers := resp
    let now ← Moment.now
    IO.println <| showTimers timers.data now
  | Command.pauseTimer which => match resp with
    | .ok =>
      println! "Timer #{repr which.id} paused."
    | .timerNotFound => timerNotFound which
    | .alreadyPaused =>
      println! "Timer {repr which.id} is already paused."
  | Command.resumeTimer which => match resp with
    | .ok =>
      println! "Timer #{repr which.id} resumed."
    | .timerNotFound => timerNotFound which
    | .alreadyRunning =>
      println! "Timer {repr which.id} is already running."

  where
  timerNotFound (timerId : TimerId) := do
    println! "Timer with id \"{repr timerId.id}\" not found."
    IO.Process.exit 1

def usage : String := unlines [
    "Usage:",
    "",
    "sand <DURATION>",
    "  Start a new timer for the given duration.",
    "",
    "  Durations are specified with a space separated list of unit amounts.",
    "  For example:",
    "    sand 2hr 5min 3s 500ms",
    "    sand 1m 3ms",
    "  if no unit is provided, seconds are assumed",
    "    sand 30",
    "",
    "sand ls | sand list   ",
    "",
    "  List active timers",
    "",
    "sand pause <TIMER_ID>",
    "",
    "  Pause the timer with the given ID.",
    "",
    "sand resume <TIMER_ID>",
    "",
    "  Resume the timer with the given ID.",
    "",
    "sand cancel <TIMER_ID>",
    "",
    "  Cancel the timer with the given ID.",
  ]

def runtimeDir : IO FilePath := do
  let some dir ← IO.getEnv "XDG_RUNTIME_DIR" | do
    IO.eprintln "Error: failed to get XDG_RUNTIME_DIR!"
    IO.Process.exit 1
  return dir

def getSockPath : IO FilePath := do
  if let some path ← IO.getEnv "SAND_SOCK_PATH" then
    pure path
  else
    runtimeDir <&> (· / "sand.sock")

def Client.main (args : List String) : IO UInt32 := do
  let some cmd := CLI.parseArgs args | do
    IO.println usage
    IO.Process.exit 1

  let sockPath ← getSockPath
  if not (← sockPath.pathExists) then do
    IO.println "socket doesn't exist. Is the server running?"
    IO.Process.exit 1

  withUnixSocket sockPath (handleCmd · cmd)
  return 0
