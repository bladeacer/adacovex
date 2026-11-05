# Adacovex.Renderers.HTML

HTML dashboard and JSON API renderer.
Produces a self-contained HTML page with embedded CSS for the web
dashboard and a lightweight JSON endpoint for programmatic access.
HLR-RENDER-HTML: HTML dashboard and JSON API

**See also:** [Web dashboard](../usage/dashboard.md)

> **Note:** All items in this package are public.

## Functions

### function Render_Charts (Doc_Metrics : Adacovex.Types.Docstring_Metrics; Proof : Adacovex.Types.Proof_Summary; Tests : Adacovex.Types.Implementation.Test_Summary; DAL_Assess : Adacovex.Types.Implementation.DAL_Assessment) return Standard.String `[Post]` `[Global]`

| Parameter | Description |
|-----------|-------------|
| `DAL_Assess` | DAL compliance assessment (Robustness Comp axis). |
| `Doc_Metrics` | Docstring coverage metrics. |
| `Proof` | GNATprove proof summary. |
| `Tests` | Test result summary. |

**Returns:** HTML fragment with the chart cards.

### function Render_Charts (Doc_Metrics : Adacovex.Types.Docstring_Metrics; Proof : Adacovex.Types.Proof_Summary; Tests : Adacovex.Types.Implementation.Test_Summary; DAL_Assess : Adacovex.Types.Implementation.DAL_Assessment; Graph : Adacovex.Types.Implementation.Component_Vectors.Vector) return Standard.String `[Post]` `[Global]`

| Parameter | Description |
|-----------|-------------|
| `DAL_Assess` | DAL compliance assessment (drives the Robustness |
| `Doc_Metrics` | Docstring coverage metrics. |
| `Graph` | Dependency graph for the scope ring (empty = skip). |
| `Proof` | GNATprove proof summary. |
| `Tests` | Test result summary. |

**Returns:** HTML fragment with the chart cards.

### function Render_Dashboard (Doc_Metrics : Adacovex.Types.Docstring_Metrics; Proof : Adacovex.Types.Proof_Summary; Tests : Adacovex.Types.Implementation.Test_Summary; DAL_Assess : Adacovex.Types.Implementation.DAL_Assessment; Packages : Adacovex.Types.Implementation.Package_Vectors.Vector; Graph : Adacovex.Types.Implementation.Component_Vectors.Vector; All_Standards : Standard.Boolean; Theme : Adacovex.Types.Dashboard_Theme; Spark_OK : Standard.Boolean; Spark_Totals : Adacovex.Types.Implementation.Spark_Coverage_Totals; Spark_Groups : Adacovex.Types.Implementation.Spark_Group_Vectors.Vector) return Standard.String `[Post]` `[Global]`

| Parameter | Description |
|-----------|-------------|
| `All_Standards` | Render every standard (else the selected one). |
| `DAL_Assess` | DAL compliance assessment. |
| `Doc_Metrics` | Docstring coverage metrics. |
| `Graph` | Resolved dependency graph (for the Dependencies tab). |
| `Packages` | Scanned package vector. |
| `Proof` | GNATprove proof summary. |
| `Spark_Groups` | Per-group SPARK coverage rollups. |
| `Spark_OK` | True when the SPARK coverage report was read. |
| `Spark_Totals` | Whole-tree SPARK coverage rollup. |
| `Tests` | Test result summary. |
| `Theme` | Initial dashboard theme (system/light/dark). |

**Returns:** HTML dashboard page.

### function Render_Dashboard (Doc_Metrics : Adacovex.Types.Docstring_Metrics; Proof : Adacovex.Types.Proof_Summary; Tests : Adacovex.Types.Implementation.Test_Summary; DAL_Assess : Adacovex.Types.Implementation.DAL_Assessment; Packages : Adacovex.Types.Implementation.Package_Vectors.Vector; All_Standards : Standard.Boolean; Theme : Adacovex.Types.Dashboard_Theme; Spark_OK : Standard.Boolean; Spark_Totals : Adacovex.Types.Implementation.Spark_Coverage_Totals; Spark_Groups : Adacovex.Types.Implementation.Spark_Group_Vectors.Vector) return Standard.String `[Post]` `[Global]`

| Parameter | Description |
|-----------|-------------|
| `All_Standards` | Render every standard. |
| `DAL_Assess` | DAL compliance assessment. |
| `Doc_Metrics` | Docstring coverage metrics. |
| `Packages` | Scanned package vector. |
| `Proof` | GNATprove proof summary. |
| `Spark_Groups` | Per-group SPARK coverage rollups. |
| `Spark_OK` | True when the SPARK coverage report was read. |
| `Spark_Totals` | Whole-tree SPARK coverage rollup. |
| `Tests` | Test result summary. |
| `Theme` | Initial dashboard theme. |

**Returns:** HTML dashboard page.

### function Render_Deps_HTML (Graph : Adacovex.Types.Implementation.Component_Vectors.Vector) return Standard.String `[Post]` `[Global]`

| Parameter | Description |
|-----------|-------------|
| `Graph` | Dependency graph component vector. |

**Returns:** HTML fragment for the deps tab.

### function Render_Deps_JSON (Graph : Adacovex.Types.Implementation.Component_Vectors.Vector) return Standard.String `[Post]` `[Global]`

| Parameter | Description |
|-----------|-------------|
| `Graph` | Dependency graph component vector. |

**Returns:** JSON string with a "dependencies" array.

### function Render_Endpoints_JSON return Standard.String `[Post]` `[Global]`

**Returns:** JSON object with an "endpoints" array.

### function Render_Metrics_JSON (Doc_Metrics : Adacovex.Types.Docstring_Metrics; Proof : Adacovex.Types.Proof_Summary; Tests : Adacovex.Types.Implementation.Test_Summary; DAL_Assess : Adacovex.Types.Implementation.DAL_Assessment; All_Standards : Standard.Boolean) return Standard.String `[Post]` `[Global]`

| Parameter | Description |
|-----------|-------------|
| `All_Standards` | Emit a per-standard breakdown (else one standard). |
| `DAL_Assess` | DAL compliance assessment. |
| `Doc_Metrics` | Docstring coverage metrics. |
| `Proof` | GNATprove proof summary. |
| `Tests` | Test result summary. |

**Returns:** JSON string with key metrics.

### function Render_Spark_Coverage_HTML (Totals : Adacovex.Types.Implementation.Spark_Coverage_Totals; Groups : Adacovex.Types.Implementation.Spark_Group_Vectors.Vector; Group : Adacovex.Types.Spark_Group_Kind; OK : Standard.Boolean) return Standard.String `[Post]` `[Global]`

| Parameter | Description |
|-----------|-------------|
| `Group` | Group kind the table is keyed on. |
| `Groups` | Per-group SPARK coverage rollups. |
| `OK` | True when the coverage report was read. |
| `Totals` | Whole-tree SPARK coverage rollup. |

**Returns:** HTML fragment for the Proof tab.

### function Render_Spark_Coverage_JSON (Totals : Adacovex.Types.Implementation.Spark_Coverage_Totals; Groups : Adacovex.Types.Implementation.Spark_Group_Vectors.Vector; Group : Adacovex.Types.Spark_Group_Kind) return Standard.String `[Post]` `[Global]`

| Parameter | Description |
|-----------|-------------|
| `Group` | Group kind the table is keyed on. |
| `Groups` | Per-group SPARK coverage rollups. |
| `Totals` | Whole-tree SPARK coverage rollup. |

**Returns:** JSON string with the coverage payload.
