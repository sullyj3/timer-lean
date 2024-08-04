import Lake

open System Lake DSL

require "hargoniX" / "socket"

package sand where
  srcDir := "src"

lean_lib Sand

@[default_target] lean_exe sand where
  root := `Main
