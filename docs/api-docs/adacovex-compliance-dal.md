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

> **Note:** All items in this package are public.

## Functions

### function Is_DAL_Achieved (Assessment : Adacovex.Types.DAL_Assessment) return Standard.Boolean `[Global]`

| Parameter | Description |
|-----------|-------------|
| `Assessment` | DAL assessment record. |

**Returns:** True if Assessment.Status = Achieved.

## Procedures

### procedure Assess_DAL (Level : Adacovex.Types.DAL_Level; Target_Dir : Standard.String; Packages : Adacovex.Types.Package_Vectors.Vector; Proof_Summary : Adacovex.Types.Proof_Summary; Test_Summary : Adacovex.Types.Test_Summary; Assessment : Adacovex.Types.DAL_Assessment)

| Parameter | Description |
|-----------|-------------|
| `Assessment` | Output DAL assessment record. |
| `Level` | Target DAL level (A-E). |
| `Packages` | Scanned package vector. |
| `Proof_Summary` | GNATprove proof results. |
| `Target_Dir` | Project root directory. |
| `Test_Summary` | Test run results. |
