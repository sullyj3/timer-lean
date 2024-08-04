import Lake

open System Lake DSL

require "hargoniX" / "socket"

package sand where
  srcDir := "src"

lean_lib Sand
lean_lib Daemon
lean_lib Client

@[default_target] lean_exe sand where
  root := `Main
