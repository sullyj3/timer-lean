import «Sand»
import «Daemon»
import «Client»

def version : IO UInt32 := do
  println! "Sand {Sand.version}"
  return 0

def main : List String → IO UInt32
  | ("version" :: _)   => version
  | ("daemon" :: rest) => Daemon.main rest
  | args               => Client.main args
