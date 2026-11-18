# Adacovex.Prove

GNATprove runner for the ``adacovex prove`` subcommand.
It resolves a gnatprove executable. It runs it against a target
project's root .gpr file. It leaves a fresh obj/gnatprove/gnatprove.out
for the standard assessment pipeline to parse.

Resolution priority (lightweight: adacovex only requires ``alr`` on PATH):

#. If the target's alire.toml or alire-dev.toml declares gnatprove as
a dependency, deploy only the gnatprove binary crate. This crate is
a self-contained bundle with no dependencies. Deploy it into
<data>/toolkit via ``alr -n get gnatprove=<version>``, then run
it directly. This avoids the fragile ``alr exec`` path. That path
used to compose the target's entire dev-manifest dependency set
(covex, gnatdoc_bin, gnatformat_bin, and more). Flaky third-party
downloads in CI cannot fail a proof run. No dev-manifest swap is
ever needed. The manifest can declare the version as a rich set
expression (``^16.1.0``, ``~16.1.0``, and more). The leading operator is
stripped to yield the bare version that alr accepts. A
manifest-declared prover is authoritative. When it cannot be
deployed, the run fails instead of falling back. A different
gnatprove version can change which VCs are discharged. Results must
always come from the pinned prover. Priorities 2 to 5 apply only to
projects whose manifest does not declare gnatprove. The first
deployment downloads a ~130 MB bundle through alr (one-time per
version; a progress line says so up front). Every later run reuses
the deployed crate under <data>/toolkit with no download, and
two projects pinning different versions keep both toolchains side
by side there.

#. A gnatprove version pinned globally. The pin comes from the
ADACOVEX_GNATPROVE_VERSION environment variable or the
``[prove] gnatprove-version = "16.1.0"`` key in
<config>/adacovex.toml. Run_Prove reads it and passes it in as
Pinned_Version. The exact version is deployed via
``alr -n get gnatprove=<version>`` and run directly. Like the manifest
pin, it is authoritative. A failure to deploy is a failure to run.
It is folded into the proof result-cache identity. A different pinned
version can never reuse a stale proof.

#. A gnatprove already on $PATH.

#. A cached gnatprove in <data>/toolkit/bin (download layout) or a
previously ``alr get``-deployed gnatprove_*/ crate under the same dir.

#. Last resort: a platform toolkit download. It uses curl. It is
used only when no deployable, on-PATH, or cached gnatprove is
available.

So the order is: manifest pin > global pin (config/env) > PATH > cache >
download.
HLR-PROVE: GNATprove subcommand

**See also:** [Architecture -- toolkit resolution](../contributing/architecture-dependencies.md#gnatprove-toolchain-resolution-prove-subcommand)

> **Note:** All items in this package are public.

## Types

### type Failure_Array

```ada
subtype Failure_Array is Adacovex.Prove_Output.Failure_Array;
```

> The fixed finding array one diagnostics pass fills.

### type Failure_Stats

```ada
subtype Failure_Stats is Adacovex.Prove_Output.Failure_Stats;
```

> Counts gathered by one diagnostics pass over a captured gnatprove output file.

### type Prove_Failure

```ada
subtype Prove_Failure is Adacovex.Prove_Output.Prove_Failure;
```

> The proof finding model, the pass that reads a captured stream, the rendered diagnostics block, and the annotation shape live in `Adacovex.Prove_Output`. They are re-exported here so the prove API stays one package for callers and tests.

### type Prove_Options

```ada
type Prove_Options is record
Jobs        : Integer := -1;
Level       : Integer := -1;
Timeout     : Integer := -1;
Steps       : Integer := -1;
Memlimit    : Integer := -1;
Force       : Boolean := False;
No_Inlining : Boolean := False;
Extra_Args : Ada.Strings.Unbounded.Unbounded_String :=
Ada.Strings.Unbounded.Null_Unbounded_String;
Suppress_Warnings : Boolean := True;
Suppress_Sets : Ada.Strings.Unbounded.Unbounded_String :=
Ada.Strings.Unbounded.Null_Unbounded_String;
Cache : Boolean := True;
Show_Coverage : Boolean := True;
Diagnostics_Json : Boolean := False;
end record;
```

> GNATprove invocation options forwarded to the gnatprove command line. An integer field of -1 means "not configured". Then --jobs auto-detects the host core count. The level, timeout, steps, and memlimit options are not passed. --jobs=0 forwards -j0 (all cores). The default is auto-detected parallelism. CI and the local make targets use every core without any flag. Users can pin --jobs=12 (or -j12).

### type Replay_Stats

```ada
type Replay_Stats is record
Hidden     : Natural := 0;
Progress   : Natural := 0;
Errors     : Natural := 0;
Warnings   : Natural := 0;
Duplicates : Natural := 0;
end record;
```

> Counts gathered by one quiet-mode replay pass over a captured gnatprove output file. They keep the actionable detail apart from the tool noise: Hidden is how many informational notice blocks the suppression sets removed, Progress is how many phase-progress lines the replay dropped (pure progress, meaningless once the run has finished), Errors and Warnings count the message lines that named a failure, and Duplicates is how many repeated diagnostic lines the replay folded into their first copy.

## Functions

### function Annotation_Line (Location : Standard.String; Kind : Standard.String) return Standard.String

> Build the GitHub Actions workflow command for one unproved finding.

| Parameter | Description |
|-----------|-------------|
| `Kind` | Check kind (for example "range check"). |
| `Location` | Source location as Collect_Failures recorded it. |

**Returns:** The workflow command, or "" when the location is malformed.

### function Build_Option_String (Opts : Adacovex.Prove.Prove_Options; Jobs : Standard.Natural) return Standard.String

> Build the gnatprove option arguments as a space-separated string. Exclude the -P <project> pair. Always include `-j <jobs>` and `--no-loop-unrolling`. Pass the resolved job count (Opts.Jobs when >= 0, else a detected core count). Loop unrolling is always disabled. GNATprove then never emits the purely-informational "cannot unroll loop (too many loop iterations) [info-unrolling-inlining]" notice. This is proof-neutral for the dogfood targets. Those targets are 720/720 adacovex and 589/589 Ada_CRDT VCs with 0 unproved either way. Level, timeout, steps, and memlimit are included only when configured. --force and --no-inlining map to the corresponding gnatprove switches. Any raw --args value in Opts.Extra_Args is appended verbatim (space-split) at the end.

| Parameter | Description |
|-----------|-------------|
| `Jobs` | Resolved job count to forward (-j value). |
| `Opts` | GNATprove options. |

**Returns:** Space-separated gnatprove option string.

### function Detect_Core_Count return Standard.Natural

> Detect the number of logical CPUs on the host. It reads /proc/cpuinfo (Linux). It falls back to 1 elsewhere or when the file is unreadable.

**Returns:** Number of logical processors (>= 1).

### function Diagnostics_Json (Prover : Standard.String; Stats : Adacovex.Prove.Failure_Stats; Source_Root : Standard.String) return Standard.String

> Render the same findings as one JSON object for `--diagnostics=json`.

| Parameter | Description |
|-----------|-------------|
| `Prover` | The resolved prover identity, or "". |
| `Source_Root` | Directory the finding locations are relative to. |
| `Stats` | Findings gathered by Collect_Failures. |

**Returns:** One JSON object, or "" when there is nothing to report.

### function Diagnostics_Text (Prover : Standard.String; Stats : Adacovex.Prove.Failure_Stats; Source_Root : Standard.String) return Standard.String

> Render the diagnostics block for a proof run that left unproved checks.

| Parameter | Description |
|-----------|-------------|
| `Prover` | The resolved prover identity (version or path), or "". |
| `Source_Root` | Directory the finding locations are relative to. |
| `Stats` | Findings gathered by Collect_Failures. |

**Returns:** The diagnostics block, or "" when there is nothing to report.

### function Is_Proof_Input (Name : Standard.String) return Standard.Boolean

> Whether an Ada source file participates in the proof-input hash. Every project source does, except the generated bundle specs (`adacovex-docs_template.ads` and `adacovex-dashboard_template.ads`). Both are multi-thousand-line string constants (base64 gzip chunks and inlined HTML/CSS/JS) with no subprogram and no check, so a docs or dashboard regeneration cannot change a proof result. Excluding them keeps a documentation edit from invalidating the cached proof. The match is exact and case-sensitive on the file base name.

| Parameter | Description |
|-----------|-------------|
| `Name` | File base name, with extension. |

**Returns:** True when the file is hashed into the proof-input digest.

## Procedures

### procedure Collect_Failures (Path : Standard.String; Stats : Adacovex.Prove.Failure_Stats; Summary_Path : Standard.String)

> Collect the actionable failure detail of a captured gnatprove stream. The rules (severity stripping, deduplication, the bounded seen table) are documented on `Adacovex.Prove_Output.Collect_Failures`.

| Parameter | Description |
|-----------|-------------|
| `Path` | Captured gnatprove output file to read. |
| `Stats` | Findings gathered during the pass. |
| `Summary_Path` | Gnatprove summary whose prover column attributes a prover set to each finding category ("" when unavailable). |

### procedure Export_Status (Target_Dir : Standard.String; Out_Path : Standard.String; TZ_Spec : Standard.String; Success : Standard.Boolean)

> Write the `adacovex status` report as machine-readable JSON for the `status --export[=PATH]` mode. The JSON holds the version, the target, alire and gnatprove detectability (manifest or global pin, PATH, toolkit cache), the platform (logical CPUs, CI, default -j), the VCS tool report, and the overall OK verdict. Like Run_Status, it never deploys or downloads anything. When Out_Path is empty, the JSON prints to stdout. Otherwise it is written to Out_Path, which is created or overwritten.

| Parameter | Description |
|-----------|-------------|
| `Out_Path` | Output file path, or "" for stdout. |
| `Success` | True when the report was gathered and written. |
| `TZ_Spec` | Display timezone override (--tz / --timezone), or "" for the operating system's timezone. |
| `Target_Dir` | Project root directory. |

### procedure Find_Root_GPR (Target_Dir : Standard.String; GPR_Path : Standard.String; GPR_Len : Standard.Natural; Success : Standard.Boolean)

> Locate the root GNAT project file for a target directory. It searches the target root for a single *.gpr file (the build project). If no .gpr is found, Success is False.

| Parameter | Description |
|-----------|-------------|
| `GPR_Len` | Length of the resolved .gpr path. |
| `GPR_Path` | Output buffer for the .gpr path. |
| `Success` | True if a root .gpr file was found. |
| `Target_Dir` | Project root directory. |

### procedure Replay_Suppressed (Path : Standard.String; Sets : Standard.String; Out_Path : Standard.String; Stats : Adacovex.Prove.Replay_Stats)

> Replay a captured gnatprove output file (its combined stdout and stderr) as one framed block, dropping the noise a finished run no longer needs and keeping every actionable line: * the informational blocks whose tags match Sets, together with their `-->` location, code excerpt, caret ruler, and `+` sub-message continuation lines; * the `Phase N of M:` progress lines, which only mean something while the run is still going; * a diagnostic line the replay already emitted -- the same file, line, column, severity, and message -- with its continuation lines, because the prover prints one warning per inlined call site; * the orphan blank lines those drops leave behind -- runs of blank lines collapse to one. Checks, errors, warnings, and the summary pass through untouched. The block is framed: one blank line opens it so it never runs into the caller's own status lines, and one blank line closes it. When notices or repeats were dropped, a footer states how many and that --verbose shows them, so a reader always learns that output was edited.

| Parameter | Description |
|-----------|-------------|
| `Out_Path` | Destination file. Empty replays to standard output. The directory of a named file must already exist. |
| `Path` | Captured gnatprove output file to replay. |
| `Sets` | Comma-separated suppression-set names. Empty selects the default set (`unrolling-inlining`). A set name S drops blocks tagged `[info-S]` or `[S]`. |
| `Stats` | Counts gathered during the pass. |

### procedure Report_Coverage (Target_Dir : Standard.String)

> Print the proof-coverage summary line (statement, subprogram, and VC coverage) for a target whose obj/gnatprove/ artefacts are readable. It is a summary, not a gate: a missing or unreadable artefact set prints nothing and never fails the caller. Used by `adacovex prove` and by a plain `adacovex` run when proof data is available.

| Parameter | Description |
|-----------|-------------|
| `Target_Dir` | Project root whose obj/gnatprove artefacts are read. |

### procedure Resolve_GNATprove (Target_Dir : Standard.String; Pinned_Version : Standard.String; Exe_Path : Standard.String; Exe_Len : Standard.Natural; Toolkit_Dir : Standard.String; Dir_Len : Standard.Natural; Identity : Standard.String; Ident_Len : Standard.Natural; Success : Standard.Boolean)

> Resolve how to run gnatprove for a target project. The priority is manifest-declared deployment via `alr get`. Then the global version pin follows (see Pinned_Version in the package comment). Then PATH, then <data>/toolkit/bin, then a platform toolkit download. Pinned_Version applies only when the manifest does not declare gnatprove. The manifest pin is authoritative and always wins. When Pinned_Version is not empty, the exact gnatprove version is deployed via `alr -n get gnatprove=<version>` and run directly. A failure to deploy is a failure to run. It is never a silent fallback to a different prover. This is how mission-critical CI fixes the proof toolchain across projects that do not pin one themselves. Exe_Path always holds a directly-executable gnatprove binary. It is never the `alr` wrapper. The deployment path runs the deployed binary itself. Toolkit_Dir is the bin directory to prepend to PATH for the child. It is empty when the binary is already on PATH. Identity is a short fingerprint of the resolved prover. For the deploy path it is the pinned version. Otherwise it is the executable or toolchain path. Run_Prove folds Identity into the result-cache key. Proofs from different gnatprove deployments are then never mixed.

| Parameter | Description |
|-----------|-------------|
| `Dir_Len` | Length of the toolkit bin directory path. |
| `Exe_Len` | Length of the resolved executable path. |
| `Exe_Path` | Output buffer for the executable path. |
| `Ident_Len` | Length of the identity fingerprint. |
| `Identity` | Output buffer for the prover identity fingerprint. |
| `Pinned_Version` | Global gnatprove version pin ("" = none. The manifest pin is still preferred when the target declares one). |
| `Success` | True if a usable gnatprove was found. |
| `Target_Dir` | Project root directory. |
| `Toolkit_Dir` | Output buffer for the toolkit bin directory. |

### procedure Run_Prove (Target_Dir : Standard.String; Opts : Adacovex.Prove.Prove_Options; Success : Standard.Boolean)

> Run gnatprove against a target project's root .gpr file. The procedure resolves gnatprove (see Resolve_GNATprove) and spawns `gnatprove -P <gpr> <options>` directly. When the deployment is not already on PATH, it prepends the toolkit bin directory to PATH for the child. It forwards the options (jobs, level, timeout, steps, memlimit, force, unrolling, inlining) to gnatprove. On success, gnatprove writes a fresh <target>/obj/gnatprove/gnatprove.out, and both the success marker and the summary content go into the proof result cache. A later run over unchanged inputs short-circuits: it restores the cached gnatprove.out (so the assessment pipeline can parse it even when obj/gnatprove/ was wiped) and skips the prover entirely. The command's stdout and stderr stream to the parent's terminal.

| Parameter | Description |
|-----------|-------------|
| `Opts` | GNATprove invocation options. |
| `Success` | True if gnatprove ran and exited 0. |
| `Target_Dir` | Project root directory. |

### procedure Run_Status (Target_Dir : Standard.String; TZ_Spec : Standard.String; Success : Standard.Boolean)

> Print a non-mutating toolkit and platform report for the `adacovex status` subcommand. It checks, in order, whether: * Alire (`alr`) is installed on $PATH. * the target manifest declares gnatprove (dependency-managed), a global pin is set, or a gnatprove is already on $PATH or cached in <data>/toolkit. * the host logical-CPU count and CI status drive GNATprove parallelism. Unlike Resolve_GNATprove and Run_Prove, it never deploys or downloads anything. Success is True when a usable gnatprove is detectable without a download and alr is present whenever the deploy path is the only option. It also prints the release note. The CI release binary is Linux x86-64 only for now.

| Parameter | Description |
|-----------|-------------|
| `Success` | True when alr and gnatprove are available or dependency-managed. |
| `TZ_Spec` | Display timezone override (--tz / --timezone), or "" for the operating system's timezone. |
| `Target_Dir` | Project root directory. |

### procedure Run_Status_Metrics (Target_Dir : Standard.String; TZ_Spec : Standard.String; Success : Standard.Boolean)

> Print the `adacovex status --metrics` report. It shows the same data as Run_Status. It uses compact key=value lines (one per line, keys lowercase with - separators). Shell scripts and CI can then consume the report without parsing prose. It never deploys or downloads anything.

| Parameter | Description |
|-----------|-------------|
| `Success` | True when alr and gnatprove are available or dependency-managed (same meaning as Run_Status). |
| `TZ_Spec` | Display timezone override (--tz / --timezone), or "" for the operating system's timezone. |
| `Target_Dir` | Project root directory. |
