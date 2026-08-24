# Adacovex.Prove_Patch

Proof patches for vendored dependencies.

The docstring patch system (Adacovex.Parsers.Source.Apply_Patches)
overlays documentation onto vendored .ads files.  This package extends
the same .adacovex/patches/<relative-path> layout with SPARK proof
support.  A patch file can carry SPARK aspects.  The aspects are
SPARK_Mode on the package declaration and Pre, Post, or SPARK_Mode on
subprogram declarations.  The ``prove`` subcommand merges them into a copy
of the vendored spec.  When the patch carries one, it also merges the
vendored body.  GNATprove then analyses the vendored unit with the
patched contracts.  It does not modify the original vendored sources.
A .ads patch re-declares the spec with contracts.  A .adb patch opts
the body into the proof.  The body is analysed only when it declares
SPARK_Mode On itself.

The merge is textual and line-based.  The patched source is the original
with each patched subprogram declaration replaced by the patch's
declaration block.  The block carries the aspects.  A declaration
matches on name and normalised parameter profile.  An overload patches
its exact signature, never a same-named sibling.  The default ``in`` mode
is equivalent to a bare mode.  ``in out`` and ``out`` are distinct.  The
package declaration is given the patch's package-level aspect when
present.  Subprogram declarations terminate at the ';' of a spec
declaration or at the ``is`` of a body declaration.  A patched body
declaration is replaced without touching the body proper.

When the vendored body is SPARK-clean and opted in via a body patch,
GNATprove proves the patched contracts.  When it is not, for example
Ada.Text_IO callers, GNATprove skips the I/O bodies by design.  The
unit is then reported as out of proof scope.  A proof patch never drags
the target's proof level down.
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
| `Merged` | Buffer receiving the patched source. |
| `Merged_Len` | Length of the patched source (0 on failure). |
| `OK` | True when the merge succeeded. |
| `Original` | Original vendored source text. |
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
