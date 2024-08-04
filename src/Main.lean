import «Sand»
import «Daemon»
import «Client»

def version : IO UInt32 := do
  println! "Sand {Sand.version}"
  return 0

def main (args : List String) : IO UInt32 := do
  match args with
  | ("version" :: _) => version
  | ("daemon" :: rest) => Daemon.main rest
  | _                  => Client.main args
