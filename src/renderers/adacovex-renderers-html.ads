with Adacovex.Types;

package Adacovex.Renderers.HTML is

   function Render_Dashboard
     (Doc_Metrics : Types.Docstring_Metrics;
      Proof       : Types.Proof_Summary;
      Tests       : Types.Test_Summary;
      DAL_Assess  : Types.DAL_Assessment;
      Packages    : Types.Package_Array;
      Pkg_Count   : Natural) return String;

   function Render_Metrics_JSON
     (Doc_Metrics : Types.Docstring_Metrics;
      Proof       : Types.Proof_Summary;
      Tests       : Types.Test_Summary;
      DAL_Assess  : Types.DAL_Assessment) return String;

end Adacovex.Renderers.HTML;
