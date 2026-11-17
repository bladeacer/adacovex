# Adacovex.Renderers.HTML

HTML dashboard and JSON API renderer.
Produces a self-contained HTML page with embedded CSS for the web
dashboard and a lightweight JSON endpoint for programmatic access.
HLR-RENDER-HTML: HTML dashboard and JSON API

**See also:** [Web dashboard](../usage/dashboard.md)

> **Note:** All items in this package are public.

## Functions

### function Render_Charts (Doc_Metrics : Adacovex.Types.Docstring_Metrics; Proof : Adacovex.Types.Proof_Summary; Tests : Adacovex.Types.Implementation.Test_Summary; DAL_Assess : Adacovex.Types.Implementation.DAL_Assessment) return Standard.String `[Post]` `[Global]`

> Backward-compatible wrapper without graph (no scope pie).

| Parameter | Description |
|-----------|-------------|
| `DAL_Assess` | DAL compliance assessment (Robustness Comp axis). |
| `Doc_Metrics` | Docstring coverage metrics. |
| `Proof` | GNATprove proof summary. |
| `Tests` | Test result summary. |

**Returns:** HTML fragment with the chart cards.

### function Render_Charts (Doc_Metrics : Adacovex.Types.Docstring_Metrics; Proof : Adacovex.Types.Proof_Summary; Tests : Adacovex.Types.Implementation.Test_Summary; DAL_Assess : Adacovex.Types.Implementation.DAL_Assessment; Graph : Adacovex.Types.Implementation.Component_Vectors.Vector) return Standard.String `[Post]` `[Global]`

> Render the metrics charts section (multiple chart cards) for the dashboard. The section shows a donut of SPARK proof (proved vs unproved VCs) and bars of proved checks per category. It shows a bar chart of the test categories and a docstring-coverage meter, a donut of test pass/fail distribution, and a polar ring of dependency scopes. The charts are hand-rolled (SVG-less CSS donuts and flex bars) so the page stays self-contained and dependency-free at runtime -- no external chart library is bundled.

| Parameter | Description |
|-----------|-------------|
| `DAL_Assess` | DAL compliance assessment (drives the Robustness Comp axis). |
| `Doc_Metrics` | Docstring coverage metrics. |
| `Graph` | Dependency graph for the scope ring (empty = skip). |
| `Proof` | GNATprove proof summary. |
| `Tests` | Test result summary. |

**Returns:** HTML fragment with the chart cards.

### function Render_Dashboard (Doc_Metrics : Adacovex.Types.Docstring_Metrics; Proof : Adacovex.Types.Proof_Summary; Tests : Adacovex.Types.Implementation.Test_Summary; DAL_Assess : Adacovex.Types.Implementation.DAL_Assessment; Packages : Adacovex.Types.Implementation.Package_Vectors.Vector; Graph : Adacovex.Types.Implementation.Component_Vectors.Vector; All_Standards : Standard.Boolean; Theme : Adacovex.Types.Dashboard_Theme; Spark_OK : Standard.Boolean; Spark_Totals : Adacovex.Types.Implementation.Spark_Coverage_Totals; Spark_Groups : Adacovex.Types.Implementation.Spark_Group_Vectors.Vector) return Standard.String `[Post]` `[Global]`

> Render a full HTML dashboard page with cards for all metrics. Produces a self-contained HTML page (with embedded CSS) showing SPARK proof status, test results, compliance, and package coverage. The page uses a card-based layout. The compliance card is standard-aware. It prints the selected standard's level label. When All_Standards is True, it prints one row per standard. The page supports light, dark, and system themes. Colours come from CSS custom properties. The initial theme follows Theme (System_Theme follows the browser's prefers-color-scheme). A header dropdown switches between light, dark, and system. A Save settings button stores the choice in localStorage. On load, theme resolution selects the explicit CLI light/dark first. Then it uses localStorage. Then it uses the system preference. Content is organised into clickable tabs (Overview, Proof, Tests, Compliance, Dependencies, Charts). The dependency graph has its own page. It does not share the card stack.

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

> Backward-compatible wrapper that renders an empty dependency graph.

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

> Render the dependency graph as an interactive HTML tree for the Dependencies tab. Groups components by parent index into a collapsible <details> tree with scope badges and a client-side filter input.

| Parameter | Description |
|-----------|-------------|
| `Graph` | Dependency graph component vector. |

**Returns:** HTML fragment for the deps tab.

### function Render_Deps_JSON (Graph : Adacovex.Types.Implementation.Component_Vectors.Vector) return Standard.String `[Post]` `[Global]`

> Render the dependency graph as a JSON object for /api/deps. Serializes the resolved component vector (root at index 1 plus its transitive closure) with name, version, scope, licence, PURL, kind, and the parent index, so consumers can reconstruct the tree.

| Parameter | Description |
|-----------|-------------|
| `Graph` | Dependency graph component vector. |

**Returns:** JSON string with a "dependencies" array.

### function Render_Endpoints_JSON return Standard.String `[Post]` `[Global]`

> Render the API endpoint catalog as JSON for /api/endpoints. Every route the --serve server dispatches on is listed once with its HTTP method, path, a machine kind (json / svg / text), its dashboard group, and a short description. It is the single source of truth the dashboard's API playground builds its UI from.

**Returns:** JSON object with an "endpoints" array.

### function Render_Metrics_JSON (Doc_Metrics : Adacovex.Types.Docstring_Metrics; Proof : Adacovex.Types.Proof_Summary; Tests : Adacovex.Types.Implementation.Test_Summary; DAL_Assess : Adacovex.Types.Implementation.DAL_Assessment; All_Standards : Standard.Boolean) return Standard.String `[Post]` `[Global]`

> Render a JSON object with key metric values. Produces a lightweight JSON payload containing docstring coverage, proof results, test summary, and compliance status for programmatic consumption by the API endpoint. Includes the selected standard and its level label, plus a per-standard "standards" object when All_Standards is True.

| Parameter | Description |
|-----------|-------------|
| `All_Standards` | Emit a per-standard breakdown (else one standard). |
| `DAL_Assess` | DAL compliance assessment. |
| `Doc_Metrics` | Docstring coverage metrics. |
| `Proof` | GNATprove proof summary. |
| `Tests` | Test result summary. |

**Returns:** JSON string with key metrics.

### function Render_Spark_Coverage_HTML (Totals : Adacovex.Types.Implementation.Spark_Coverage_Totals; Groups : Adacovex.Types.Implementation.Spark_Group_Vectors.Vector; Group : Adacovex.Types.Spark_Group_Kind; OK : Standard.Boolean) return Standard.String `[Post]` `[Global]`

> Render the SPARK coverage fragment for the Proof tab: one card with every metric side by side (statements, subprograms, VCs), the off-class breakdown with the three sub-classes as separate rows, and a per-group table. The work-queue row is highlighted, because it is the actionable backlog.

| Parameter | Description |
|-----------|-------------|
| `Group` | Group kind the table is keyed on. |
| `Groups` | Per-group SPARK coverage rollups. |
| `OK` | True when the coverage report was read. |
| `Totals` | Whole-tree SPARK coverage rollup. |

**Returns:** HTML fragment for the Proof tab.

### function Render_Spark_Coverage_JSON (Totals : Adacovex.Types.Implementation.Spark_Coverage_Totals; Groups : Adacovex.Types.Implementation.Spark_Group_Vectors.Vector; Group : Adacovex.Types.Spark_Group_Kind) return Standard.String `[Post]` `[Global]`

> Render the SPARK coverage payload for /api/spark: the whole-tree rollup (all three metrics with their numerators and denominators), the off-class breakdown, warning count, and one entry per group rollup. All counts are named fields, never bare percentages.

| Parameter | Description |
|-----------|-------------|
| `Group` | Group kind the table is keyed on. |
| `Groups` | Per-group SPARK coverage rollups. |
| `Totals` | Whole-tree SPARK coverage rollup. |

**Returns:** JSON string with the coverage payload.
