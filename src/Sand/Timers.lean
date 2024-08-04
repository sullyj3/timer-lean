import Lean.Data.Json.FromToJson

import «Sand».Time

open Lean ToJson FromJson

def List.eraseBy (xs : List α) (pred : α → Bool) : List α := match xs with
  | [] => []
  | x :: xs =>
    if pred x then xs
    else x :: xs.eraseBy pred

def List.tryReplaceOne (xs : List α) (f : α → Option α) : Option (List α) := match xs with
  | [] => none
  | x :: xs => match f x with
    | some y => some (y :: xs)
    | none => do
      let ys ← xs.tryReplaceOne f
      return x :: ys

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
  timers : List (TimerId × Timer)

instance : EmptyCollection Timers where
  emptyCollection := ⟨∅⟩

namespace Timers
def erase : Timers → TimerId → Timers
  | ⟨timers⟩, id => ⟨timers.eraseBy (·.fst == id) ⟩

def find? : Timers → TimerId → Option Timer
  | ⟨timers⟩ => timers.lookup

def insert : Timers → TimerId → Timer → Timers
  | timers, id, timer =>
    let tryReplace := λ (id', _) => if id == id' then some (id, timer) else none
    match timers.timers.tryReplaceOne tryReplace with
    | some timers' => ⟨timers'⟩
    | none => Timers.mk <| (id, timer) :: timers.timers

def forClient : Timers → Array TimerInfoForClient
  | ⟨timers⟩ => timers.toArray.map (λ (a, b) ↦ timerForClient a b)

end Timers
