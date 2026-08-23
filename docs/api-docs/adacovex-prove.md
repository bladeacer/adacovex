# Adacovex.Prove

GNATprove runner for the ``adacovex prove`` subcommand.
Resolves a gnatprove executable and runs it against a target project's
root .gpr file, leaving a fresh obj/gnatprove/gnatprove.out for the
standard assessment pipeline to parse.

Resolution priority (lightweight: adacovex only requires ``alr`` on PATH):

#. If the target's alire.toml / alire-dev.toml declares gnatprove as a
dependency, deploy ONLY the gnatprove binary crate (a self-contained
bundle -- no dependencies) into ~/.adacovex/toolchain via
``alr -n get gnatprove=<version>``, then run it directly.  This avoids
the fragile ``alr exec`` path that used to compose the target's entire
dev-manifest dependency set (covex, gnatdoc_bin, gnatformat_bin, ...):
flaky third-party downloads in CI could not fail a proof run, and no
dev-manifest swap is ever needed.  The manifest may declare the version
as a rich set expression (``^15.1.0``, ``~15.1.0``, ...); the leading
operator is stripped to yield the bare version alr accepts.  A
manifest-declared prover is authoritative: when it cannot be deployed
the run fails instead of falling back, because a different gnatprove
version can change which VCs are discharged (results must always come
from the pinned prover).  Priorities 2-5 apply only to projects whose
manifest does not declare gnatprove.

#. A gnatprove version pinned globally -- the ADACOVEX_GNATPROVE_VERSION
environment variable or the ``[prove] gnatprove-version = "16.1.0"``
key in ~/.adacovex/adacovex.toml (read by Run_Prove and passed in as
Pinned_Version).  The exact version is deployed via
``alr -n get gnatprove=<version>`` and run directly; like the manifest
pin it is authoritative (a failure to deploy is a failure to run) and
is folded into the proof result-cache identity so a different pinned
version can never reuse a stale proof.

#. A gnatprove already on $PATH.

#. A cached gnatprove in ~/.adacovex/toolchain/bin (download layout) or a
previously ``alr get``-deployed gnatprove_*/ crate under the same dir.

#. Last resort: a platform toolchain download (curl; only used when
no deployable, on-PATH, or cached gnatprove is available).

So the order is: manifest pin > global pin (config/env) > PATH > cache >
download.
HLR-PROVE: GNATprove subcommand

**See also:** [Architecture -- toolchain resolution](../architecture.md#gnatprove-toolchain-resolution-prove-subcommand)

> **Note:** All items in this package are public.

## Types

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
Suppress_Warnings : Boolean := True;
Suppress_Sets : Ada.Strings.Unbounded.Unbounded_String :=
Ada.Strings.Unbounded.Null_Unbounded_String;
Cache : Boolean := True;
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

## Procedures

### procedure Find_Root_GPR (Target_Dir : Standard.String; GPR_Path : Standard.String; GPR_Len : Standard.Natural; Success : Standard.Boolean)

| Parameter | Description |
|-----------|-------------|
| `GPR_Len` | Length of the resolved .gpr path. |
| `GPR_Path` | Output buffer for the .gpr path. |
| `Success` | True if a root .gpr file was found. |
| `Target_Dir` | Project root directory. |

### procedure Resolve_GNATprove (Target_Dir : Standard.String; Pinned_Version : Standard.String; Exe_Path : Standard.String; Exe_Len : Standard.Natural; Toolchain_Dir : Standard.String; Dir_Len : Standard.Natural; Identity : Standard.String; Ident_Len : Standard.Natural; Success : Standard.Boolean)

| Parameter | Description |
|-----------|-------------|
| `Dir_Len` | Length of the toolchain bin directory path. |
| `Exe_Len` | Length of the resolved executable path. |
| `Exe_Path` | Output buffer for the executable path. |
| `Ident_Len` | Length of the identity fingerprint. |
| `Identity` | Output buffer for the prover identity fingerprint. |
| `Pinned_Version` | Global gnatprove version pin ("" = none; the |
| `Success` | True if a usable gnatprove was found. |
| `Target_Dir` | Project root directory. |
| `Toolchain_Dir` | Output buffer for the toolchain bin directory. |

### procedure Run_Prove (Target_Dir : Standard.String; Opts : Adacovex.Prove.Prove_Options; Success : Standard.Boolean)

| Parameter | Description |
|-----------|-------------|
| `Opts` | GNATprove invocation options. |
| `Success` | True if gnatprove ran and exited 0. |
| `Target_Dir` | Project root directory. |

### procedure Run_Status (Target_Dir : Standard.String; Success : Standard.Boolean)

| Parameter | Description |
|-----------|-------------|
| `Success` | True when alr + gnatprove are available or |
| `Target_Dir` | Project root directory. |
