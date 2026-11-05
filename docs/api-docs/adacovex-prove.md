# Adacovex.Prove

GNATprove runner for the ``adacovex prove`` subcommand.
It resolves a gnatprove executable. It runs it against a target
project's root .gpr file. It leaves a fresh obj/gnatprove/gnatprove.out
for the standard assessment pipeline to parse.

Resolution priority (lightweight: adacovex only requires ``alr`` on PATH):

#. If the target's alire.toml or alire-dev.toml declares gnatprove as
a dependency, deploy only the gnatprove binary crate. This crate is
a self-contained bundle with no dependencies. Deploy it into
<data>/toolchain via ``alr -n get gnatprove=<version>``, then run
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
the deployed crate under <data>/toolchain with no download, and
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

#. A cached gnatprove in <data>/toolchain/bin (download layout) or a
previously ``alr get``-deployed gnatprove_*/ crate under the same dir.

#. Last resort: a platform toolchain download. It uses curl. It is
used only when no deployable, on-PATH, or cached gnatprove is
available.

So the order is: manifest pin > global pin (config/env) > PATH > cache >
download.
HLR-PROVE: GNATprove subcommand

**See also:** [Architecture -- toolchain resolution](../contributing/architecture-dependencies.md#gnatprove-toolchain-resolution-prove-subcommand)

> **Note:** All items in this package are public.

## Types

### type Failure_Array

```ada
type Failure_Array is array (1 .. Max_Failure_Items) of Prove_Failure;
```

### type Failure_Stats

```ada
type Failure_Stats is record
Unproved : Natural := 0;
Count    : Natural := 0;
Items    : Failure_Array;
end record;
```

### type Prove_Failure

```ada
type Prove_Failure is record
Location : Ada.Strings.Unbounded.Unbounded_String :=
Ada.Strings.Unbounded.Null_Unbounded_String;
Kind     : Ada.Strings.Unbounded.Unbounded_String :=
Ada
.Strings
.Unbounded
.Null_Unbounded_String;
Flow     : Boolean := False;
Budget : Boolean := False;
end record;
```

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
end record;
```

### type Replay_Stats

```ada
type Replay_Stats is record
Hidden   : Natural := 0;
Progress : Natural := 0;
Errors   : Natural := 0;
Warnings : Natural := 0;
end record;
```

## Functions

### function Build_Option_String (Opts : Adacovex.Prove.Prove_Options; Jobs : Standard.Natural) return Standard.String

| Parameter | Description |
|-----------|-------------|
| `Jobs` | Resolved job count to forward (-j value). |
| `Opts` | GNATprove options. |

**Returns:** Space-separated gnatprove option string.

### function Detect_Core_Count return Standard.Natural

**Returns:** Number of logical processors (>= 1).

### function Diagnostics_Text (Prover : Standard.String; Stats : Adacovex.Prove.Failure_Stats) return Standard.String

| Parameter | Description |
|-----------|-------------|
| `Prover` | The resolved prover identity (version or path), or "" |
| `Stats` | Findings gathered by Collect_Failures. |

**Returns:** The diagnostics block, or "" when there is nothing to report.

### function Is_Proof_Input (Name : Standard.String) return Standard.Boolean

| Parameter | Description |
|-----------|-------------|
| `Name` | File base name, with extension. |

**Returns:** True when the file is hashed into the proof-input digest.

## Procedures

### procedure Collect_Failures (Path : Standard.String; Stats : Adacovex.Prove.Failure_Stats)

| Parameter | Description |
|-----------|-------------|
| `Path` | Captured gnatprove output file to read. |
| `Stats` | Findings gathered during the pass. |

### procedure Export_Status (Target_Dir : Standard.String; Out_Path : Standard.String; TZ_Spec : Standard.String; Success : Standard.Boolean)

| Parameter | Description |
|-----------|-------------|
| `Out_Path` | Output file path, or "" for stdout. |
| `Success` | True when the report was gathered and written. |
| `TZ_Spec` | Display timezone override (--tz / --timezone), or "" |
| `Target_Dir` | Project root directory. |

### procedure Find_Root_GPR (Target_Dir : Standard.String; GPR_Path : Standard.String; GPR_Len : Standard.Natural; Success : Standard.Boolean)

| Parameter | Description |
|-----------|-------------|
| `GPR_Len` | Length of the resolved .gpr path. |
| `GPR_Path` | Output buffer for the .gpr path. |
| `Success` | True if a root .gpr file was found. |
| `Target_Dir` | Project root directory. |

### procedure Replay_Suppressed (Path : Standard.String; Sets : Standard.String; Out_Path : Standard.String; Stats : Adacovex.Prove.Replay_Stats)

| Parameter | Description |
|-----------|-------------|
| `Out_Path` | Destination file. Empty replays to standard output. |
| `Path` | Captured gnatprove output file to replay. |
| `Sets` | Comma-separated suppression-set names. Empty selects the |
| `Stats` | Counts gathered during the pass. |

### procedure Resolve_GNATprove (Target_Dir : Standard.String; Pinned_Version : Standard.String; Exe_Path : Standard.String; Exe_Len : Standard.Natural; Toolchain_Dir : Standard.String; Dir_Len : Standard.Natural; Identity : Standard.String; Ident_Len : Standard.Natural; Success : Standard.Boolean)

| Parameter | Description |
|-----------|-------------|
| `Dir_Len` | Length of the toolchain bin directory path. |
| `Exe_Len` | Length of the resolved executable path. |
| `Exe_Path` | Output buffer for the executable path. |
| `Ident_Len` | Length of the identity fingerprint. |
| `Identity` | Output buffer for the prover identity fingerprint. |
| `Pinned_Version` | Global gnatprove version pin ("" = none. The |
| `Success` | True if a usable gnatprove was found. |
| `Target_Dir` | Project root directory. |
| `Toolchain_Dir` | Output buffer for the toolchain bin directory. |

### procedure Run_Prove (Target_Dir : Standard.String; Opts : Adacovex.Prove.Prove_Options; Success : Standard.Boolean)

| Parameter | Description |
|-----------|-------------|
| `Opts` | GNATprove invocation options. |
| `Success` | True if gnatprove ran and exited 0. |
| `Target_Dir` | Project root directory. |

### procedure Run_Status (Target_Dir : Standard.String; TZ_Spec : Standard.String; Success : Standard.Boolean)

| Parameter | Description |
|-----------|-------------|
| `Success` | True when alr and gnatprove are available or |
| `TZ_Spec` | Display timezone override (--tz / --timezone), or "" |
| `Target_Dir` | Project root directory. |

### procedure Run_Status_Metrics (Target_Dir : Standard.String; TZ_Spec : Standard.String; Success : Standard.Boolean)

| Parameter | Description |
|-----------|-------------|
| `Success` | True when alr and gnatprove are available or |
| `TZ_Spec` | Display timezone override (--tz / --timezone), or "" |
| `Target_Dir` | Project root directory. |
