import Lake

open System Lake DSL

require socket from git "https://github.com/hargoniX/socket.lean"@"main"
require batteries from git "git@github.com:leanprover-community/batteries.git"@"v4.9.1"

package sand where
  srcDir := "src"

lean_lib Sand

@[default_target] lean_exe sand where
  root := `Main
