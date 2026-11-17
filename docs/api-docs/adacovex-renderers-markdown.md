# Adacovex.Renderers.Markdown

Markdown report renderer.
Generates VERIFICATION.md (coverage, proof, test, compliance tables)
and TRACE.md (HLR to package traceability matrix).
HLR-RENDER-MD: Markdown report generation

> **Note:** All items in this package are public.

## Procedures

### procedure Generate_Trace_Matrix (Path : Standard.String; Packages : Adacovex.Types.Implementation.Package_Vectors.Vector) `[Pre]`

> Write a traceability matrix mapping packages to their HLR tags. Generates a TRACE.md file with a table listing each package and its associated HLR identifiers from source-code annotations.

| Parameter | Description |
|-----------|-------------|
| `Packages` | Scanned package vector. |
| `Path` | Output file path for TRACE.md. |

### procedure Generate_Verification_Report (Path : Standard.String; Doc_Metrics : Adacovex.Types.Docstring_Metrics; Proof : Adacovex.Types.Proof_Summary; Tests : Adacovex.Types.Implementation.Test_Summary; DAL_Assess : Adacovex.Types.Implementation.DAL_Assessment; Packages : Adacovex.Types.Implementation.Package_Vectors.Vector; All_Standards : Standard.Boolean) `[Pre]`

> Write a full verification report to the given file path. Generates a VERIFICATION.md file with sections for coverage analysis, proof results table, test summary, and compliance status. The compliance section is standard-aware. It prints the selected standard's level label. When All_Standards is True, it prints one row per standard.

| Parameter | Description |
|-----------|-------------|
| `All_Standards` | Report every standard (else the selected one). |
| `DAL_Assess` | DAL compliance assessment. |
| `Doc_Metrics` | Docstring coverage metrics. |
| `Packages` | Scanned package vector. |
| `Path` | Output file path for VERIFICATION.md. |
| `Proof` | GNATprove proof summary. |
| `Tests` | Test result summary. |
