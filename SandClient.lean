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

def parseArgs : List String → Option Command
  | [] => none
  | ["list"] => some .list
  | [strN] => do
    let nSeconds ← strN.toNat?
    return .addTimer <| Duration.fromSeconds nSeconds
  | _ => none

def unlines := String.intercalate "\n"

def showTimer (now : Nat) : Timer → String
  | {id, due} =>
    let remaining : Duration := ⟨due - now⟩
    let formatted := remaining.formatColonSeparated

    s!"{repr id} | {due} ({formatted} remaining)"

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
    IO.println s!"now: {now}"
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
