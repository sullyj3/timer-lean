import Socket

open System (FilePath)

def main : IO Unit := do

  let sockPath : FilePath := "/home/james/tmp/lean-timer-socket"
  if (← sockPath.pathExists) then do
    IO.FS.removeFile sockPath

  let addr := Socket.SockAddrUnix.unix sockPath
  let sock : Socket ← Socket.mk .unix .stream

  sock.bind addr
  sock.listen 1

  IO.println "listening..."
  let (client, _sa) ← sock.accept
  IO.println "client connected"

  sock.close

  IO.println "end"



