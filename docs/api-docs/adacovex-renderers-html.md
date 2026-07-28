# Adacovex.Renderers.HTML

Render a full HTML dashboard page with cards for all metrics.
Produces a self-contained HTML page (with embedded CSS) showing
SPARK proof status, test results, DO-178C compliance, and package
coverage in a card-based layout.
@param Doc_Metrics  Docstring coverage metrics.
@param Proof  GNATprove proof summary.
@param Tests  Test result summary.
@param DAL_Assess  DAL compliance assessment.
@param Packages  Scanned package array.
@param Pkg_Count  Number of packages.
@return HTML dashboard page.

> **Note:** All items in this package are public.

## Functions

### function Render_Dashboard (Doc_Metrics : Adacovex.Types.Docstring_Metrics; Proof : Adacovex.Types.Proof_Summary; Tests : Adacovex.Types.Test_Summary; DAL_Assess : Adacovex.Types.DAL_Assessment; Packages : Adacovex.Types.Package_Array; Pkg_Count : Standard.Natural) return Standard.String `[Post]` `[Global]`

| Parameter | Description |
|-----------|-------------|
| `DAL_Assess` | DAL compliance assessment. |
| `Doc_Metrics` | Docstring coverage metrics. |
| `Packages` | Scanned package array. |
| `Pkg_Count` | Number of packages. |
| `Proof` | GNATprove proof summary. |
| `Tests` | Test result summary. |

**Returns:** HTML dashboard page.

### function Render_Metrics_JSON (Doc_Metrics : Adacovex.Types.Docstring_Metrics; Proof : Adacovex.Types.Proof_Summary; Tests : Adacovex.Types.Test_Summary; DAL_Assess : Adacovex.Types.DAL_Assessment) return Standard.String `[Post]` `[Global]`

| Parameter | Description |
|-----------|-------------|
| `DAL_Assess` | DAL compliance assessment. |
| `Doc_Metrics` | Docstring coverage metrics. |
| `Proof` | GNATprove proof summary. |
| `Tests` | Test result summary. |

**Returns:** JSON string with key metrics.
