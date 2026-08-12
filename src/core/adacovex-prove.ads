with Adacovex.Types;

--  GNATprove runner for the `adacovex prove` subcommand.
--  Resolves a gnatprove executable and runs it against a target project's
--  root .gpr file, leaving a fresh obj/gnatprove/gnatprove.out for the
--  standard assessment pipeline to parse.
--
--  Resolution priority (lightweight: adacovex only requires `alr` on PATH):
--    1. If the target's alire.toml / alire-dev.toml declares gnatprove as a
--       dependency, invoke it via `alr exec` (alire manages the toolchain).
--       When gnatprove lives only in alire-dev.toml (the common dev-manifest
--       layout), the dev manifest is temporarily swapped over alire.toml for
--       the proof run and restored afterwards -- the assessment and SBOM
--       pipeline always scans the publishing alire.toml.
--    2. A gnatprove already on $PATH.
--    3. A cached gnatprove in ~/.adacovex/toolchain/bin.
--    4. Last resort: a platform toolchain download (curl; only used when
--       no alire-managed or on-PATH gnatprove is available).
--  HLR-PROVE: GNATprove subcommand

package Adacovex.Prove is

   --  GNATprove invocation options forwarded to the gnatprove command line.
   --  An integer field of -1 means "not configured": --jobs auto-detects the
   --  host core count and the level/timeout/steps/memlimit options are not
   --  passed.  --jobs=0 forwards -j0 (all cores).  A sane default of
   --  auto-detected parallelism means CI and the local make targets use every
   --  core without any flag, while users can pin --jobs=12 (or -j12).
    type Prove_Options is record
       Jobs              : Integer := -1;
       Level             : Integer := -1;
       Timeout           : Integer := -1;
       Steps             : Integer := -1;
       Memlimit          : Integer := -1;
       Force             : Boolean := False;
       No_Loop_Unrolling : Boolean := False;
       No_Inlining       : Boolean := False;
       Cache             : Boolean := True;
    end record;

   --  Detect the number of logical CPUs on the host.  Reads /proc/cpuinfo
   --  (Linux); falls back to 1 elsewhere or when the file is unreadable.
   --  @return Number of logical processors (>= 1).
   function Detect_Core_Count return Natural;

   --  Build the gnatprove option arguments as a space-separated string
   --  (excluding the -P <project> pair).  Always includes `-j <jobs>`:
   --  pass the resolved job count (Opts.Jobs when >= 0, else a detected
   --  core count).  Level/timeout/steps/memlimit are included only when
   --  configured; --force, --no-loop-unrolling and --no-inlining map to the
   --  corresponding gnatprove switches.
   --  @param Opts  GNATprove options.
   --  @param Jobs  Resolved job count to forward (-j value).
   --  @return Space-separated gnatprove option string.
   function Build_Option_String
     (Opts : Prove_Options; Jobs : Natural) return String;

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
   --  `alr -C <target> exec -- gnatprove -P <gpr> <options>` when
   --  alire-managed, or `gnatprove -P <gpr> <options>` directly otherwise
   --  (prepending the toolchain bin directory to PATH for the child).  The
   --  options (jobs, level, timeout, steps, memlimit, force, unrolling,
   --  inlining) are forwarded to gnatprove.  On success a fresh
   --  <target>/obj/gnatprove/gnatprove.out is written by gnatprove.  The
   --  command's stdout/stderr stream to the parent's terminal.
   --  @param Target_Dir  Project root directory.
   --  @param Opts  GNATprove invocation options.
   --  @param Success  True if gnatprove ran and exited 0.
   procedure Run_Prove
     (Target_Dir : String; Opts : Prove_Options; Success : out Boolean);

end Adacovex.Prove;
