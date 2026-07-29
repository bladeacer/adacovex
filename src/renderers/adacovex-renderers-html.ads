with Adacovex.Types;

--  HTML dashboard and JSON API renderer.
--  Produces a self-contained HTML page with embedded CSS for the web
--  dashboard and a lightweight JSON endpoint for programmatic access.
--  HLR-RENDER-HTML: HTML dashboard and JSON API

package Adacovex.Renderers.HTML is

   --  Render a full HTML dashboard page with cards for all metrics.
   --  Produces a self-contained HTML page (with embedded CSS) showing
   --  SPARK proof status, test results, DO-178C compliance, and package
   --  coverage in a card-based layout.
   --  @param Doc_Metrics  Docstring coverage metrics.
   --  @param Proof  GNATprove proof summary.
   --  @param Tests  Test result summary.
   --  @param DAL_Assess  DAL compliance assessment.
   --  @param Packages  Scanned package vector.
   --  @return HTML dashboard page.
   function Render_Dashboard
     (Doc_Metrics : Types.Docstring_Metrics;
      Proof       : Types.Proof_Summary;
      Tests       : Types.Test_Summary;
      DAL_Assess  : Types.DAL_Assessment;
      Packages    : Types.Package_Vectors.Vector) return String
   with Post => Render_Dashboard'Result'Length > 0, Global => null;

   --  Render a JSON object with key metric values.
   --  Produces a lightweight JSON payload containing docstring coverage,
   --  proof results, test summary, and DO-178C status for programmatic
   --  consumption by the API endpoint.
   --  @param Doc_Metrics  Docstring coverage metrics.
   --  @param Proof  GNATprove proof summary.
   --  @param Tests  Test result summary.
   --  @param DAL_Assess  DAL compliance assessment.
   --  @return JSON string with key metrics.
   function Render_Metrics_JSON
     (Doc_Metrics : Types.Docstring_Metrics;
      Proof       : Types.Proof_Summary;
      Tests       : Types.Test_Summary;
      DAL_Assess  : Types.DAL_Assessment) return String
   with Post => Render_Metrics_JSON'Result'Length > 0, Global => null;

end Adacovex.Renderers.HTML;
