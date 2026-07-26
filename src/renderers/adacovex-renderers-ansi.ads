with Adacovex.Types;

--  Terminal ANSI renderer.
--  Produces a colored, human-readable report on standard output using
--  ANSI escape sequences for highlighting.
--  HLR-RENDER-ANSI: ANSI rendering

package Adacovex.Renderers.ANSI is
   pragma SPARK_Mode (On);

   --  Print a formatted report to standard output.
   procedure Render_Summary
     (Doc_Metrics  : Types.Docstring_Metrics;
      Proof        : Types.Proof_Summary;
      Tests        : Types.Test_Summary;
      DAL_Assess   : Types.DAL_Assessment;
      Packages     : Types.Package_Array;
      Pkg_Count    : Natural);

end Adacovex.Renderers.ANSI;
