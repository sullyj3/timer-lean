import Lean
import Socket
import Batteries
import «Sand».Time

open Lean (ToJson FromJson toJson)
open System (FilePath)
open Batteries (HashMap)

def Batteries.HashMap.values [BEq α] [Hashable α] (hashMap : HashMap α β) : Array β :=
  hashMap.toArray |>.map Prod.snd

namespace Sand

structure TimerId where
  id : Nat
  deriving BEq, Repr, ToJson, FromJson, Hashable

def TimerId.fromNat (n : Nat) : TimerId := ⟨n⟩

structure Timer where
  id : TimerId
  due : Nat
  deriving Repr, ToJson, FromJson

-- TODO this data model needs improvement
-- currently paused timers retain their outdated due times while they're paused
inductive TimerState
  | paused (remaining : Duration)
  | running (task : Task (Except IO.Error Unit))


-- TODO filthy hack.
-- revisit after reworking timer data model
inductive TimerStateForClient
  | running (due : Nat)
  | paused (remaining : Duration)
  deriving ToJson, FromJson

structure TimerInfoForClient where
  id : TimerId
  state : TimerStateForClient
  deriving ToJson, FromJson

def timersForClient
  (timers : HashMap TimerId (Timer × TimerState))
  : Array TimerInfoForClient :=
  timers.values.map λ (timer, timerstate) ↦
    let state : TimerStateForClient := match timerstate with
    | TimerState.running _ => .running timer.due
    | .paused remaining => .paused remaining
    { id := timer.id, state }

def nullStdioConfig : IO.Process.StdioConfig := ⟨.null, .null, .null⟩
def SimpleChild : Type := IO.Process.Child nullStdioConfig

def runCmdSimple (cmd : String) (args : Array String := #[]) : IO SimpleChild :=
  IO.Process.spawn
    { cmd := cmd,
      args := args,

      stdin := .null,
      stdout := .null,
      stderr := .null,
    }

def notify (message : String) : IO SimpleChild :=
  -- TODO wrap libnotify with FFI so we can do this properly
  runCmdSimple "notify-send" #[message]

-- commands sent from client to server
inductive Command
  | addTimer (duration : Duration)
  | list
  | cancelTimer (which : TimerId)
  | pause (which : TimerId)
  | resume (which : TimerId)
  deriving Repr, ToJson, FromJson

-- responses to commands sent from server to client
inductive CmdResponse
  | ok
  | list (timers : Array TimerInfoForClient)
  | timerNotFound (which : TimerId)
  | noop
  deriving ToJson, FromJson

def CmdResponse.serialize : CmdResponse → ByteArray :=
  String.toUTF8 ∘ toString ∘ toJson


end Sand
