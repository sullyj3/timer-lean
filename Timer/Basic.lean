open System (FilePath)

def runtimeDir : IO FilePath := IO.getEnv "XDG_RUNTIME_DIR" >>= 
  λ | some runtimeDir => return runtimeDir
    | none => do
      IO.eprintln "Error: failed to get XDG_RUNTIME_DIR!"
      IO.Process.exit 1

namespace Timer

def getSockPath : IO FilePath := 
  runtimeDir <&> (· / "timerd.sock")

end Timer
