--  Host CPU / parallelism helpers for adacovex.
--  It detects the number of logical CPUs. It supports the platforms that
--  Alire supports: Linux, macOS, FreeBSD, and Windows. It uses only the
--  GNAT runtime, so the crate keeps no dependencies. It also resolves the
--  default GNATprove job count. On a developer machine it leaves two cores
--  free for system responsiveness. Inside CI it uses every core.
--  HLR-CPU: Cross-platform CPU core detection

with GNAT.OS_Lib;

package Adacovex.CPUs is

   --  Number of logical processors on the host, or 1 when it cannot be
   --  determined. Detection order (pure GNAT runtime only):
   --    * Linux:            count "processor" entries in /proc/cpuinfo
   --    * macOS / FreeBSD:  `sysctl -n hw.ncpu`
   --    * Linux fallback:   `nproc`
   --    * Windows:          NUMBER_OF_PROCESSORS env var, then
   --                        `powershell Get-CimInstance ... NumberOfLogicalProcessors`
   --  Any failure at a stage moves to the next stage. If every stage fails,
   --  the result is 1.
   --  @return Logical CPU count (>= 1).
   function Detect_Core_Count return Natural;

   --  True when adacovex is running in a known CI environment. It detects the
   --  markers set by GitHub Actions, GitLab CI, Azure Pipelines, Buildkite,
   --  CircleCI, Travis CI, and generic CI runners (the `CI` variable).
   --  @return True when running inside CI.
   function Is_Running_In_CI return Boolean;

   --  Resolve the GNATprove parallelism to use for one run.
   --  * Configured < 0  -> auto default (see Default_Prove_Jobs)
   --  * Configured = 0  -> all cores (gnatprove -j0)
   --  * Configured > 0  -> that many jobs
   --  @param Configured  The --jobs integer from the CLI (-1 = auto).
   --  @param In_CI  Whether the run is inside CI.
   --  @return Resolved job count (>= 1).
   function Resolve_Jobs
     (Configured : Integer; In_CI : Boolean) return Natural;

   --  Portable system temp directory. It checks TMPDIR, TEMP, TMP (in that
   --  order) and falls back to "/tmp". It reads Ada.Environment_Variables.
   --  SPARK_Mode On: gnatprove 16 analyses the runtime env-var readers with
   --  `[assumed-global-null]` warnings (the runtime has no Global
   --  contracts), so the function stays fully in the SPARK subset. The six
   --  warnings are recorded in docs/proof/16.1.0-ledger.md. The remaining
   --  SPARK_Mode Off exceptions are the non-formal Ada.Containers
   --  instantiations (adacovex-types and adacovex-complexity), which
   --  gnatprove rejects in SPARK_Mode On code; see
   --  docs/proof/16.1.0-ledger.md.
   function Get_Temp_Directory return String
   with SPARK_Mode => On, Global => null;

   --  Default shell executable for spawned commands. It is a pure function
   --  of the host platform: "cmd" on Windows and "sh" elsewhere. Windows
   --  ships no POSIX shell, so a command line must run through cmd.exe
   --  there; every shell-adapted caller pairs it with Get_Shell_Option.
   function Get_Shell_Command return String
   with SPARK_Mode => On, Global => (Input => GNAT.OS_Lib.Directory_Separator);

   --  The flag that passes a command line to that shell: "-c" for sh and
   --  "/c" for cmd.exe. It is a pure function of the host platform.
   function Get_Shell_Option return String
   with SPARK_Mode => On, Global => (Input => GNAT.OS_Lib.Directory_Separator);

   --  Where a shell sends discarded output: "/dev/null" on POSIX hosts and
   --  "NUL" on Windows. It is a pure function of the host platform.
   function Get_Null_Device return String
   with SPARK_Mode => On, Global => (Input => GNAT.OS_Lib.Directory_Separator);

   --  Whether the host is Windows. The path separator is the one
   --  compile-time fact that identifies the platform, so no environment
   --  read is needed and the answer cannot disagree with Executable_Suffix.
   --  GNAT.OS_Lib carries no Global contracts (the runtime is not analysed
   --  by gnatprove), so the same scoped warning pragma the env-var readers
   --  use covers this constant read. The pragma only silences the missing
   --  contract notice: the constant is a value, not a write, so the flow
   --  analysis has no data dependency to prove.
   function Is_Windows return Boolean
   with SPARK_Mode => On, Global => (Input => GNAT.OS_Lib.Directory_Separator);

   --  The auto default. In CI it uses all cores. Otherwise it uses
   --  max(1, cores - 2) so the developer machine stays responsive. Pass the
   --  already-detected core count. Callers can then print the basis for the
   --  choice.
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

   --  Sensible default task-pool size for the --serve dashboard. It scales
   --  with the host's logical CPU count and stays within 2 .. 8, so a small
   --  machine does not over-subscribe and a large one does not spawn an
   --  excessive pool. Used when --serve is given without an explicit
   --  --serve-workers / --workers value.
   --  @param Cores  Detected logical CPU count.
   --  @return Worker count in 2 .. 8.
   function Default_Serve_Workers (Cores : Natural) return Positive
   with
     SPARK_Mode => On,
     Post       => Default_Serve_Workers'Result in 2 .. 8,
     Global     => null;

   --  A human-readable justification for the resolved job count, suitable for
   --  the verbose pipeline log. Examples:
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
   --  It uses GNAT.OS_Lib to redirect to a temp file. The temp file is
   --  removed afterwards. Ok is False when the spawn fails or produces no
   --  output.
   procedure Run_Capture
     (Cmd      : String;
      Out_Line : out String;
      Out_Len  : out Natural;
      Ok       : out Boolean);

end Adacovex.CPUs;
