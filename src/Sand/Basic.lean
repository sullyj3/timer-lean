import Lean
import Socket
import Batteries
import «Sand».Time

open Lean (ToJson FromJson toJson)
open System (FilePath)
open Batteries (HashMap)
open Sand (Moment)

def Batteries.HashMap.values [BEq α] [Hashable α] (hashMap : HashMap α β) : Array β :=
  hashMap.toArray |>.map Prod.snd

namespace Sand

structure TimerId where
  id : Nat
  deriving BEq, Repr, ToJson, FromJson, Hashable

def TimerId.fromNat (n : Nat) : TimerId := ⟨n⟩

structure Timer where
  id : TimerId
  due : Moment
  deriving Repr, ToJson, FromJson

-- TODO this data model needs improvement
-- currently paused timers retain their outdated due times while they're paused
inductive TimerState
  | paused (remaining : Duration)
  | running (task : Task (Except IO.Error Unit))

-- TODO filthy hack.
-- revisit after reworking timer data model
inductive TimerStateForClient
  | running (due : Moment)
  | paused (remaining : Duration)
  deriving Repr, ToJson, FromJson

structure TimerInfoForClient where
  id : TimerId
  state : TimerStateForClient
  deriving Repr, ToJson, FromJson

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

def runCmdSimple (cmd : String) (args : Array String := #[]) : IO Unit := do
  let child ← IO.Process.spawn
    { cmd := cmd,
      args := args,

      stdin := .null,
      stdout := .null,
      stderr := .null,
    }
  _ ← (child.wait).asTask

def notify (message : String) : IO Unit := do
  -- TODO wrap libnotify with FFI so we can do this properly
  runCmdSimple "notify-send" #[message]

end Sand
