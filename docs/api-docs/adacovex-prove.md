# Adacovex.Prove

GNATprove runner for the ``adacovex prove`` subcommand.
Resolves a gnatprove executable (PATH, then ~/.adacovex/toolchain/bin,
then a platform toolchain download), runs it against a target project's
root .gpr file, and leaves a fresh obj/gnatprove/gnatprove.out for the
standard assessment pipeline to parse.  No alire.toml is required in the
target project: gnatprove is found from the toolchain, not the project.
HLR-PROVE: GNATprove subcommand

> **Note:** All items in this package are public.

## Procedures

### procedure Find_Root_GPR (Target_Dir : Standard.String; GPR_Path : Standard.String; GPR_Len : Standard.Natural; Success : Standard.Boolean)

| Parameter | Description |
|-----------|-------------|
| `GPR_Len` | Length of the resolved .gpr path. |
| `GPR_Path` | Output buffer for the .gpr path. |
| `Success` | True if a root .gpr file was found. |
| `Target_Dir` | Project root directory. |

### procedure Resolve_GNATprove (Exe_Path : Standard.String; Exe_Len : Standard.Natural; Toolchain_Dir : Standard.String; Dir_Len : Standard.Natural; Success : Standard.Boolean)

| Parameter | Description |
|-----------|-------------|
| `Dir_Len` | Length of the toolchain bin directory path. |
| `Exe_Len` | Length of the resolved executable path. |
| `Exe_Path` | Output buffer for the gnatprove executable path. |
| `Success` | True if a usable gnatprove was found. |
| `Toolchain_Dir` | Output buffer for the toolchain bin directory. |

### procedure Run_Prove (Target_Dir : Standard.String; Success : Standard.Boolean)

| Parameter | Description |
|-----------|-------------|
| `Success` | True if gnatprove ran and exited 0. |
| `Target_Dir` | Project root directory. |
