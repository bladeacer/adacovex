with Adacovex.Types;

--  GNATprove runner for the `adacovex prove` subcommand.
--  Resolves a gnatprove executable and runs it against a target project's
--  root .gpr file, leaving a fresh obj/gnatprove/gnatprove.out for the
--  standard assessment pipeline to parse.
--
--  Resolution priority (lightweight: adacovex only requires `alr` on PATH):
--    1. If the target's alire.toml / alire-dev.toml declares gnatprove as a
--       dependency, invoke it via `alr exec` (alire manages the toolchain).
--    2. A gnatprove already on $PATH.
--    3. A cached gnatprove in ~/.adacovex/toolchain/bin.
--    4. Last resort: a platform toolchain download (curl; only used when
--       no alire-managed or on-PATH gnatprove is available).
--  HLR-PROVE: GNATprove subcommand

package Adacovex.Prove is

   --  Resolve how to run gnatprove for a target project.
   --  Priority: alire-managed (Via_Alr => True), then PATH, then
   --  ~/.adacovex/toolchain/bin, then a platform toolchain download.
   --  When Via_Alr is True, Exe_Path holds the `alr` executable and
   --  Run_Prove spawns `alr -C <target> exec -- gnatprove -P <gpr>`.
   --  Otherwise Exe_Path holds the gnatprove binary and Toolchain_Dir is
   --  the bin directory to prepend to PATH (empty when already on PATH).
   --  @param Target_Dir  Project root directory.
   --  @param Exe_Path  Output buffer for the executable path.
   --  @param Exe_Len  Length of the resolved executable path.
   --  @param Toolchain_Dir  Output buffer for the toolchain bin directory.
   --  @param Dir_Len  Length of the toolchain bin directory path.
   --  @param Via_Alr  True if gnatprove must run through `alr exec`.
   --  @param Success  True if a usable gnatprove was found.
   procedure Resolve_GNATprove
     (Target_Dir    : String;
      Exe_Path      : out String;
      Exe_Len       : out Natural;
      Toolchain_Dir : out String;
      Dir_Len       : out Natural;
      Via_Alr       : out Boolean;
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
   --  Resolves gnatprove (see Resolve_GNATprove), then spawns
   --  `alr -C <target> exec -- gnatprove -P <gpr>` when alire-managed, or
   --  `gnatprove -P <gpr>` directly otherwise (prepending the toolchain bin
   --  directory to PATH for the child).  On success a fresh
   --  <target>/obj/gnatprove/gnatprove.out is written by gnatprove.  The
   --  command's stdout/stderr stream to the parent's terminal.
   --  @param Target_Dir  Project root directory.
   --  @param Success  True if gnatprove ran and exited 0.
   procedure Run_Prove (Target_Dir : String; Success : out Boolean);

end Adacovex.Prove;
