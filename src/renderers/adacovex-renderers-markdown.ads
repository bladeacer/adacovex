with Adacovex.Types;

package Adacovex.Renderers.Markdown is

   procedure Generate_Verification_Report
     (Path         : String;
      Doc_Metrics  : Types.Docstring_Metrics;
      Proof        : Types.Proof_Summary;
      Tests        : Types.Test_Summary;
      DAL_Assess   : Types.DAL_Assessment;
      Packages     : Types.Package_Array;
      Pkg_Count    : Natural);

   procedure Generate_Trace_Matrix
     (Path         : String;
      Packages     : Types.Package_Array;
      Pkg_Count    : Natural);

end Adacovex.Renderers.Markdown;
