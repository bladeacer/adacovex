with Adacovex.Types;

--  HTML dashboard and JSON API renderer.
--  Produces a self-contained HTML page with embedded CSS for the web
--  dashboard and a lightweight JSON endpoint for programmatic access.
--  HLR-RENDER-HTML: HTML dashboard and JSON API

package Adacovex.Renderers.HTML is

   --  Render a full HTML dashboard page with cards for all metrics.
   --  Produces a self-contained HTML page (with embedded CSS) showing
   --  SPARK proof status, test results, compliance, and package coverage.
   --  The page uses a card-based layout.  The compliance card is
   --  standard-aware.  It prints the selected standard's level label.  When
   --  All_Standards is True, it prints one row per standard.  The page
   --  supports light, dark, and system themes.  Colours come from CSS custom
   --  properties.  The initial theme follows Theme (System_Theme follows the
   --  browser's prefers-color-scheme).  A header dropdown switches between
   --  light, dark, and system.  A Save settings button stores the choice in
   --  localStorage.  On load, theme resolution selects the explicit CLI
   --  light/dark first.  Then it uses localStorage.  Then it uses the system
   --  preference.  Content is organised into clickable tabs (Overview, Proof,
   --  Tests, Compliance, Dependencies, Charts).  The dependency graph has its
   --  own page.  It does not share the card stack.
   --  @param Doc_Metrics  Docstring coverage metrics.
   --  @param Proof  GNATprove proof summary.
   --  @param Tests  Test result summary.
   --  @param DAL_Assess  DAL compliance assessment.
   --  @param Packages  Scanned package vector.
   --  @param Graph  Resolved dependency graph (for the Dependencies tab).
   --  @param All_Standards  Render every standard (else the selected one).
   --  @param Theme  Initial dashboard theme (system/light/dark).
   --  @return HTML dashboard page.
   function Render_Dashboard
     (Doc_Metrics   : Types.Docstring_Metrics;
      Proof         : Types.Proof_Summary;
      Tests         : Types.Implementation.Test_Summary;
      DAL_Assess    : Types.Implementation.DAL_Assessment;
      Packages      : Types.Implementation.Package_Vectors.Vector;
      Graph         : Types.Implementation.Component_Vectors.Vector;
      All_Standards : Boolean := False;
      Theme         : Types.Dashboard_Theme := Types.System_Theme)
      return String
   with Post => Render_Dashboard'Result'Length > 0, Global => null;

   --  Backward-compatible wrapper that renders an empty dependency graph.
   --  @param Doc_Metrics  Docstring coverage metrics.
   --  @param Proof  GNATprove proof summary.
   --  @param Tests  Test result summary.
   --  @param DAL_Assess  DAL compliance assessment.
   --  @param Packages  Scanned package vector.
   --  @param All_Standards  Render every standard.
   --  @param Theme  Initial dashboard theme.
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

   --  Render the metrics charts section (multiple chart cards) for the
   --  dashboard.  The section shows a donut of SPARK proof (proved vs
   --  unproved VCs) and bars of proved checks per category.  It shows a
   --  bar chart of the test categories and a docstring-coverage meter, a
   --  donut of test pass/fail distribution, and a polar ring of dependency
   --  scopes.  The charts are hand-rolled (SVG-less CSS donuts and flex
   --  bars) so the page stays self-contained and dependency-free at
   --  runtime -- no external chart library is bundled.
   --  @param Doc_Metrics  Docstring coverage metrics.
   --  @param Proof  GNATprove proof summary.
   --  @param Tests  Test result summary.
   --  @param Graph  Dependency graph for the scope ring (empty = skip).
   --  @return HTML fragment with the chart cards.
   function Render_Charts
     (Doc_Metrics : Types.Docstring_Metrics;
      Proof       : Types.Proof_Summary;
      Tests       : Types.Implementation.Test_Summary;
      Graph       : Types.Implementation.Component_Vectors.Vector)
      return String
   with Post => Render_Charts'Result'Length > 0, Global => null;

   --  Backward-compatible wrapper without graph (no scope pie).
   --  @param Doc_Metrics  Docstring coverage metrics.
   --  @param Proof  GNATprove proof summary.
   --  @param Tests  Test result summary.
   --  @return HTML fragment with the chart cards.
   function Render_Charts
     (Doc_Metrics : Types.Docstring_Metrics;
      Proof       : Types.Proof_Summary;
      Tests       : Types.Implementation.Test_Summary) return String
   with Post => Render_Charts'Result'Length > 0, Global => null;

   --  Render the dependency graph as an interactive HTML tree for the
   --  Dependencies tab.  Groups components by parent index into a collapsible
   --  <details> tree with scope badges and a client-side filter input.
   --  @param Graph  Dependency graph component vector.
   --  @return HTML fragment for the deps tab.
   function Render_Deps_HTML
     (Graph : Types.Implementation.Component_Vectors.Vector) return String
   with Post => Render_Deps_HTML'Result'Length > 0, Global => null;

   --  Render the dependency graph as a JSON object for /api/deps.
   --  Serializes the resolved component vector (root at index 1 plus its
   --  transitive closure) with name, version, scope, licence, PURL, kind,
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
