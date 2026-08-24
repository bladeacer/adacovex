with Adacovex.Types;
with Ada.Strings.Unbounded;

--  GNATprove runner for the `adacovex prove` subcommand.
--  It resolves a gnatprove executable.  It runs it against a target
--  project's root .gpr file.  It leaves a fresh obj/gnatprove/gnatprove.out
--  for the standard assessment pipeline to parse.
--
--  Resolution priority (lightweight: adacovex only requires `alr` on PATH):
--    1. If the target's alire.toml or alire-dev.toml declares gnatprove as
--       a dependency, deploy only the gnatprove binary crate.  This crate is
--       a self-contained bundle with no dependencies.  Deploy it into
--       ~/.adacovex/toolchain via `alr -n get gnatprove=<version>`, then run
--       it directly.  This avoids the fragile `alr exec` path.  That path
--       used to compose the target's entire dev-manifest dependency set
--       (covex, gnatdoc_bin, gnatformat_bin, and more).  Flaky third-party
--       downloads in CI cannot fail a proof run.  No dev-manifest swap is
--       ever needed.  The manifest can declare the version as a rich set
--       expression (`^15.1.0`, `~15.1.0`, and more).  The leading operator is
--       stripped to yield the bare version that alr accepts.  A
--       manifest-declared prover is authoritative.  When it cannot be
--       deployed, the run fails instead of falling back.  A different
--       gnatprove version can change which VCs are discharged.  Results must
--       always come from the pinned prover.  Priorities 2 to 5 apply only to
--       projects whose manifest does not declare gnatprove.
--    2. A gnatprove version pinned globally.  The pin comes from the
--       ADACOVEX_GNATPROVE_VERSION environment variable or the
--       `[prove] gnatprove-version = "16.1.0"` key in
--       ~/.adacovex/adacovex.toml.  Run_Prove reads it and passes it in as
--       Pinned_Version.  The exact version is deployed via
--       `alr -n get gnatprove=<version>` and run directly.  Like the manifest
--       pin, it is authoritative.  A failure to deploy is a failure to run.
--       It is folded into the proof result-cache identity.  A different pinned
--       version can never reuse a stale proof.
--    3. A gnatprove already on $PATH.
--    4. A cached gnatprove in ~/.adacovex/toolchain/bin (download layout) or a
--       previously `alr get`-deployed gnatprove_*/ crate under the same dir.
--    5. Last resort: a platform toolchain download.  It uses curl.  It is
--       used only when no deployable, on-PATH, or cached gnatprove is
--       available.
--  So the order is: manifest pin > global pin (config/env) > PATH > cache >
--  download.
--  HLR-PROVE: GNATprove subcommand

package Adacovex.Prove is

   --  GNATprove invocation options forwarded to the gnatprove command line.
   --  An integer field of -1 means "not configured".  Then --jobs
   --  auto-detects the host core count.  The level, timeout, steps, and
   --  memlimit options are not passed.  --jobs=0 forwards -j0 (all cores).
   --  The default is auto-detected parallelism.  CI and the local make
   --  targets use every core without any flag.  Users can pin --jobs=12
   --  (or -j12).
   type Prove_Options is record
      Jobs        : Integer := -1;
      Level       : Integer := -1;
      Timeout     : Integer := -1;
      Steps       : Integer := -1;
      Memlimit    : Integer := -1;
      Force       : Boolean := False;
      No_Inlining : Boolean := False;

      --  True when gnatprove's benign informational messages are hidden from
      --  stdout.  It is quiet by default for local runs.  It is always off
      --  under --verbose.  CI passes --verbose, so the CI output stays
      --  authoritative.
      Suppress_Warnings : Boolean := True;

      --  Comma-separated suppression-set names for --suppress-warnings=SETS.
      --  Empty (the default, also --quiet) means the default set
      --  (unrolling-inlining).  A set name S suppresses gnatprove info tags
      --  `[info-S]` or `[S]`.  See Replay_Suppressed.  It is consulted only
      --  when Suppress_Warnings is True.
      Suppress_Sets : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.Null_Unbounded_String;

      Cache : Boolean := True;
   end record;

   --  Detect the number of logical CPUs on the host.  It reads /proc/cpuinfo
   --  (Linux).  It falls back to 1 elsewhere or when the file is unreadable.
   --  @return Number of logical processors (>= 1).
   function Detect_Core_Count return Natural;

   --  Build the gnatprove option arguments as a space-separated string.
   --  Exclude the -P <project> pair.  Always include `-j <jobs>` and
   --  `--no-loop-unrolling`.  Pass the resolved job count
   --  (Opts.Jobs when >= 0, else a detected core count).  Loop unrolling is
   --  always disabled.  GNATprove then never emits the purely-informational
   --  "cannot unroll loop (too many loop iterations) [info-unrolling-inlining]"
   --  notice.  This is proof-neutral for the dogfood targets.  Those targets
   --  are 720/720 adacovex and 589/589 Ada_CRDT VCs with 0 unproved either
   --  way.  Level, timeout, steps, and memlimit are included only when
   --  configured.  --force and --no-inlining map to the corresponding gnatprove
   --  switches.
   --  @param Opts  GNATprove options.
   --  @param Jobs  Resolved job count to forward (-j value).
   --  @return Space-separated gnatprove option string.
   function Build_Option_String
     (Opts : Prove_Options; Jobs : Natural) return String;

   --  Resolve how to run gnatprove for a target project.
   --  The priority is manifest-declared deployment via `alr get`.  Then the
   --  global version pin follows (see Pinned_Version in the package comment).
   --  Then PATH, then ~/.adacovex/toolchain/bin, then a platform toolchain
   --  download.
   --  Pinned_Version applies only when the manifest does not declare
   --  gnatprove.  The manifest pin is authoritative and always wins.  When
   --  Pinned_Version is not empty, the exact gnatprove version is deployed via
   --  `alr -n get gnatprove=<version>` and run directly.  A failure to deploy
   --  is a failure to run.  It is never a silent fallback to a different
   --  prover.  This is how mission-critical CI fixes the proof toolchain
   --  across projects that do not pin one themselves.
   --  Exe_Path always holds a directly-executable gnatprove binary.  It is
   --  never the `alr` wrapper.  The deployment path runs the deployed binary
   --  itself.  Toolchain_Dir is the bin directory to prepend to PATH for the
   --  child.  It is empty when the binary is already on PATH.  Identity is a
   --  short fingerprint of the resolved prover.  For the deploy path it is the
   --  pinned version.  Otherwise it is the executable or toolchain path.
   --  Run_Prove folds Identity into the result-cache key.  Proofs from
   --  different gnatprove deployments are then never mixed.
   --  @param Target_Dir  Project root directory.
   --  @param Pinned_Version  Global gnatprove version pin ("" = none.  The
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
   --  It searches the target root for a single *.gpr file (the build project).
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
   --  It resolves gnatprove (see Resolve_GNATprove).  It then spawns
   --  `gnatprove -P <gpr> <options>` directly.  When the deployment was not
   --  already on PATH, it prepends the toolchain bin directory to PATH for the
   --  child.  The options (jobs, level, timeout, steps, memlimit, force,
   --  unrolling, inlining) are forwarded to gnatprove.  On success, gnatprove
   --  writes a fresh <target>/obj/gnatprove/gnatprove.out.  The command's
   --  stdout and stderr stream to the parent's terminal.
   --  @param Target_Dir  Project root directory.
   --  @param Opts  GNATprove invocation options.
   --  @param Success  True if gnatprove ran and exited 0.
   procedure Run_Prove
     (Target_Dir : String; Opts : Prove_Options; Success : out Boolean);

   --  Print a non-mutating toolchain and platform report for the `adacovex
   --  status` subcommand.  It checks, in order, whether:
   --    * Alire (`alr`) is installed on $PATH.
   --    * the target manifest declares gnatprove (dependency-managed), a
   --      global pin is set, or a gnatprove is already on $PATH or cached in
   --      ~/.adacovex/toolchain.
   --    * the host logical-CPU count and CI status drive GNATprove
   --      parallelism.
   --  Unlike Resolve_GNATprove and Run_Prove, it never deploys or downloads
   --  anything.  Success is True when a usable gnatprove is detectable
   --  without a download and alr is present whenever the deploy path is the
   --  only option.  It also prints the release note.  The CI release binary is
   --  Linux x86-64 only for now.
   --  @param Target_Dir  Project root directory.
   --  @param Success  True when alr and gnatprove are available or
   --  dependency-managed.
   procedure Run_Status (Target_Dir : String; Success : out Boolean);

   --  Write the `adacovex status` report as machine-readable JSON for the
   --  `status --export[=PATH]` mode.  The JSON holds the version, the target,
   --  alire and gnatprove detectability (manifest or global pin, PATH,
   --  toolchain cache), the platform (logical CPUs, CI, default -j), the VCS
   --  tool report, and the overall OK verdict.  Like Run_Status, it never
   --  deploys or downloads anything.  When Out_Path is empty, the JSON prints
   --  to stdout.  Otherwise it is written to Out_Path, which is created or
   --  overwritten.
   --  @param Target_Dir  Project root directory.
   --  @param Out_Path  Output file path, or "" for stdout.
   --  @param Success  True when the report was gathered and written.
   procedure Export_Status
     (Target_Dir : String; Out_Path : String; Success : out Boolean);

   --  Print the `adacovex status --metrics` report.  It shows the same data
   --  as Run_Status.  It uses compact key=value lines (one per line, keys
   --  lowercase with - separators).  Shell scripts and CI can then consume the
   --  report without parsing prose.  It never deploys or downloads anything.
   --  @param Target_Dir  Project root directory.
   --  @param Success  True when alr and gnatprove are available or
   --  dependency-managed (same meaning as Run_Status).
   procedure Run_Status_Metrics (Target_Dir : String; Success : out Boolean);

end Adacovex.Prove;
