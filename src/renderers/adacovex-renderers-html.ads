with Adacovex.Types;

--  HTML dashboard and JSON API renderer.
--  Produces a self-contained HTML page with embedded CSS for the web
--  dashboard and a lightweight JSON endpoint for programmatic access.
--  HLR-RENDER-HTML: HTML dashboard and JSON API

package Adacovex.Renderers.HTML is

   --  Render a full HTML dashboard page with cards for all metrics.
   --  Produces a self-contained HTML page (with embedded CSS) showing
   --  SPARK proof status, test results, compliance, and package coverage in
   --  a card-based layout.  The compliance card is standard-aware: it prints
   --  the selected standard's level label, or one row per standard when
   --  All_Standards is True.  The page supports light / dark / system themes:
   --  colors are driven by CSS custom properties, the initial theme follows
   --  Theme (System_Theme follows the browser's prefers-color-scheme), a
   --  header dropdown switches live between light, dark, and system, and a
   --  Save settings button persists the choice in localStorage.  Theme
   --  resolution on load: explicit CLI light/dark wins, then localStorage,
   --  then the system preference.
   --  @param Doc_Metrics  Docstring coverage metrics.
   --  @param Proof  GNATprove proof summary.
   --  @param Tests  Test result summary.
   --  @param DAL_Assess  DAL compliance assessment.
   --  @param Packages  Scanned package vector.
   --  @param All_Standards  Render every standard (else the selected one).
   --  @param Theme  Initial dashboard theme (system/light/dark).
   --  @return HTML dashboard page.
   function Render_Dashboard
     (Doc_Metrics   : Types.Docstring_Metrics;
      Proof         : Types.Proof_Summary;
      Tests         : Types.Implementation.Test_Summary;
      DAL_Assess    : Types.Implementation.DAL_Assessment;
      Packages      : Types.Implementation.Package_Vectors.Vector;
      All_Standards : Boolean := False;
      Theme         : Types.Dashboard_Theme := Types.System_Theme)
      return String
   with Post => Render_Dashboard'Result'Length > 0, Global => null;

   --  Render the Chart.css metrics section (multiple chart cards) for the
   --  dashboard: a donut of SPARK proof (proved vs total VCs), a column
   --  chart of proved checks per category, a bar chart of the test
   --  categories (pass vs fail), and a docstring-coverage bar.  The markup
   --  uses the vendored Charts.css framework (resources/charts.min.css,
   --  inlined into the dashboard template) so the page stays
   --  self-contained and dependency-free at runtime.
   --  @param Doc_Metrics  Docstring coverage metrics.
   --  @param Proof  GNATprove proof summary.
   --  @param Tests  Test result summary.
   --  @return HTML fragment with the chart cards.
   function Render_Charts
     (Doc_Metrics : Types.Docstring_Metrics;
      Proof       : Types.Proof_Summary;
      Tests       : Types.Implementation.Test_Summary) return String
   with Post => Render_Charts'Result'Length > 0, Global => null;

   --  Render the dependency graph as a JSON object for /api/deps.
   --  Serializes the resolved component vector (root at index 1 plus its
   --  transitive closure) with name, version, scope, license, PURL, kind,
   --  and the parent index, so consumers can reconstruct the tree.
   --  @param Graph  Dependency graph component vector.
   --  @return JSON string with a "dependencies" array.
   function Render_Deps_JSON
     (Graph : Types.Implementation.Component_Vectors.Vector) return String
   with Post => Render_Deps_JSON'Result'Length > 0, Global => null;

   --  Render a JSON object with key metric values.
   --  Produces a lightweight JSON payload containing docstring coverage,
   --  proof results, test summary, and compliance status for programmatic
   --  consumption by the API endpoint.  Includes the selected standard and
   --  its level label, plus a per-standard "standards" object when
   --  All_Standards is True.
   --  @param Doc_Metrics  Docstring coverage metrics.
   --  @param Proof  GNATprove proof summary.
   --  @param Tests  Test result summary.
   --  @param DAL_Assess  DAL compliance assessment.
   --  @param All_Standards  Emit a per-standard breakdown (else one standard).
   --  @return JSON string with key metrics.
   function Render_Metrics_JSON
     (Doc_Metrics   : Types.Docstring_Metrics;
      Proof         : Types.Proof_Summary;
      Tests         : Types.Implementation.Test_Summary;
      DAL_Assess    : Types.Implementation.DAL_Assessment;
      All_Standards : Boolean := False) return String
   with Post => Render_Metrics_JSON'Result'Length > 0, Global => null;

end Adacovex.Renderers.HTML;
