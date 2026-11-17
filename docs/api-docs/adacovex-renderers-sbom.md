# Adacovex.Renderers.SBOM

Proof-aware software bill of materials (SBOM) generator.
Produces CycloneDX 1.5 JSON and SPDX 2.3 JSON documents from the
dependency graph resolved by Adacovex.Parsers.Manifest. Only the root
component carries the adacovex properties. The root component is the
project adacovex actually assessed. It carries adacovex:proof_level
(Stone..Platinum), adacovex:standard ("DO-178C" | "ISO 26262" |
"IEC 62304"), adacovex:dal_target (DAL-A through DAL-D), and
adacovex:level (the standard-specific label "DAL-C" | "ASIL B" |
"Class A"). Dependency components report adacovex:proof_level =
"Not proved". adacovex only proves the target itself. It never proves
third-party dependencies. Every dependency component also carries an
adacovex:dep_scope property ("base" | "dev" | "transitive" |
"vendored"). This property distinguishes publishing (alire.toml),
development-only (alire-dev.toml), transitive, and patched-vendored
packages.
HLR-SBOM: SBOM generation

**See also:** [SBOM](../usage/sbom.md)

> **Note:** All items in this package are public.

## Functions

### function All_Levels_Property (Level : Adacovex.Types.DAL_Level) return Standard.String

> Slash-joined standard-specific level labels for the "all standards" SBOM property. For example, "DAL-C / ASIL B / Class A". Each standard's native label is used. An ISO 26262 or IEC 62304 reader sees "ASIL B" or "Class A" without decoding the shared tier.

| Parameter | Description |
|-----------|-------------|
| `Level` | Shared rigor tier. |

**Returns:** The slash-joined level labels for all three standards.

### function All_Standards_Property return Standard.String `[Post]` `[Global]` `[SPARK]`

> Comma-joined standard names for the "all standards" SBOM property. The value is "DO-178C, ISO 26262, IEC 62304". Used for adacovex:standard when --standard=all runs one assessment against every standard.

**Returns:** The comma-joined standard names.

### function DAL_Property_Value (Level : Adacovex.Types.DAL_Level) return Standard.String `[Post]` `[Global]` `[SPARK]`

> Map a DAL level to the dal_target property value ("DAL-A".."DAL-D"). Returns an empty string for DAL-E. DAL-E has no safety effect. As a result, it is not asserted in the SBOM.

| Parameter | Description |
|-----------|-------------|
| `Level` | Target DAL level. |

**Returns:** "DAL-A".."DAL-D", or "" for DAL-E.

### function Escape_JSON (S : Standard.String) return Standard.String `[Pre]` `[Post]` `[Global]` `[SPARK]`

> Escape a string for inclusion in a JSON document. Backslash, quote, and control characters are escaped. The emitted JSON is then always well-formed. This holds even for manifest strings containing embedded quotes. The output buffer is bounded at six bytes per input byte (the widest escape, "\u00xx"). Source length is capped at Max_Esc_Src. The 6x output bound then stays provably within Natural.

| Parameter | Description |
|-----------|-------------|
| `S` | String to escape. |

**Returns:** The escaped JSON string.

### function I2S (N : Standard.Natural) return Standard.String `[Post]` `[Global]` `[SPARK]`

> Decimal string of a non-negative integer. The fixed 10-character buffer holds any Natural (up to 2,147,483,647, ten digits). The loop invariant proves the write cursor never underflows the buffer.

| Parameter | Description |
|-----------|-------------|
| `N` | Non-negative integer to format. |

**Returns:** The decimal string, 1-10 characters, no leading zeros.

### function ISO_From_Epoch (Epoch_Sec : Standard.Natural) return Standard.String `[Global]` `[SPARK]`

> ISO 8601 UTC timestamp (YYYY-MM-DDTHH:MM:SS) from a Unix epoch second count. It is computed with pure integer arithmetic (Howard Hinnant's civil-from-days algorithm). The result is then identical on every machine and timezone.

| Parameter | Description |
|-----------|-------------|
| `Epoch_Sec` | Unix epoch seconds since 1970-01-01T00:00:00Z. |

**Returns:** The fixed-length ISO 8601 timestamp string.

### function Level_Property (Standard : Adacovex.Types.Compliance_Standard; Level : Adacovex.Types.DAL_Level) return Standard.String `[Global]` `[SPARK]`

> Standard-specific level label for the root component's adacovex:level property ("DAL-C", "ASIL B", "Class A", ...). Returns an empty string for the no-safety-effect tier (DAL-E), matching DAL_Property_Value's omission of DAL-E.

| Parameter | Description |
|-----------|-------------|
| `Level` | Shared rigor tier. |
| `Standard` | Compliance standard labelling the level. |

**Returns:** The standard-specific level label, or "" for DAL-E.

### function Pad2 (N : Standard.Natural) return Standard.String `[Post]` `[Global]` `[SPARK]`

> Two-digit-padded decimal string of a non-negative integer (single digits are prefixed with a zero).

| Parameter | Description |
|-----------|-------------|
| `N` | Non-negative integer to format. |

**Returns:** Two-or-more-digit zero-padded decimal string.

### function Proof_Level_Property (Level : Adacovex.Types.SPARK_Level) return Standard.String `[Post]` `[Global]` `[SPARK]`

> Map an assessed SPARK level to the binary proof-level property value. Reports the honest assessed level (Stone..Platinum) verbatim. It does not collapse to a coarse "Gold" or "Platinum" tier. SBOM consumers then never overstate the assurance state. For example, Silver with unproved VCs is reported as "Silver", never "Gold".

| Parameter | Description |
|-----------|-------------|
| `Level` | Assessed SPARK level. |

**Returns:** "Stone", "Bronze", "Silver", "Gold", or "Platinum".

### function Scope_Property (Scope : Adacovex.Types.Component_Scope) return Standard.String `[Post]` `[Global]` `[SPARK]`

> Map a dependency scope to the adacovex:dep_scope property value ("base", "dev", "transitive", or "vendored"). Base dependencies are declared in the publishing alire.toml. Dev dependencies are declared only in alire-dev.toml. Transitive ones are in neither manifest. Vendored packages are overlaid by a .adacovex/patches/ docstring patch.

| Parameter | Description |
|-----------|-------------|
| `Scope` | Component dependency scope. |

**Returns:** "base" (4), "dev" (3), "transitive" (10), or "vendored" (8).

## Procedures

### procedure Write_CycloneDX_To (F : Ada.Text_IO.File_Type; Graph : Adacovex.Types.Implementation.Component_Vectors.Vector; Proof_Level : Standard.String; Standard : Adacovex.Types.Compliance_Standard; DAL_Target : Adacovex.Types.DAL_Level; Standard_All : Standard.Boolean)

> Write a CycloneDX 1.5 JSON SBOM to an already-open file.

| Parameter | Description |
|-----------|-------------|
| `DAL_Target` | Shared rigor tier for adacovex:dal_target/level. |
| `F` | Output file to write the JSON document to. |
| `Graph` | Dependency graph (index 1 = root component). |
| `Proof_Level` | adacovex:proof_level property value. |
| `Standard` | Compliance standard labelling the root assessment. |
| `Standard_All` | True when --standard=all: emit the joined standard names and level labels for every standard. |

### procedure Write_Markdown_To (F : Ada.Text_IO.File_Type; Graph : Adacovex.Types.Implementation.Component_Vectors.Vector; Proof_Level : Standard.String; Standard : Adacovex.Types.Compliance_Standard; DAL_Target : Adacovex.Types.DAL_Level; Standard_All : Standard.Boolean)

> Write a human-readable Markdown SBOM to an already-open file. Renders a compliance table of every component with its version, licence, PURL, proof level, standard, and DAL target properties.

| Parameter | Description |
|-----------|-------------|
| `DAL_Target` | Shared rigor tier for adacovex:dal_target/level. |
| `F` | Output file to write the Markdown document to. |
| `Graph` | Dependency graph (index 1 = root component). |
| `Proof_Level` | adacovex:proof_level property value. |
| `Standard` | Compliance standard labelling the root assessment. |
| `Standard_All` | True when --standard=all: emit the joined standard names and level labels for every standard. |

### procedure Write_SBOM (Format : Adacovex.Types.SBOM_Format_Kind; Out_Path : Standard.String; Graph : Adacovex.Types.Implementation.Component_Vectors.Vector; Proof_Level : Standard.String; Standard : Adacovex.Types.Compliance_Standard; DAL_Target : Adacovex.Types.DAL_Level; Standard_All : Standard.Boolean; Success : Standard.Boolean) `[Pre]`

> Write an SBOM in the requested format to Out_Path. Creates any missing parent directories and overwrites Out_Path.

| Parameter | Description |
|-----------|-------------|
| `DAL_Target` | Shared rigor tier for adacovex:dal_target/level. |
| `Format` | SBOM format (CycloneDX_JSON, SPDX_JSON, or Markdown). |
| `Graph` | Dependency graph (index 1 = root component). |
| `Out_Path` | Filesystem path to write the SBOM to. |
| `Proof_Level` | adacovex:proof_level property value. |
| `Standard` | Compliance standard labelling the root assessment. |
| `Standard_All` | True when --standard=all: emit the joined standard names and level labels for every standard instead of the single selected standard. |
| `Success` | True if the SBOM was written successfully. |

### procedure Write_SPDX_To (F : Ada.Text_IO.File_Type; Graph : Adacovex.Types.Implementation.Component_Vectors.Vector; Proof_Level : Standard.String; Standard : Adacovex.Types.Compliance_Standard; DAL_Target : Adacovex.Types.DAL_Level; Standard_All : Standard.Boolean)

> Write an SPDX 2.3 JSON SBOM to an already-open file.

| Parameter | Description |
|-----------|-------------|
| `DAL_Target` | Shared rigor tier for adacovex:dal_target/level. |
| `F` | Output file to write the JSON document to. |
| `Graph` | Dependency graph (index 1 = root component). |
| `Proof_Level` | adacovex:proof_level property value. |
| `Standard` | Compliance standard labelling the root assessment. |
| `Standard_All` | True when --standard=all: emit the joined standard names and level labels for every standard. |
