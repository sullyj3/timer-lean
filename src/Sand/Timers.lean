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

structure Timers where
  timers : HashMap TimerId Timer

instance : EmptyCollection Timers where
  emptyCollection := ⟨∅⟩

namespace Timers
def erase : Timers → TimerId → Timers
  | ⟨timers⟩, id => ⟨timers.erase id⟩

def find? : Timers → TimerId → Option Timer
  | ⟨timers⟩ => timers.find?

def insert : Timers → TimerId → Timer → Timers
  | ⟨timers⟩, k, v => ⟨timers.insert k v⟩

def forClient : Timers → Array TimerInfoForClient
  | ⟨timers⟩ => timers.toArray.map (λ (a, b) ↦ timerForClient a b)

end Timers
