# Adacovex.Prove_Patch

Proof patches for vendored dependencies.

The docstring patch system (Adacovex.Parsers.Source.Apply_Patches)
overlays documentation onto vendored .ads files.  This package extends
the same .adacovex/patches/<relative-path> layout with SPARK proof
support: a patch file may carry SPARK aspects (SPARK_Mode on the package
declaration, Pre/Post/SPARK_Mode on subprogram declarations), and the
``prove`` subcommand merges them into a copy of the vendored spec so
GNATprove analyzes the vendored unit with the patched contracts --
without modifying the original vendored sources.
--  The merge is textual and line-based: the patched spec is the original
spec with each patched subprogram declaration (matched on name AND
normalized parameter profile, so an overload patches its exact
signature -- never a same-named sibling) replaced by the patch's
declaration block (which carries the aspects), and the package
declaration given the patch's package-level aspect when present.

Where the vendored body is SPARK-clean, GNATprove proves the patched
contracts; where it is not (e.g. Ada.Text_IO callers), GNATprove skips
the bodies by design and the unit is reported as out of proof scope --
it never drags the target's proof level down.
HLR-PROVE: GNATprove runner and proof patches

> **Note:** All items in this package are public.

## Functions

### function Count_Proof_Patches (Target_Dir : Standard.String) return Standard.Natural

| Parameter | Description |
|-----------|-------------|
| `Target_Dir` | Target project root. |

**Returns:** Number of proof-carrying patch files.

### function Has_Proof (Text : Standard.String) return Standard.Boolean

| Parameter | Description |
|-----------|-------------|
| `Text` | Patch file contents. |

**Returns:** True when the patch carries proof aspects.

### function Patches_Hash (Target_Dir : Standard.String) return Standard.String

| Parameter | Description |
|-----------|-------------|
| `Target_Dir` | Target project root. |

**Returns:** Hex digest of all patch file contents ("" when none).

## Procedures

### procedure Apply (Original : Standard.String; Patch : Standard.String; Merged : Standard.String; Merged_Len : Standard.Natural; OK : Standard.Boolean)

| Parameter | Description |
|-----------|-------------|
| `Merged` | Buffer receiving the patched spec. |
| `Merged_Len` | Length of the patched spec (0 on failure). |
| `OK` | True when the merge succeeded. |
| `Original` | Original vendored spec text. |
| `Patch` | Patch text (valid Ada .ads with docstrings and/or |

### procedure Build_Patched_Copy (Target_Dir : Standard.String; Root_GPR : Standard.String; Copy_Dir : Standard.String; Copy_Len : Standard.Natural; Copy_GPR : Standard.String; GPR_Len : Standard.Natural; Success : Standard.Boolean)

| Parameter | Description |
|-----------|-------------|
| `Copy_Dir` | Directory of the patched proof tree. |
| `Copy_GPR` | Absolute path of the copy's root project file. |
| `Copy_Len` | Length of Copy_Dir. |
| `GPR_Len` | Length of Copy_GPR. |
| `Root_GPR` | Absolute path of the root project file. |
| `Success` | True when the tree was built (a merge failure |
| `Target_Dir` | Target project root. |
