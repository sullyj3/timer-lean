import Lean
import «Sand».Basic

open Lean (ToJson FromJson toJson)

namespace Sand

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
  | serviceError (msg : String)
  deriving ToJson, FromJson

def CmdResponse.serialize : CmdResponse → ByteArray :=
  String.toUTF8 ∘ toString ∘ toJson

end Sand
