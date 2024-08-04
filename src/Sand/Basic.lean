import Lean
import Socket
import «Sand».Time

open Lean (HashMap ToJson FromJson toJson)
open System (FilePath)
open Sand (Moment)

def Batteries.HashMap.values [BEq α] [Hashable α] (hashMap : HashMap α β) : Array β :=
  hashMap.toArray |>.map Prod.snd

namespace Sand

elab "get_version" : term => do
  let version ← do
    -- this is necessary in CI
    if let some version ← IO.getEnv "GIT_DESCRIBE" then
      pure version
    else
      String.trimRight <$> IO.Process.run { cmd := "git", args := #["describe"] }
  return .lit <| .strVal version

def version : String := get_version

structure TimerId where
  id : Nat
  deriving BEq, Repr, ToJson, FromJson, Hashable

def TimerId.fromNat (n : Nat) : TimerId := ⟨n⟩

inductive Timer
  | paused (remaining : Duration)
  | running (due : Moment) (task : Task (Except IO.Error Unit))

inductive TimerStateForClient
  | paused (remaining : Duration)
  | running (due : Moment)
  deriving Repr, ToJson, FromJson

structure TimerInfoForClient where
  id : TimerId
  state : TimerStateForClient
  deriving Repr, ToJson, FromJson

def timerForClient (id : TimerId) (timer : Timer) : TimerInfoForClient :=
  let state : TimerStateForClient := match timer with
  | .running due _task => .running due
  | .paused remaining => .paused remaining
  { id, state }

def timersForClient
  (timers : HashMap TimerId Timer)
  : Array TimerInfoForClient := timers.toArray.map (λ (a, b) ↦ timerForClient a b)

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
