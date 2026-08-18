# Adacovex.Renderers.HTML

HTML dashboard and JSON API renderer.
Produces a self-contained HTML page with embedded CSS for the web
dashboard and a lightweight JSON endpoint for programmatic access.
HLR-RENDER-HTML: HTML dashboard and JSON API

> **Note:** All items in this package are public.

## Functions

### function Render_Dashboard (Doc_Metrics : Adacovex.Types.Docstring_Metrics; Proof : Adacovex.Types.Proof_Summary; Tests : Adacovex.Types.Implementation.Test_Summary; DAL_Assess : Adacovex.Types.Implementation.DAL_Assessment; Packages : Adacovex.Types.Implementation.Package_Vectors.Vector; All_Standards : Standard.Boolean; Theme : Adacovex.Types.Dashboard_Theme) return Standard.String `[Post]` `[Global]`

| Parameter | Description |
|-----------|-------------|
| `All_Standards` | Render every standard (else the selected one). |
| `DAL_Assess` | DAL compliance assessment. |
| `Doc_Metrics` | Docstring coverage metrics. |
| `Packages` | Scanned package vector. |
| `Proof` | GNATprove proof summary. |
| `Tests` | Test result summary. |
| `Theme` | Initial dashboard theme (system/light/dark). |

**Returns:** HTML dashboard page.

### function Render_Metrics_JSON (Doc_Metrics : Adacovex.Types.Docstring_Metrics; Proof : Adacovex.Types.Proof_Summary; Tests : Adacovex.Types.Implementation.Test_Summary; DAL_Assess : Adacovex.Types.Implementation.DAL_Assessment; All_Standards : Standard.Boolean) return Standard.String `[Post]` `[Global]`

| Parameter | Description |
|-----------|-------------|
| `All_Standards` | Emit a per-standard breakdown (else one standard). |
| `DAL_Assess` | DAL compliance assessment. |
| `Doc_Metrics` | Docstring coverage metrics. |
| `Proof` | GNATprove proof summary. |
| `Tests` | Test result summary. |

**Returns:** JSON string with key metrics.
