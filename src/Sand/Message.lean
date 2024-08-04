import Lean.Data.Json.Basic
import «Sand».Basic
import «Sand».Timers

open Lean (Json ToJson FromJson toJson fromJson?)

namespace Sand

-- commands sent from client to server
inductive Command
  | addTimer (duration : Duration)
  | list
  | cancelTimer (which : TimerId)
  | pauseTimer  (which : TimerId)
  | resumeTimer (which : TimerId)
  deriving Repr, ToJson, FromJson

-- responses to commands sent from server to client
inductive AddTimerResponse
  | ok (createdId : TimerId)
  deriving Repr, ToJson, FromJson

inductive ListResponse
  | ok (timers : Array TimerInfoForClient)
  deriving Repr, ToJson, FromJson

inductive CancelTimerResponse
  | ok
  | timerNotFound
  deriving Repr, ToJson, FromJson

inductive PauseTimerResponse
  | ok
  | timerNotFound
  | alreadyPaused
  deriving Repr, ToJson, FromJson

inductive ResumeTimerResponse
  | ok
  | timerNotFound
  | alreadyRunning
  deriving Repr, ToJson, FromJson

abbrev ResponseFor : Command → Type
  | .addTimer    _ => AddTimerResponse
  | .list          => ListResponse
  | .cancelTimer _ => CancelTimerResponse
  | .pauseTimer  _ => PauseTimerResponse
  | .resumeTimer _ => ResumeTimerResponse

instance {cmd : Command} : ToJson (ResponseFor cmd) := by
  cases cmd <;> exact inferInstance

instance {cmd : Command} : FromJson (ResponseFor cmd) := by
  cases cmd <;> exact inferInstance

def serializeResponse {cmd : Command} (resp : ResponseFor cmd) : ByteArray :=
  String.toUTF8 <| toString <| toJson resp

end Sand
