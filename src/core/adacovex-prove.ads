with Adacovex.Types;

--  GNATprove runner for the `adacovex prove` subcommand.
--  Resolves a gnatprove executable (PATH, then ~/.adacovex/toolchain/bin,
--  then a platform toolchain download), runs it against a target project's
--  root .gpr file, and leaves a fresh obj/gnatprove/gnatprove.out for the
--  standard assessment pipeline to parse.  No alire.toml is required in the
--  target project: gnatprove is found from the toolchain, not the project.
--  HLR-PROVE: GNATprove subcommand

package Adacovex.Prove is

   --  Resolve the gnatprove executable to use for `prove` runs.
   --  Priority: PATH, then ~/.adacovex/toolchain/bin/gnatprove, then the
   --  ADACOVEX_TOOLCHAIN_URL download (or the default GitHub release asset)
   --  unpacked into ~/.adacovex/toolchain/.  On success Exe_Path holds the
   --  absolute path of the gnatprove binary and Toolchain_Dir is the bin
   --  directory that must be prepended to PATH for the child process.
   --  @param Exe_Path  Output buffer for the gnatprove executable path.
   --  @param Exe_Len  Length of the resolved executable path.
   --  @param Toolchain_Dir  Output buffer for the toolchain bin directory.
   --  @param Dir_Len  Length of the toolchain bin directory path.
   --  @param Success  True if a usable gnatprove was found.
   procedure Resolve_GNATprove
     (Exe_Path      : out String;
      Exe_Len       : out Natural;
      Toolchain_Dir : out String;
      Dir_Len       : out Natural;
      Success       : out Boolean);

   --  Locate the root GNAT project file for a target directory.
   --  Searches the target root for a single *.gpr file (the build project).
   --  If no .gpr is found, Success is False.
   --  @param Target_Dir  Project root directory.
   --  @param GPR_Path  Output buffer for the .gpr path.
   --  @param GPR_Len  Length of the resolved .gpr path.
   --  @param Success  True if a root .gpr file was found.
   procedure Find_Root_GPR
     (Target_Dir : String;
      GPR_Path   : out String;
      GPR_Len    : out Natural;
      Success    : out Boolean);

   --  Run gnatprove against a target project's root .gpr file.
   --  Prepends the resolved toolchain bin directory to PATH for the child,
   --  then spawns `gnatprove -P <gpr>`.  On success a fresh
   --  <target>/obj/gnatprove/gnatprove.out is written by gnatprove.  The
   --  command's stdout/stderr stream to the parent's terminal.
   --  @param Target_Dir  Project root directory.
   --  @param Success  True if gnatprove ran and exited 0.
   procedure Run_Prove (Target_Dir : String; Success : out Boolean);

end Adacovex.Prove;
