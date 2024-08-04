import «Sand».Timers

open Sand Timers

structure DaemonState : Type where
  nextTimerId : IO.Mutex Nat
  timers : IO.Mutex Timers

def DaemonState.initial : IO DaemonState := do
  return {
    nextTimerId := (← IO.Mutex.new 1),
    timers := (← IO.Mutex.new ∅)
  }
