import Lake

open System Lake DSL

package timer

require batteries from git "https://github.com/leanprover-community/batteries"@"v4.9.1"
require socket from git "https://github.com/hargoniX/socket.lean"@"main"
require alloy from git "https://github.com/tydeu/lean4-alloy.git"@"master"

lean_lib Sand

module_data alloy.c.o.export : BuildJob FilePath
module_data alloy.c.o.noexport : BuildJob FilePath
lean_lib FFI where
  precompileModules := true
  nativeFacets := fun shouldExport =>
    if shouldExport then
      #[Module.oExportFacet, `alloy.c.o.export]
    else
      #[Module.oNoExportFacet, `alloy.c.o.noexport]

@[default_target] lean_exe sand where root := `SandClient
@[default_target] lean_exe sandd where root := `SandDaemon
