import Socket
import «Sand».Basic
import «Sand».Time
import «Sand».Message

open Sand

def withUnixSocket path (action : Socket → IO a) := do
  let addr := Socket.SockAddrUnix.unix path
  let sock : Socket ← Socket.mk .unix .stream
  sock.connect addr

  let result ← action sock

  sock.close
  return result

open System (FilePath)

def String.span (s : String) (p : Char → Bool) : (String × String) :=
  (s.takeWhile p, s.dropWhile p)

inductive TimeUnit
  | hours
  | minutes
  | seconds
  | milliseconds
  deriving Repr, BEq

namespace TimeUnit
def parse (s : String) : Option TimeUnit :=
  match s.toLower with
  | "h"     => some .hours
  | "hr"    => some .hours
  | "hrs"   => some .hours
  | "hours" => some .hours

  | "m"       => some .minutes
  | "min"     => some .minutes
  | "mins"    => some .minutes
  | "minutes" => some .minutes

  | "s"       => some .seconds
  | "sec"     => some .seconds
  | "secs"    => some .seconds
  | "seconds" => some .seconds

  | "ms"           => some .milliseconds
  | "milli"        => some .milliseconds
  | "millis"       => some .milliseconds
  | "milliseconds" => some .milliseconds

  | ""   => some .seconds
  | _ => none

def toMillis : TimeUnit → Nat
  | .hours => 60 * 60 * 1000
  | .minutes => 60 * 1000
  | .seconds => 1000
  | .milliseconds => 1

end TimeUnit

def parseTimerWord (w : String) : Option Duration := do
  let (countStr, unitStr) := w.span Char.isDigit
  let count ← countStr.toNat?
  let unit ← TimeUnit.parse unitStr
  return ⟨count * unit.toMillis⟩

def parseTimer : List String → Option Duration
  | [] => none
  | xs => do
    let durations ← xs.mapM parseTimerWord
    return durations.foldr (·+·) {millis := 0}

def testParseTimer : IO Unit := do
  let cases : List (List String × Option Duration) := [
    -- bare number
    (["1"], some ⟨1000⟩),
    (["12"], some ⟨12000⟩),

    -- unit in same word
    (["500ms"], some ⟨500⟩),
    (["5s"], some ⟨5000⟩),
    (["5sec"], some ⟨5000⟩),
    (["5secs"], some ⟨5000⟩),
    (["5m"], some ⟨5 * 60 * 1000⟩),
    (["5min"], some ⟨5 * 60 * 1000⟩),
    (["5mins"], some ⟨5 * 60 * 1000⟩),

    -- multiple units
    (["1m", "30"], some ⟨90000⟩),
    (["1m", "30s"], some ⟨90000⟩),
    (["1min", "30s"], some ⟨90000⟩),
    (["1m", "30sec"], some ⟨90000⟩),
    (["2h", "15m"], some ⟨1000*60*60*2 + 1000*60*15⟩),
    (["2hrs", "15mins"], some ⟨1000*60*60*2 + 1000*60*15⟩),

    -- TODO
    -- unit in different word
    -- (["5", "seconds"], some ⟨5 * 1000⟩),
    -- (["5", "seconds"], some ⟨5 * 1000⟩),

    -- (["1m30"], some ⟨90000⟩),
  ]
  for (input, expected) in cases do
    let actual := parseTimer input
    IO.print s!"`parseTimer {repr input}`:"
    if actual != expected then do
      IO.println ""
      IO.println s!"  Test failed:"
      IO.println s!"    expected: {repr expected}"
      IO.println s!"    actual:   {repr actual}"
    else
      IO.println s!" Ok."

def parseArgs : List String → Option Command
  | [] => none
  | ["list"] => some .list
  | ["ls"] => some .list
  | ["cancel", idStr] => do
    let timerId ← idStr.toNat?
    return .cancelTimer { id := timerId }
  | ["pause", idStr] => do
    let timerId ← idStr.toNat?
    return .pauseTimer { id := timerId }
  | ["resume", idStr] => do
    let timerId ← idStr.toNat?
    return .resumeTimer { id := timerId }
  | args => do
    let duration ← parseTimer args
    return .addTimer duration

def unlines := String.intercalate "\n"

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
    fromJsonResponse? =<< Lean.Json.parse respStr
  let .ok resp := resp? | do
    IO.println "Failed to parse message from server:"
    println! "    \"{respStr}\""
    IO.Process.exit 1

  -- Handle response
  match cmd with
  | Command.addTimer timer => do
    let .ok := resp
    println! "Timer created for {timer.formatColonSeparated}."
  | Command.cancelTimer timerId => match resp with
    | .ok =>
      println! "Timer #{repr timerId.id} cancelled."
    | .timerNotFound => timerNotFound timerId
  | Command.list => do
    let .ok timers := resp
    let now ← Moment.mk <$> IO.monoMsNow
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

def getSockPath : IO FilePath :=
  runtimeDir <&> (· / "sand.sock")

def SandClient.main (args : List String) : IO UInt32 := do
  let some cmd := parseArgs args | do
    IO.println usage
    IO.Process.exit 1

  let sockPath ← getSockPath
  if not (← sockPath.pathExists) then do
    IO.println "socket doesn't exist. Is the server running?"
    IO.Process.exit 1

  withUnixSocket sockPath (handleCmd · cmd)
  return 0
