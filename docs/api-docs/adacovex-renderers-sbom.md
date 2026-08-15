# Adacovex.Renderers.SBOM

Proof-aware software bill of materials (SBOM) generator.
Produces CycloneDX 1.5 JSON and SPDX 2.3 JSON documents from the
dependency graph resolved by Adacovex.Parsers.Manifest.  Only the root
component -- the project adacovex actually assessed -- carries the
adacovex:proof_level (Stone..Platinum), adacovex:standard
("DO-178C" | "ISO 26262" | "IEC 62304"), adacovex:dal_target
(DAL-A through DAL-D), and adacovex:level (the standard-specific label
"DAL-C" | "ASIL B" | "Class A") properties.  Dependency components
report adacovex:proof_level = "Not proved": adacovex only proves the
target itself, never third-party dependencies.  Every dependency
component also carries an adacovex:dep_scope property ("base" | "dev" |
"transitive" | "vendored") distinguishing publishing (alire.toml),
development-only (alire-dev.toml), transitive, and patched-vendored
packages.
HLR-SBOM: SBOM generation

> **Note:** All items in this package are public.

## Functions

### function DAL_Property_Value (Level : Adacovex.Types.DAL_Level) return Standard.String `[Post]` `[Global]` `[SPARK]`

| Parameter | Description |
|-----------|-------------|
| `Level` | Target DAL level. |

**Returns:** "DAL-A".."DAL-D", or "" for DAL-E.

### function Escape_JSON (S : Standard.String) return Standard.String `[Pre]` `[Post]` `[Global]` `[SPARK]`

| Parameter | Description |
|-----------|-------------|
| `S` | String to escape. |

**Returns:** The escaped JSON string.

### function I2S (N : Standard.Natural) return Standard.String `[Post]` `[Global]` `[SPARK]`

| Parameter | Description |
|-----------|-------------|
| `N` | Non-negative integer to format. |

**Returns:** The decimal string, 1-10 characters, no leading zeros.

### function ISO_From_Epoch (Epoch_Sec : Standard.Natural) return Standard.String `[Global]` `[SPARK]`

| Parameter | Description |
|-----------|-------------|
| `Epoch_Sec` | Unix epoch seconds since 1970-01-01T00:00:00Z. |

**Returns:** The fixed-length ISO 8601 timestamp string.

### function Level_Property (Standard : Adacovex.Types.Compliance_Standard; Level : Adacovex.Types.DAL_Level) return Standard.String `[Global]` `[SPARK]`

| Parameter | Description |
|-----------|-------------|
| `Level` | Shared rigor tier. |
| `Standard` | Compliance standard labelling the level. |

**Returns:** The standard-specific level label, or "" for DAL-E.

### function Pad2 (N : Standard.Natural) return Standard.String `[Post]` `[Global]` `[SPARK]`

| Parameter | Description |
|-----------|-------------|
| `N` | Non-negative integer to format. |

**Returns:** Two-or-more-digit zero-padded decimal string.

### function Proof_Level_Property (Level : Adacovex.Types.SPARK_Level) return Standard.String `[Post]` `[Global]` `[SPARK]`

| Parameter | Description |
|-----------|-------------|
| `Level` | Assessed SPARK level. |

**Returns:** "Stone", "Bronze", "Silver", "Gold", or "Platinum".

### function Scope_Property (Scope : Adacovex.Types.Component_Scope) return Standard.String `[Post]` `[Global]` `[SPARK]`

| Parameter | Description |
|-----------|-------------|
| `Scope` | Component dependency scope. |

**Returns:** "base" (4), "dev" (3), "transitive" (10), or "vendored" (8).

## Procedures

### procedure Write_CycloneDX_To (F : Ada.Text_IO.File_Type; Graph : Adacovex.Types.Implementation.Component_Vectors.Vector; Proof_Level : Standard.String; Standard : Adacovex.Types.Compliance_Standard; DAL_Target : Adacovex.Types.DAL_Level)

| Parameter | Description |
|-----------|-------------|
| `DAL_Target` | Shared rigor tier for adacovex:dal_target/level. |
| `F` | Output file to write the JSON document to. |
| `Graph` | Dependency graph (index 1 = root component). |
| `Proof_Level` | adacovex:proof_level property value. |
| `Standard` | Compliance standard labelling the root assessment. |

### procedure Write_Markdown_To (F : Ada.Text_IO.File_Type; Graph : Adacovex.Types.Implementation.Component_Vectors.Vector; Proof_Level : Standard.String; Standard : Adacovex.Types.Compliance_Standard; DAL_Target : Adacovex.Types.DAL_Level)

| Parameter | Description |
|-----------|-------------|
| `DAL_Target` | Shared rigor tier for adacovex:dal_target/level. |
| `F` | Output file to write the Markdown document to. |
| `Graph` | Dependency graph (index 1 = root component). |
| `Proof_Level` | adacovex:proof_level property value. |
| `Standard` | Compliance standard labelling the root assessment. |

### procedure Write_SBOM (Format : Adacovex.Types.SBOM_Format_Kind; Out_Path : Standard.String; Graph : Adacovex.Types.Implementation.Component_Vectors.Vector; Proof_Level : Standard.String; Standard : Adacovex.Types.Compliance_Standard; DAL_Target : Adacovex.Types.DAL_Level; Success : Standard.Boolean) `[Pre]`

| Parameter | Description |
|-----------|-------------|
| `DAL_Target` | Shared rigor tier for adacovex:dal_target/level. |
| `Format` | SBOM format (CycloneDX_JSON, SPDX_JSON, or Markdown). |
| `Graph` | Dependency graph (index 1 = root component). |
| `Out_Path` | Filesystem path to write the SBOM to. |
| `Proof_Level` | adacovex:proof_level property value. |
| `Standard` | Compliance standard labelling the root assessment. |
| `Success` | True if the SBOM was written successfully. |

### procedure Write_SPDX_To (F : Ada.Text_IO.File_Type; Graph : Adacovex.Types.Implementation.Component_Vectors.Vector; Proof_Level : Standard.String; Standard : Adacovex.Types.Compliance_Standard; DAL_Target : Adacovex.Types.DAL_Level)

| Parameter | Description |
|-----------|-------------|
| `DAL_Target` | Shared rigor tier for adacovex:dal_target/level. |
| `F` | Output file to write the JSON document to. |
| `Graph` | Dependency graph (index 1 = root component). |
| `Proof_Level` | adacovex:proof_level property value. |
| `Standard` | Compliance standard labelling the root assessment. |
