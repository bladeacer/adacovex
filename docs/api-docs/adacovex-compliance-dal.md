# Adacovex.Compliance.DAL

Run DAL compliance assessment for any DAL level (A-E).
Evaluates HLR trace coverage, orphan tag absence, test pass rate,
and minimum SPARK proof level (per-level criteria). The routine
populates Assessment with pass/fail results and detailed failure reasons.
@param Level  Target DAL level (A-E).
@param Target_Dir  Project root directory.
@param Packages  Scanned package vector.
@param Proof_Summary  GNATprove proof results.
@param Test_Summary  Test run results.
@param Assessment  Output DAL assessment record.
@param Use_Cache  When True the HLR.md/LLR.md parses are served from
the on-disk result cache when unchanged; when False they are always
re-parsed (--no-cache).

**See also:** [DAL Levels](adacovex-dal-levels.md) | [Standards](../usage/standards.md)

> **Note:** All items in this package are public.

## Functions

### function Is_DAL_Achieved (Assessment : Adacovex.Types.Implementation.DAL_Assessment) return Standard.Boolean `[Global]`

| Parameter | Description |
|-----------|-------------|
| `Assessment` | DAL assessment record. |

**Returns:** True if Assessment.Status = Achieved.

### function Min_SPARK_For (Level : Adacovex.Types.DAL_Level) return Adacovex.Types.SPARK_Level `[Post]` `[Global]` `[SPARK]`

| Parameter | Description |
|-----------|-------------|
| `Level` | Target DAL level (A-E). |

**Returns:** The minimum SPARK level that satisfies the criteria of the level.

### function Need_Tests (Level : Adacovex.Types.DAL_Level) return Standard.Boolean `[Post]` `[Global]` `[SPARK]`

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
