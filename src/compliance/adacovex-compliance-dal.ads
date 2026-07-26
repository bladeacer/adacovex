with Adacovex.Types;
with Adacovex.Parsers.DO178C;
with Adacovex.Parsers.Source;

--  DO-178C DAL compliance assessment engine.
--  Evaluates HLR trace coverage, orphan tags, test passing status, and
--  minimum SPARK proof level to determine Achieved / Unmet status.

package Adacovex.Compliance.DAL is

   --  Run all DAL-C assessment checks against the scanned project data.
   procedure Assess_DAL_C
     (Target_Dir     : String;
      Packages       : Types.Package_Array;
      Pkg_Count      : Natural;
      Proof_Summary  : Types.Proof_Summary;
      Test_Summary   : Types.Test_Summary;
      Assessment     : out Types.DAL_Assessment);

   --  Convenience test: return True iff Assessment.Status = Achieved.
   function Is_DAL_Achieved
     (Assessment : Types.DAL_Assessment) return Boolean;

end Adacovex.Compliance.DAL;
