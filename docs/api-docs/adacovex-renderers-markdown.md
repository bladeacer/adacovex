# Adacovex.Renderers.Markdown

Write a full verification report to the given file path.
Generates a VERIFICATION.md file with sections for coverage analysis,
proof results table, test summary, and DO-178C compliance status.
@param Path  Output file path for VERIFICATION.md.
@param Doc_Metrics  Docstring coverage metrics.
@param Proof  GNATprove proof summary.
@param Tests  Test result summary.
@param DAL_Assess  DAL compliance assessment.
@param Packages  Scanned package array.
@param Pkg_Count  Number of packages.

> **Note:** All items in this package are public.

## Procedures

### procedure Generate_Trace_Matrix (Path : Standard.String; Packages : Adacovex.Types.Package_Array; Pkg_Count : Standard.Natural) `[Pre]`

| Parameter | Description |
|-----------|-------------|
| `Packages` | Scanned package array. |
| `Path` | Output file path for TRACE.md. |
| `Pkg_Count` | Number of packages. |

### procedure Generate_Verification_Report (Path : Standard.String; Doc_Metrics : Adacovex.Types.Docstring_Metrics; Proof : Adacovex.Types.Proof_Summary; Tests : Adacovex.Types.Test_Summary; DAL_Assess : Adacovex.Types.DAL_Assessment; Packages : Adacovex.Types.Package_Array; Pkg_Count : Standard.Natural) `[Pre]`

| Parameter | Description |
|-----------|-------------|
| `DAL_Assess` | DAL compliance assessment. |
| `Doc_Metrics` | Docstring coverage metrics. |
| `Packages` | Scanned package array. |
| `Path` | Output file path for VERIFICATION.md. |
| `Pkg_Count` | Number of packages. |
| `Proof` | GNATprove proof summary. |
| `Tests` | Test result summary. |
