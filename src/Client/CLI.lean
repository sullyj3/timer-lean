import «Sand».Time
import «Sand».Message

open Sand Duration

private def String.span (s : String) (p : Char → Bool) : (String × String) :=
  (s.takeWhile p, s.dropWhile p)

private inductive TimeUnit
  | hours
  | minutes
  | seconds
  | milliseconds
  deriving Repr, BEq

namespace TimeUnit
private def parse (s : String) : Option TimeUnit :=
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

private def toMillis : TimeUnit → Nat
  | .hours => 60 * 60 * 1000
  | .minutes => 60 * 1000
  | .seconds => 1000
  | .milliseconds => 1

end TimeUnit

private def parseTimerWord (w : String) : Option Duration := do
  let (countStr, unitStr) := w.span Char.isDigit
  let count ← countStr.toNat?
  let unit ← TimeUnit.parse unitStr
  return ⟨count * unit.toMillis⟩

private def parseTimer : List String → Option Duration
  | [] => none
  | xs => do
    let durations ← xs.mapM parseTimerWord
    return durations.foldr (·+·) {millis := 0}

private def testParseTimer : IO Unit := do
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

def CLI.parseArgs : List String → Option Command
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
