open System (FilePath)

def runtimeDir : IO FilePath := do
  let mRuntimeDir ← IO.getEnv "XDG_RUNTIME_DIR"
  mRuntimeDir.getDM do
    IO.eprintln "Error: failed to get XDG_RUNTIME_DIR!"
    IO.Process.exit 1

namespace Timer

def getSockPath : IO FilePath := 
  return (← runtimeDir).join "timerd.sock"

end Timer
