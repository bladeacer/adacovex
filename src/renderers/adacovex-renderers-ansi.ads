with Adacovex.Types;

--  Terminal ANSI renderer.
--  Produces a colored, human-readable report on standard output using
--  ANSI escape sequences for highlighting.
--  HLR-RENDER-ANSI: ANSI rendering

package Adacovex.Renderers.ANSI is
   pragma SPARK_Mode (On);

    --  Print a formatted report to standard output.
    --  Displays a color-coded summary of docstring coverage, proof results,
    --  test results, and DO-178C DAL compliance using ANSI escape sequences.
    --  @param Doc_Metrics  Docstring coverage metrics.
    --  @param Proof  GNATprove proof summary.
    --  @param Tests  Test result summary.
    --  @param DAL_Assess  DAL compliance assessment.
    --  @param Packages  Scanned package array.
    --  @param Pkg_Count  Number of packages.
    procedure Render_Summary
      (Doc_Metrics : Types.Docstring_Metrics;
       Proof       : Types.Proof_Summary;
       Tests       : Types.Test_Summary;
       DAL_Assess  : Types.DAL_Assessment;
       Packages    : Types.Package_Array;
       Pkg_Count   : Natural);

end Adacovex.Renderers.ANSI;
