# Adacovex.Compliance.DAL

Run DAL compliance assessment for any DAL level (A-E).
Evaluates HLR trace coverage, orphan tag absence, test pass rate,
and minimum SPARK proof level (per-level criteria). Populates
Assessment with pass/fail results and detailed failure reasons.
@param Level  Target DAL level (A-E).
@param Target_Dir  Project root directory.
@param Packages  Scanned package array.
@param Pkg_Count  Number of packages.
@param Proof_Summary  GNATprove proof results.
@param Test_Summary  Test run results.
@param Assessment  Output DAL assessment record.

> **Note:** All items in this package are public.

## Functions

### function Is_DAL_Achieved (Assessment : Adacovex.Types.DAL_Assessment) return Standard.Boolean `[Global]`

| Parameter | Description |
|-----------|-------------|
| `Assessment` | DAL assessment record. |

**Returns:** True if Assessment.Status = Achieved.

## Procedures

### procedure Assess_DAL (Level : Adacovex.Types.DAL_Level; Target_Dir : Standard.String; Packages : Adacovex.Types.Package_Array; Pkg_Count : Standard.Natural; Proof_Summary : Adacovex.Types.Proof_Summary; Test_Summary : Adacovex.Types.Test_Summary; Assessment : Adacovex.Types.DAL_Assessment) `[Pre]`

| Parameter | Description |
|-----------|-------------|
| `Assessment` | Output DAL assessment record. |
| `Level` | Target DAL level (A-E). |
| `Packages` | Scanned package array. |
| `Pkg_Count` | Number of packages. |
| `Proof_Summary` | GNATprove proof results. |
| `Target_Dir` | Project root directory. |
| `Test_Summary` | Test run results. |
