with Adacovex.Types;

--  Markdown report renderer.
--  Generates VERIFICATION.md (coverage, proof, test, compliance tables)
--  and TRACE.md (HLR-to-package traceability matrix).
--  HLR-RENDER-MD: Markdown report generation

package Adacovex.Renderers.Markdown is
   pragma SPARK_Mode (On);

   --  Write a full verification report to the given file path.
   procedure Generate_Verification_Report
     (Path         : String;
      Doc_Metrics  : Types.Docstring_Metrics;
      Proof        : Types.Proof_Summary;
      Tests        : Types.Test_Summary;
      DAL_Assess   : Types.DAL_Assessment;
      Packages     : Types.Package_Array;
      Pkg_Count    : Natural);

   --  Write a traceability matrix mapping packages to their HLR tags.
   procedure Generate_Trace_Matrix
     (Path         : String;
      Packages     : Types.Package_Array;
      Pkg_Count    : Natural);

end Adacovex.Renderers.Markdown;
