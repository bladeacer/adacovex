# Adacovex.Renderers.SBOM

Proof-aware software bill of materials (SBOM) generator.
Produces CycloneDX 1.5 JSON and SPDX 2.3 JSON documents from the
dependency graph resolved by Adacovex.Parsers.Manifest.  Only the root
component -- the project adacovex actually assessed -- carries the
adacovex:proof_level (Gold | Platinum) and adacovex:dal_target
(DAL-A through DAL-D) properties.  Dependency components report
adacovex:proof_level = "Not proved": adacovex only proves the target
itself, never third-party dependencies.
HLR-SBOM: SBOM generation

> **Note:** All items in this package are public.

## Functions

### function DAL_Property_Value (Level : Adacovex.Types.DAL_Level) return Standard.String `[Post]` `[Global]` `[SPARK]`

| Parameter | Description |
|-----------|-------------|
| `Level` | Target DAL level. |

**Returns:** "DAL-A".."DAL-D", or "" for DAL-E.

### function Proof_Level_Property (Level : Adacovex.Types.SPARK_Level) return Standard.String `[Post]` `[Global]` `[SPARK]`

| Parameter | Description |
|-----------|-------------|
| `Level` | Assessed SPARK level. |

**Returns:** "Gold" or "Platinum".

## Procedures

### procedure Write_CycloneDX_To (F : Ada.Text_IO.File_Type; Graph : Adacovex.Types.Implementation.Component_Vectors.Vector; Proof_Level : Standard.String; DAL_Target : Standard.String)

| Parameter | Description |
|-----------|-------------|
| `DAL_Target` | adacovex:dal_target property value. |
| `F` | Output file to write the JSON document to. |
| `Graph` | Dependency graph (index 1 = root component). |
| `Proof_Level` | adacovex:proof_level property value. |

### procedure Write_Markdown_To (F : Ada.Text_IO.File_Type; Graph : Adacovex.Types.Implementation.Component_Vectors.Vector; Proof_Level : Standard.String; DAL_Target : Standard.String)

| Parameter | Description |
|-----------|-------------|
| `DAL_Target` | adacovex:dal_target property value. |
| `F` | Output file to write the Markdown document to. |
| `Graph` | Dependency graph (index 1 = root component). |
| `Proof_Level` | adacovex:proof_level property value. |

### procedure Write_SBOM (Format : Adacovex.Types.SBOM_Format_Kind; Out_Path : Standard.String; Graph : Adacovex.Types.Implementation.Component_Vectors.Vector; Proof_Level : Standard.String; DAL_Target : Standard.String; Success : Standard.Boolean) `[Pre]`

| Parameter | Description |
|-----------|-------------|
| `DAL_Target` | adacovex:dal_target property value. |
| `Format` | SBOM format (CycloneDX_JSON or SPDX_JSON). |
| `Graph` | Dependency graph (index 1 = root component). |
| `Out_Path` | Filesystem path to write the SBOM to. |
| `Proof_Level` | adacovex:proof_level property value. |
| `Success` | True if the SBOM was written successfully. |

### procedure Write_SPDX_To (F : Ada.Text_IO.File_Type; Graph : Adacovex.Types.Implementation.Component_Vectors.Vector; Proof_Level : Standard.String; DAL_Target : Standard.String)

| Parameter | Description |
|-----------|-------------|
| `DAL_Target` | adacovex:dal_target property value. |
| `F` | Output file to write the JSON document to. |
| `Graph` | Dependency graph (index 1 = root component). |
| `Proof_Level` | adacovex:proof_level property value. |
