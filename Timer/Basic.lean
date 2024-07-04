import Socket
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

inductive SockSource 
  | create | systemd

def getSocket : SockSource → IO Socket
  | .create => do
    let sockPath ← getSockPath
    IO.println s!"sockPath is {sockPath}"

    if (← sockPath.pathExists) then do
      IO.FS.removeFile sockPath

    let addr := Socket.SockAddrUnix.unix sockPath
    let sock : Socket ← Socket.mk .unix .stream

    sock.bind addr
    sock.listen 5
    return sock

  | .systemd =>
    let systemdSocketActivationFd : UInt32 := 3
    Socket.fromFd systemdSocketActivationFd true

end Timer
