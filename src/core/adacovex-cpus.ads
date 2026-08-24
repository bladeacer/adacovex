--  Host CPU / parallelism helpers for adacovex.
--  Detects the number of logical CPUs across the platforms Alire supports
--  (Linux, macOS, FreeBSD, and Windows) using only the GNAT runtime, so the
--  crate stays zero-dependency.  Also resolves the default GNATprove job
--  count: leave two cores free for system responsiveness on a developer
--  machine, but use every core inside CI.
--  HLR-CPU: Cross-platform CPU core detection

package Adacovex.CPUs is

   --  Number of logical processors on the host, or 1 when it cannot be
   --  determined.  Detection order (pure GNAT runtime only):
   --    * Linux:            count "processor" entries in /proc/cpuinfo
   --    * macOS / FreeBSD:  `sysctl -n hw.ncpu`
   --    * Linux fallback:   `nproc`
   --    * Windows:          NUMBER_OF_PROCESSORS env var, then
   --                        `powershell Get-CimInstance ... NumberOfLogicalProcessors`
   --  Any failure at a stage falls through to the next; exhausts to 1.
   --  @return Logical CPU count (>= 1).
   function Detect_Core_Count return Natural;

   --  True when adacovex is running under a known CI environment.  Detects the
   --  markers set by GitHub Actions, GitLab CI, Azure Pipelines, Buildkite,
   --  CircleCI, Travis CI, and generic CI runners (the `CI` variable).
   --  @return True when running inside CI.
   function Is_Running_In_CI return Boolean;

   --  Resolve the GNATprove parallelism to use for a run.
   --  * Configured < 0  -> auto default (see Default_Prove_Jobs)
   --  * Configured = 0  -> all cores (gnatprove -j0)
   --  * Configured > 0  -> that many jobs
   --  @param Configured  The --jobs integer from the CLI (-1 = auto).
   --  @param In_CI  Whether the run is inside CI.
   --  @return Resolved job count (>= 1).
   function Resolve_Jobs
     (Configured : Integer; In_CI : Boolean) return Natural;

   --  Portable system temp directory.  Checks TMPDIR, TEMP, TMP (in that
   --  order) and falls back to "/tmp".  Reads Ada.Environment_Variables,
   --  which is outside the SPARK subset, so this stays SPARK_Mode Off.
   function Get_Temp_Directory return String
   with SPARK_Mode => Off;

   --  Default shell executable for spawned commands.  Pure: returns the
   --  constant "sh", so it is SPARK_Mode On with no global state.
   function Get_Shell_Command return String
   with SPARK_Mode => On, Global => null;

   --  The auto default: all cores in CI, otherwise max(1, cores - 2) to keep
   --  the developer machine responsive.  Pass the already-detected core count
   --  so callers can print the basis for the choice.
   --  @param Cores  Detected logical CPU count.
   --  @param In_CI  Whether the run is inside CI.
   --  @return Default job count.
   function Default_Prove_Jobs
     (Cores : Natural; In_CI : Boolean) return Natural
   with
     SPARK_Mode => On,
     Post       =>
       (if In_CI
        then Default_Prove_Jobs'Result = Cores
        else Default_Prove_Jobs'Result = Natural'Max (1, Cores - 2)),
     Global     => null;

   --  A human-readable justification for the resolved job count, suitable for
   --  the verbose pipeline log.  Examples:
   --    "auto default (CI): using all 8 cores"
   --    "auto default: 8 - 2 = 6 jobs (reserved 2 cores for system)"
   --    "explicit --jobs=4"
   --    "auto default (all cores): -j0"
   --  @param Configured  The --jobs integer from the CLI.
   --  @param Cores  Detected logical CPU count.
   --  @param In_CI  Whether the run is inside CI.
   --  @return Justification string (no trailing newline).
   function Jobs_Justification
     (Configured : Integer; Cores : Natural; In_CI : Boolean) return String
   with SPARK_Mode => On, Global => null;

private

   --  Run a shell command and capture its first stdout line into Out_Line.
   --  Uses GNAT.OS_Lib to redirect to a temp file; the temp file is removed
   --  afterwards.  Ok is False when the spawn fails or produces no output.
   procedure Run_Capture
     (Cmd      : String;
      Out_Line : out String;
      Out_Len  : out Natural;
      Ok       : out Boolean);

end Adacovex.CPUs;
