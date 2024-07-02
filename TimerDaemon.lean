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
  let (client, clientAddr) ← sock.accept
  let clientAddrStr := clientAddr.addr
  IO.println s!"client connected: {clientAddrStr}"
  if "" = clientAddrStr then do
    IO.println "empty addrStr"

  let bytes ← client.recv (maxBytes := 1024)
  IO.print "received message from client: "
  let msg := String.fromUTF8! bytes
  IO.println msg

  sock.close

  IO.println "end"



