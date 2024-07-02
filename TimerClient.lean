import Socket

def withUnixSocket path (action : Socket → IO a) := do
  let addr := Socket.SockAddrUnix.unix path
  let sock : Socket ← Socket.mk .unix .stream
  sock.connect addr

  let result ← action sock

  sock.close

  return result

open System (FilePath)

def main : IO Unit := do

  let sockPath : FilePath := "/home/james/tmp/lean-timer-socket"
  if not (← sockPath.pathExists) then do
    IO.println "socket doesn't exist. Is the server running?"
    IO.Process.exit 1

  for _ in [0:100] do
    withUnixSocket sockPath λ sock ↦ do
      IO.println "connected to server"
      let msg := "Hello, server!"
      let _nBytes ← sock.send msg.toUTF8
      IO.println "sent message. Exiting"



