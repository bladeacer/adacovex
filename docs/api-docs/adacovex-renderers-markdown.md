# Adacovex.Renderers.Markdown

Markdown report renderer.
Generates VERIFICATION.md (coverage, proof, test, compliance tables)
and TRACE.md (HLR to package traceability matrix).
HLR-RENDER-MD: Markdown report generation

> **Note:** All items in this package are public.

## Procedures

### procedure Generate_Trace_Matrix (Path : Standard.String; Packages : Adacovex.Types.Implementation.Package_Vectors.Vector) `[Pre]`

| Parameter | Description |
|-----------|-------------|
| `Packages` | Scanned package vector. |
| `Path` | Output file path for TRACE.md. |

### procedure Generate_Verification_Report (Path : Standard.String; Doc_Metrics : Adacovex.Types.Docstring_Metrics; Proof : Adacovex.Types.Proof_Summary; Tests : Adacovex.Types.Implementation.Test_Summary; DAL_Assess : Adacovex.Types.Implementation.DAL_Assessment; Packages : Adacovex.Types.Implementation.Package_Vectors.Vector) `[Pre]`

| Parameter | Description |
|-----------|-------------|
| `DAL_Assess` | DAL compliance assessment. |
| `Doc_Metrics` | Docstring coverage metrics. |
| `Packages` | Scanned package vector. |
| `Path` | Output file path for VERIFICATION.md. |
| `Proof` | GNATprove proof summary. |
| `Tests` | Test result summary. |
