# Adacovex.CPUs

Host CPU / parallelism helpers for adacovex.
It detects the number of logical CPUs. It supports the platforms that
Alire supports: Linux, macOS, FreeBSD, and Windows. It uses only the
GNAT runtime, so the crate keeps no dependencies. It also resolves the
default GNATprove job count. On a developer machine it leaves two cores
free for system responsiveness. Inside CI it uses every core.
HLR-CPU: Cross-platform CPU core detection

**See also:** [Platforms](../usage/platforms.md)

> **Note:** 12 public item(s) shown below; 1 private internal item(s) are in the `private` section.

## Functions

### function Default_Prove_Jobs (Cores : Standard.Natural; In_CI : Standard.Boolean) return Standard.Natural `[Post]` `[Global]` `[SPARK]`

> The auto default. In CI it uses all cores. Otherwise it uses max(1, cores - 2) so the developer machine stays responsive. Pass the already-detected core count. Callers can then print the basis for the choice.

| Parameter | Description |
|-----------|-------------|
| `Cores` | Detected logical CPU count. |
| `In_CI` | Whether the run is inside CI. |

**Returns:** Default job count.

### function Default_Serve_Workers (Cores : Standard.Natural) return Standard.Positive `[Post]` `[Global]` `[SPARK]`

> Sensible default task-pool size for the --serve dashboard. It scales with the host's logical CPU count and stays within 2 .. 8, so a small machine does not over-subscribe and a large one does not spawn an excessive pool. Used when --serve is given without an explicit --serve-workers / --workers value.

| Parameter | Description |
|-----------|-------------|
| `Cores` | Detected logical CPU count. |

**Returns:** Worker count in 2 .. 8.

### function Detect_Core_Count return Standard.Natural

> Number of logical processors on the host, or 1 when it cannot be determined. Detection order (pure GNAT runtime only): * Linux:            count "processor" entries in /proc/cpuinfo * macOS / FreeBSD:  `sysctl -n hw.ncpu` * Linux fallback:   `nproc` * Windows:          NUMBER_OF_PROCESSORS env var, then `powershell Get-CimInstance ... NumberOfLogicalProcessors` Any failure at a stage moves to the next stage. If every stage fails, the result is 1.

**Returns:** Logical CPU count (>= 1).

### function Get_Null_Device return Standard.String

> Where a shell sends discarded output: "/dev/null" on POSIX hosts and "NUL" on Windows. It is a pure function of the host platform.

### function Get_Shell_Command return Standard.String

> Default shell executable for spawned commands. It is a pure function of the host platform: "cmd" on Windows and "sh" elsewhere. Windows ships no POSIX shell, so a command line must run through cmd.exe there; every shell-adapted caller pairs it with Get_Shell_Option.

### function Get_Shell_Option return Standard.String

> The flag that passes a command line to that shell: "-c" for sh and "/c" for cmd.exe. It is a pure function of the host platform.

### function Get_Temp_Directory return Standard.String `[Global]` `[SPARK]`

> Portable system temp directory. It checks TMPDIR, TEMP, TMP (in that order) and falls back to "/tmp". It reads Ada.Environment_Variables. SPARK_Mode On: gnatprove 16 analyses the runtime env-var readers with `[assumed-global-null]` warnings (the runtime has no Global contracts), so the function stays fully in the SPARK subset. The six warnings are recorded in docs/proof/16.1.0-ledger.md. The remaining SPARK_Mode Off exceptions are the non-formal Ada.Containers instantiations (adacovex-types and adacovex-complexity), which gnatprove rejects in SPARK_Mode On code; see docs/proof/16.1.0-ledger.md.

### function Is_Running_In_CI return Standard.Boolean

> True when adacovex is running in a known CI environment. It detects the markers set by GitHub Actions, GitLab CI, Azure Pipelines, Buildkite, CircleCI, Travis CI, and generic CI runners (the `CI` variable).

**Returns:** True when running inside CI.

### function Is_Windows return Standard.Boolean

> Whether the host is Windows. The path separator is the one compile-time fact that identifies the platform, so no environment read is needed and the answer cannot disagree with Executable_Suffix. GNAT.OS_Lib carries no Global contracts (the runtime is not analysed by gnatprove), so the same scoped warning pragma the env-var readers use covers this constant read. The pragma only silences the missing contract notice: the constant is a value, not a write, so the flow analysis has no data dependency to prove.

### function Jobs_Justification (Configured : Standard.Integer; Cores : Standard.Natural; In_CI : Standard.Boolean) return Standard.String `[Global]` `[SPARK]`

> A human-readable justification for the resolved job count, suitable for the verbose pipeline log. Examples: "auto default (CI): using all 8 cores" "auto default: 8 - 2 = 6 jobs (reserved 2 cores for system)" "explicit --jobs=4" "auto default (all cores): -j0"

| Parameter | Description |
|-----------|-------------|
| `Configured` | The --jobs integer from the CLI. |
| `Cores` | Detected logical CPU count. |
| `In_CI` | Whether the run is inside CI. |

**Returns:** Justification string (no trailing newline).

### function Resolve_Jobs (Configured : Standard.Integer; In_CI : Standard.Boolean) return Standard.Natural

> Resolve the GNATprove parallelism to use for one run. * Configured < 0  -> auto default (see Default_Prove_Jobs) * Configured = 0  -> all cores (gnatprove -j0) * Configured > 0  -> that many jobs

| Parameter | Description |
|-----------|-------------|
| `Configured` | The --jobs integer from the CLI (-1 = auto). |
| `In_CI` | Whether the run is inside CI. |

**Returns:** Resolved job count (>= 1).

## Procedures

### procedure Run_Capture (Cmd : Standard.String; Out_Line : Standard.String; Out_Len : Standard.Natural; Ok : Standard.Boolean)

> Run a shell command and capture its first stdout line into Out_Line. It uses GNAT.OS_Lib to redirect to a temp file. The temp file is removed afterwards. Ok is False when the spawn fails or produces no output.

| Parameter | Description |
|-----------|-------------|
| `Cmd` | Command line to spawn. |
| `Ok` | True when the spawn succeeded and produced output. |
| `Out_Len` | Length of the captured line. |
| `Out_Line` | Output buffer for the first stdout line. |

---

## Private Section

- **procedure** `Run_Capture`
