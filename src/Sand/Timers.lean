import Lean.Data.HashMap
import Lean.Data.Json.FromToJson

import «Sand».Time

open Lean HashMap ToJson FromJson

namespace Sand

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

-- TODO make abstract to allow switching representations more easily
def Timers := HashMap TimerId Timer
  deriving EmptyCollection

def Timers.erase : Timers → TimerId → Timers := HashMap.erase
