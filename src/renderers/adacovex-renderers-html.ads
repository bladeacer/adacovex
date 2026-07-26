with Adacovex.Types;

--  HTML dashboard and JSON API renderer.
--  Produces a self-contained HTML page with embedded CSS for the web
--  dashboard and a lightweight JSON endpoint for programmatic access.
--  HLR-RENDER-HTML: HTML dashboard and JSON API

package Adacovex.Renderers.HTML is
   pragma SPARK_Mode (On);

   --  Render a full HTML dashboard page with cards for all metrics.
   function Render_Dashboard
     (Doc_Metrics : Types.Docstring_Metrics;
      Proof       : Types.Proof_Summary;
      Tests       : Types.Test_Summary;
      DAL_Assess  : Types.DAL_Assessment;
      Packages    : Types.Package_Array;
      Pkg_Count   : Natural) return String;

   --  Render a JSON object with key metric values.
   function Render_Metrics_JSON
     (Doc_Metrics : Types.Docstring_Metrics;
      Proof       : Types.Proof_Summary;
      Tests       : Types.Test_Summary;
      DAL_Assess  : Types.DAL_Assessment) return String;

end Adacovex.Renderers.HTML;
