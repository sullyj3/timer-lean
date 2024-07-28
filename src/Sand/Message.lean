import Lean
import «Sand».Basic

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
  | ok
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

def ResponseFor : Command → Type
  | .addTimer    _ => AddTimerResponse
  | .list          => ListResponse
  | .cancelTimer _ => CancelTimerResponse
  | .pauseTimer  _ => PauseTimerResponse
  | .resumeTimer _ => ResumeTimerResponse

def toJsonResponse {cmd : Command} (resp : ResponseFor cmd) : Lean.Json := by
  cases cmd <;> (
    simp only [ResponseFor] at resp
    exact toJson resp
  )

def serializeResponse {cmd : Command} (resp : ResponseFor cmd) : ByteArray :=
  String.toUTF8 <| toString <| toJsonResponse resp

def fromJsonResponse? {cmd : Command}
  (resp : Json) : Except String (ResponseFor cmd) := by
  cases cmd <;> (
    simp only [ResponseFor]
    exact fromJson? resp
  )


end Sand
