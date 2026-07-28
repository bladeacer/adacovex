with Adacovex.Types;

--  Markdown report renderer.
--  Generates VERIFICATION.md (coverage, proof, test, compliance tables)
--  and TRACE.md (HLR to package traceability matrix).
--  HLR-RENDER-MD: Markdown report generation

package Adacovex.Renderers.Markdown is
   pragma SPARK_Mode (On);

   --  Write a full verification report to the given file path.
   --  Generates a VERIFICATION.md file with sections for coverage analysis,
   --  proof results table, test summary, and DO-178C compliance status.
   --  @param Path  Output file path for VERIFICATION.md.
   --  @param Doc_Metrics  Docstring coverage metrics.
   --  @param Proof  GNATprove proof summary.
   --  @param Tests  Test result summary.
   --  @param DAL_Assess  DAL compliance assessment.
   --  @param Packages  Scanned package array.
   --  @param Pkg_Count  Number of packages.
   procedure Generate_Verification_Report
     (Path        : String;
      Doc_Metrics : Types.Docstring_Metrics;
      Proof       : Types.Proof_Summary;
      Tests       : Types.Test_Summary;
      DAL_Assess  : Types.DAL_Assessment;
      Packages    : Types.Package_Array;
      Pkg_Count   : Natural)
   with Pre => Path'Length > 0;

   --  Write a traceability matrix mapping packages to their HLR tags.
   --  Generates a TRACE.md file with a table listing each package and its
   --  associated HLR identifiers from source-code annotations.
   --  @param Path  Output file path for TRACE.md.
   --  @param Packages  Scanned package array.
   --  @param Pkg_Count  Number of packages.
   procedure Generate_Trace_Matrix
     (Path : String; Packages : Types.Package_Array; Pkg_Count : Natural)
   with Pre => Path'Length > 0;

end Adacovex.Renderers.Markdown;
