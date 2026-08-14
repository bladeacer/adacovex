with Adacovex.Types;

--  GNATprove runner for the `adacovex prove` subcommand.
--  Resolves a gnatprove executable and runs it against a target project's
--  root .gpr file, leaving a fresh obj/gnatprove/gnatprove.out for the
--  standard assessment pipeline to parse.
--
--  Resolution priority (lightweight: adacovex only requires `alr` on PATH):
--    1. If the target's alire.toml / alire-dev.toml declares gnatprove as a
--       dependency, deploy ONLY the gnatprove binary crate (a self-contained
--       bundle -- no dependencies) into ~/.adacovex/toolchain via
--       `alr -n get gnatprove=<version>`, then run it directly.  This avoids
--       the fragile `alr exec` path that used to compose the target's entire
--       dev-manifest dependency set (covex, gnatdoc_bin, gnatformat_bin, ...):
--       flaky third-party downloads in CI could not fail a proof run, and no
--       dev-manifest swap is ever needed.  The manifest may declare the version
--       as a rich set expression (`^15.1.0`, `~15.1.0`, ...); the leading
--       operator is stripped to yield the bare version alr accepts.  A
--       manifest-declared prover is authoritative: when it cannot be deployed
--       the run fails instead of falling back, because a different gnatprove
--       version can change which VCs are discharged (results must always come
--       from the pinned prover).  Priorities 2-5 apply only to projects whose
--       manifest does not declare gnatprove.
--    2. A gnatprove version pinned globally -- the ADACOVEX_GNATPROVE_VERSION
--       environment variable or the `[prove] gnatprove-version = "16.1.0"`
--       key in ~/.adacovex/adacovex.toml (read by Run_Prove and passed in as
--       Pinned_Version).  The exact version is deployed via
--       `alr -n get gnatprove=<version>` and run directly; like the manifest
--       pin it is authoritative (a failure to deploy is a failure to run) and
--       is folded into the proof result-cache identity so a different pinned
--       version can never reuse a stale proof.
--    3. A gnatprove already on $PATH.
--    4. A cached gnatprove in ~/.adacovex/toolchain/bin (download layout) or a
--       previously `alr get`-deployed gnatprove_*/ crate under the same dir.
--    5. Last resort: a platform toolchain download (curl; only used when
--       no deployable, on-PATH, or cached gnatprove is available).
--  So the order is: manifest pin > global pin (config/env) > PATH > cache >
--  download.
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
   --  Priority: manifest-declared deployment via `alr get`, then the global
   --  version pin (Pinned_Version -- see the package comment), then PATH, then
   --  ~/.adacovex/toolchain/bin, then a platform toolchain download.
   --  Pinned_Version applies only when the manifest does not declare
   --  gnatprove: the manifest pin is authoritative and always wins.  When
   --  non-empty, the exact gnatprove version is deployed via
   --  `alr -n get gnatprove=<version>` and run directly (authoritative -- a
   --  failure to deploy is a failure to run, never a silent fallback to a
   --  different prover), which is how mission-critical CI fixes the proof
   --  toolchain across projects that do not pin one themselves.
   --  Exe_Path always holds a directly-executable gnatprove binary (never the
   --  `alr` wrapper -- the deployment path runs the deployed binary itself),
   --  and Toolchain_Dir is the bin directory to prepend to PATH for the child
   --  (empty when already on PATH).  Identity is a short fingerprint of the
   --  resolved prover (pinned version for the deploy path, else the
   --  executable/toolchain path); Run_Prove folds it into the result-cache key
   --  so proofs from different gnatprove deployments are never mixed.
   --  @param Target_Dir  Project root directory.
   --  @param Pinned_Version  Global gnatprove version pin ("" = none; the
   --  manifest pin is still preferred when the target declares one).
   --  @param Exe_Path  Output buffer for the executable path.
   --  @param Exe_Len  Length of the resolved executable path.
   --  @param Toolchain_Dir  Output buffer for the toolchain bin directory.
   --  @param Dir_Len  Length of the toolchain bin directory path.
   --  @param Identity  Output buffer for the prover identity fingerprint.
   --  @param Ident_Len  Length of the identity fingerprint.
   --  @param Success  True if a usable gnatprove was found.
   procedure Resolve_GNATprove
     (Target_Dir     : String;
      Pinned_Version : String;
      Exe_Path       : out String;
      Exe_Len        : out Natural;
      Toolchain_Dir  : out String;
      Dir_Len        : out Natural;
      Identity       : out String;
      Ident_Len      : out Natural;
      Success        : out Boolean);

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
   --  `gnatprove -P <gpr> <options>` directly (prepending the toolchain bin
   --  directory to PATH for the child when the deployment was not already on
   --  PATH).  The options (jobs, level, timeout, steps, memlimit, force,
   --  unrolling, inlining) are forwarded to gnatprove.  On success a fresh
   --  <target>/obj/gnatprove/gnatprove.out is written by gnatprove.  The
   --  command's stdout/stderr stream to the parent's terminal.
   --  @param Target_Dir  Project root directory.
   --  @param Opts  GNATprove invocation options.
   --  @param Success  True if gnatprove ran and exited 0.
   procedure Run_Prove
     (Target_Dir : String; Opts : Prove_Options; Success : out Boolean);

end Adacovex.Prove;
