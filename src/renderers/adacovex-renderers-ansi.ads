with Adacovex.Types;

package Adacovex.Renderers.ANSI is

   procedure Render_Summary
     (Doc_Metrics  : Types.Docstring_Metrics;
      Proof        : Types.Proof_Summary;
      Tests        : Types.Test_Summary;
      DAL_Assess   : Types.DAL_Assessment;
      Packages     : Types.Package_Array;
      Pkg_Count    : Natural);

end Adacovex.Renderers.ANSI;
