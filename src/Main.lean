import Sand

def version : IO UInt32 := do
  println! "Sand {Sand.version}"
  return 0

def main (args : List String) : IO UInt32 := do
  match args with
  | ("version" :: _) => version
  | ("daemon" :: rest) => SandDaemon.main rest
  | _                  => SandClient.main args
