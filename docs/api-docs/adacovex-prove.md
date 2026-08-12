# Adacovex.Prove

GNATprove runner for the ``adacovex prove`` subcommand.
Resolves a gnatprove executable and runs it against a target project's
root .gpr file, leaving a fresh obj/gnatprove/gnatprove.out for the
standard assessment pipeline to parse.

Resolution priority (lightweight: adacovex only requires ``alr`` on PATH):

#. If the target's alire.toml / alire-dev.toml declares gnatprove as a
dependency, invoke it via ``alr exec`` (alire manages the toolchain).
When gnatprove lives only in alire-dev.toml (the common dev-manifest
layout), the dev manifest is temporarily swapped over alire.toml for
the proof run and restored afterwards -- the assessment and SBOM
pipeline always scans the publishing alire.toml.

#. A gnatprove already on $PATH.

#. A cached gnatprove in ~/.adacovex/toolchain/bin.

#. Last resort: a platform toolchain download (curl; only used when
no alire-managed or on-PATH gnatprove is available).

HLR-PROVE: GNATprove subcommand

> **Note:** All items in this package are public.

## Types

### type Prove_Options

```ada
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

### procedure Resolve_GNATprove (Target_Dir : Standard.String; Exe_Path : Standard.String; Exe_Len : Standard.Natural; Toolchain_Dir : Standard.String; Dir_Len : Standard.Natural; Via_Alr : Standard.Boolean; Success : Standard.Boolean)

| Parameter | Description |
|-----------|-------------|
| `Dir_Len` | Length of the toolchain bin directory path. |
| `Exe_Len` | Length of the resolved executable path. |
| `Exe_Path` | Output buffer for the executable path. |
| `Success` | True if a usable gnatprove was found. |
| `Target_Dir` | Project root directory. |
| `Toolchain_Dir` | Output buffer for the toolchain bin directory. |
| `Via_Alr` | True if gnatprove must run through `alr exec`. |

### procedure Run_Prove (Target_Dir : Standard.String; Opts : Adacovex.Prove.Prove_Options; Success : Standard.Boolean)

| Parameter | Description |
|-----------|-------------|
| `Opts` | GNATprove invocation options. |
| `Success` | True if gnatprove ran and exited 0. |
| `Target_Dir` | Project root directory. |
