import Lake

open System Lake DSL

package timer

require socket from git "https://github.com/hargoniX/socket.lean"@"main"

lean_lib Sand

@[default_target] lean_exe sand where root := `SandClient
@[default_target] lean_exe sandd where root := `SandDaemon
