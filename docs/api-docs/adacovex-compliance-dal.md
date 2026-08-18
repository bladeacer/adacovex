# Adacovex.Compliance.DAL

DO-178C DAL compliance assessment engine.
Evaluates HLR trace coverage, orphan tags, test passing status, and
minimum SPARK proof level to determine Achieved / Unmet status.
HLR-COMPLIANCE: DAL assessment
HLR-DAL-A: DAL-A compliance criteria
HLR-DAL-B: DAL-B compliance criteria
HLR-DAL-C: DAL-C compliance criteria
HLR-DAL-D: DAL-D compliance criteria
HLR-DAL-E: DAL-E compliance criteria

**See also:** [DAL Levels](adacovex-dal-levels.md) | [Standards](../standards.md)

> **Note:** All items in this package are public.

## Functions

### function Is_DAL_Achieved (Assessment : Adacovex.Types.Implementation.DAL_Assessment) return Standard.Boolean `[Global]`

| Parameter | Description |
|-----------|-------------|
| `Assessment` | DAL assessment record. |

**Returns:** True if Assessment.Status = Achieved.

### function Min_SPARK_For (Level : Adacovex.Types.DAL_Level) return Adacovex.Types.SPARK_Level `[Global]`

| Parameter | Description |
|-----------|-------------|
| `Level` | Target DAL level (A-E). |

**Returns:** The minimum SPARK level that satisfies the level's criteria.

### function Need_Tests (Level : Adacovex.Types.DAL_Level) return Standard.Boolean `[Global]`

| Parameter | Description |
|-----------|-------------|
| `Level` | Target DAL level (A-E). |

**Returns:** True unless Level is DAL-E.

## Procedures

### procedure Assess_DAL (Level : Adacovex.Types.DAL_Level; Target_Dir : Standard.String; Packages : Adacovex.Types.Implementation.Package_Vectors.Vector; Proof_Summary : Adacovex.Types.Proof_Summary; Test_Summary : Adacovex.Types.Implementation.Test_Summary; Assessment : Adacovex.Types.Implementation.DAL_Assessment; Use_Cache : Standard.Boolean)

| Parameter | Description |
|-----------|-------------|
| `Assessment` | Output DAL assessment record. |
| `Level` | Target DAL level (A-E). |
| `Packages` | Scanned package vector. |
| `Proof_Summary` | GNATprove proof results. |
| `Target_Dir` | Project root directory. |
| `Test_Summary` | Test run results. |
| `Use_Cache` | When True the HLR.md/LLR.md parses are served from |

### procedure Assess_Standard (Standard : Adacovex.Types.Compliance_Standard; Level : Adacovex.Types.DAL_Level; Target_Dir : Standard.String; Packages : Adacovex.Types.Implementation.Package_Vectors.Vector; Proof_Summary : Adacovex.Types.Proof_Summary; Test_Summary : Adacovex.Types.Implementation.Test_Summary; Assessment : Adacovex.Types.Implementation.DAL_Assessment; Use_Cache : Standard.Boolean)

| Parameter | Description |
|-----------|-------------|
| `Assessment` | Output assessment record (Standard field set). |
| `Level` | Rigor tier (reused DAL level A-E). |
| `Packages` | Scanned package vector. |
| `Proof_Summary` | GNATprove proof results. |
| `Standard` | Compliance standard (DO_178C, ISO_26262, IEC_62304). |
| `Target_Dir` | Project root directory. |
| `Test_Summary` | Test run results. |
| `Use_Cache` | When True the HLR.md/LLR.md parses are served from |
