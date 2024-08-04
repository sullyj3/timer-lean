import Lean.Data.Json.FromToJson

open Lean (ToJson FromJson toJson)

namespace Sand

structure Moment where
  millis : Nat
  deriving Repr, ToJson, FromJson, BEq

structure Duration where
  millis : Nat
  deriving Repr, ToJson, FromJson, BEq

instance : Add Duration where
  add d1 d2 := { millis := d1.millis + d2.millis }

instance : HAdd Moment Duration Moment where
  hAdd mom dur := {millis := mom.millis + dur.millis : Moment}

instance instHsubMoments : HSub Moment Moment Duration where
  hSub m1 m2 := { millis := m1.millis - m2.millis }

namespace Duration

def fromSeconds (seconds : Nat) : Duration := { millis := 1000 * seconds }

-- This is for formatting, not canonical representation of
-- duration
private structure HMSMs where
  hours : Nat
  minutes : Fin 60
  seconds : Fin 60
  millis : Fin 1000
  deriving Repr

private def toHMSMs (d : Duration) : HMSMs :=
  let seconds := d.millis / 1000
  let minutes := seconds / 60
  let hours   := minutes / 60
  {
    hours   := hours,
    minutes := Fin.ofNat' minutes  (Nat.zero_lt_succ _)
    seconds := Fin.ofNat' seconds  (Nat.zero_lt_succ _)
    millis  := Fin.ofNat' d.millis (Nat.zero_lt_succ _)
  }

private def String.replicate (n : Nat) (c : Char) : String :=
  ⟨List.replicate n c⟩

private def zeroPad (minWidth : Nat) (s : String) :=
  if s.length < minWidth then
    let pfx := String.replicate (minWidth - s.length) '0'
    pfx ++ s
  else
    s

def formatColonSeparated (d : Duration) : String :=
  let {hours, minutes, seconds, millis} := d.toHMSMs
  let h  := zeroPad 2 <| toString hours
  let m  := zeroPad 2 <| toString minutes
  let s  := zeroPad 2 <| toString seconds
  let ms := zeroPad 3 <| toString millis

  s!"{h}:{m}:{s}:{ms}"

end Duration

end Sand
