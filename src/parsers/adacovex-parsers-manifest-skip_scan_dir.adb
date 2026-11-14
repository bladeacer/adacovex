separate (Adacovex.Parsers.Manifest)
--  Whether the system-tool scan skips descending into a directory. The
--  scan reads only dev-facing build files, and a generated build tree is
--  not authored: its logs, caches, and configure output embed the
--  developer's whole environment, including PATH. Scanning them turned a
--  C project built with Meson into an SBOM that claimed `cargo` and `go`
--  (their names appear only in the build tree's recorded environment).
--  So a generated tree never contributes a tool reference.
--
--  A tree is recognised in two ways. Its conventional name (build,
--  builddir, target, dist, out, coverage) is the common case. Any other
--  name is caught by the build-system state it holds: Ninja's build.ninja,
--  Meson's meson-info, or CMake's CMakeCache.txt and
--  compile_commands.json. A directory that holds one of those was written
--  by a build system, so every file under it is generated.
--
--  The remaining entries are the source-walk skips plus the scan's own
--  exclusions: test suites, tool configuration, and Alire's dependency
--  cache are not tool invocations either.
--  @param Path  Full path of the directory, used for the state probe.
--  @param N  Directory base name.
--  @return True when the tool scan must not descend into the directory.
function Skip_Scan_Dir (Path : String; N : String) return Boolean is

   --  Whether the directory holds a build system's generated state.
   --  @param Dir  Full path of the directory.
   --  @return True when a known build-system state file or directory
   --    exists inside Dir.
   function Has_Build_State (Dir : String) return Boolean is
      use Ada.Directories;
   begin
      return
        Exists (Dir & "/CMakeCache.txt")
        or else Exists (Dir & "/compile_commands.json")
        or else Exists (Dir & "/build.ninja")
        or else Exists (Dir & "/meson-info");
   end Has_Build_State;

begin
   if Skip_Walk_Dir (N)
     or else N = ".jj"
     or else N = "tests"
     or else N = "config"
     or else N = "gnatprove"
     or else N = "__pycache__"
     or else N = "node_modules"
     or else N = ".headroom"
     or else N = ".lccst"
   then
      return True;
   end if;

   if N = "build"
     or else N = "builddir"
     or else N = "target"
     or else N = "dist"
     or else N = "out"
     or else N = "coverage"
   then
      return True;
   end if;

   return Has_Build_State (Path);
end Skip_Scan_Dir;
