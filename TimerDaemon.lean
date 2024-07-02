import Socket

open System (FilePath)
open Socket (SockAddr)

def handleClient (client : Socket) (_clientAddr : SockAddr) : IO Unit := do
  let bytes ← client.recv (maxBytes := 1024)
  let msg := String.fromUTF8! bytes
  IO.println s!"received message from client: {msg}"

def main : IO Unit := do

  let sockPath : FilePath := "/home/james/tmp/lean-timer-socket"
  if (← sockPath.pathExists) then do
    IO.FS.removeFile sockPath

  let addr := Socket.SockAddrUnix.unix sockPath
  let sock : Socket ← Socket.mk .unix .stream

  sock.bind addr
  sock.listen 5

  IO.println "listening..."

  while true do
    let (client, clientAddr) ← sock.accept
    let _tsk ← handleClient client clientAddr |>.asTask
