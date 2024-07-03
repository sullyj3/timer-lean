open System (FilePath)

def Option.getOrFail (msg : String) : Option α → IO α
| some x => return x
| none => do
  IO.eprintln msg
  IO.Process.exit 1

def runtimeDir : IO FilePath := do
  (← IO.getEnv "XDG_RUNTIME_DIR")
    |>.getOrFail "Error: failed to get XDG_RUNTIME_DIR!"

namespace Timer

def getSockPath : IO FilePath := 
  runtimeDir <&> (· / "timerd.sock")

end Timer
