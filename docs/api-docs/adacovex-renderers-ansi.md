# Adacovex.Renderers.ANSI

Print a formatted report to standard output.
Displays a color-coded summary of docstring coverage, proof results,
test results, and DO-178C DAL compliance using ANSI escape sequences.
@param Doc_Metrics  Docstring coverage metrics.
@param Proof  GNATprove proof summary.
@param Tests  Test result summary.
@param DAL_Assess  DAL compliance assessment.
@param Packages  Scanned package array.
@param Pkg_Count  Number of packages.

> **Note:** All items in this package are public.

## Procedures

### procedure Render_Summary (Doc_Metrics : Adacovex.Types.Docstring_Metrics; Proof : Adacovex.Types.Proof_Summary; Tests : Adacovex.Types.Test_Summary; DAL_Assess : Adacovex.Types.DAL_Assessment; Packages : Adacovex.Types.Package_Array; Pkg_Count : Standard.Natural)

| Parameter | Description |
|-----------|-------------|
| `DAL_Assess` | DAL compliance assessment. |
| `Doc_Metrics` | Docstring coverage metrics. |
| `Packages` | Scanned package array. |
| `Pkg_Count` | Number of packages. |
| `Proof` | GNATprove proof summary. |
| `Tests` | Test result summary. |
