import Lake

open System Lake DSL

require socket from git "https://github.com/hargoniX/socket.lean"@"main"

package sand where
  srcDir := "src"

lean_lib Sand

@[default_target] lean_exe sand where 
  root := `Main
