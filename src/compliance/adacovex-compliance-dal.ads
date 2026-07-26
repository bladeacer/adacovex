with Adacovex.Types;
with Adacovex.Parsers.DO178C;
with Adacovex.Parsers.Source;

package Adacovex.Compliance.DAL is

   procedure Assess_DAL_C
     (Target_Dir     : String;
      Packages       : Types.Package_Array;
      Pkg_Count      : Natural;
      Proof_Summary  : Types.Proof_Summary;
      Test_Summary   : Types.Test_Summary;
      Assessment     : out Types.DAL_Assessment);

   function Is_DAL_Achieved
     (Assessment : Types.DAL_Assessment) return Boolean;

end Adacovex.Compliance.DAL;
