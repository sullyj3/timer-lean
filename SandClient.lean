import Lean
import Socket
import FFI

import Sand

open Sand (Command)

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
  | args => do
    let duration ← parseTimer args
    return .addTimer duration

def unlines := String.intercalate "\n"

def showTimer (now : Nat) : Timer → String
  | {id, due} =>
    let remaining : Duration := ⟨due - now⟩
    let formatted := remaining.formatColonSeparated

    s!"#{repr id} | {formatted} remaining"

def showTimers (timers : List Timer) (now : Nat) : String :=
  if timers.isEmpty then
    "No running timers."
  else
    unlines <| List.map (showTimer now) <| timers

open Lean (fromJson? toJson) in
def handleCmd (sock : Socket) (cmd : Command) : IO Unit := do
  let msg : String := toString <| toJson cmd
  let _nBytes ← sock.send msg.toUTF8

  match cmd with
  | Command.addTimer _ => pure ()
  | Command.list => do
    let resp ← sock.recv 10240

    let timers? : Except String (List Timer) := do
      let json ← Lean.Json.parse <| String.fromUTF8! resp
      fromJson? json

    let .ok timers := timers? | do
      println! "failed to parse message from server. exiting"

    let now ← IO.monoMsNow
    IO.println <| showTimers timers now

def sandClient (args : List String) : IO Unit := do

  let some cmd := parseArgs args | do
    println! "bad args"
    IO.Process.exit 1

  let sockPath ← Sand.getSockPath
  if not (← sockPath.pathExists) then do
    IO.println "socket doesn't exist. Is the server running?"
    IO.Process.exit 1

  withUnixSocket sockPath (handleCmd · cmd)

def main := sandClient
