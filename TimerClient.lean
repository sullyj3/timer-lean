import Socket

import Timer

def withUnixSocket path (action : Socket → IO a) := do
  let addr := Socket.SockAddrUnix.unix path
  let sock : Socket ← Socket.mk .unix .stream
  sock.connect addr

  let result ← action sock

  sock.close
  return result

open System (FilePath)

def parseArgs : List String → Option Nat
  | [] => none
  | [strN] => strN.toNat?
  | _ => none

def main (args : List String) : IO Unit := do

  let some (nSeconds : Nat) := parseArgs args | do
    println! "bad args"
    IO.Process.exit 1

  let sockPath ← Timer.getSockPath
  if not (← sockPath.pathExists) then do
    IO.println "socket doesn't exist. Is the server running?"
    IO.Process.exit 1

  withUnixSocket sockPath λ sock ↦ do
    IO.println "connected to server"
    let msg := reprStr (nSeconds * 1000)
    let _nBytes ← sock.send msg.toUTF8
    IO.println "sent message. Exiting"
