import Sand

def main (args : List String) : IO UInt32 := do
  match args with
  | ("daemon" :: rest) => SandDaemon.main rest
  | _                  => SandClient.main args
