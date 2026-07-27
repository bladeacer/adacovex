with Adacovex.Types;
with Adacovex.Parsers.DO178C;
with Adacovex.Parsers.Source;

--  DO-178C DAL compliance assessment engine.
--  Evaluates HLR trace coverage, orphan tags, test passing status, and
--  minimum SPARK proof level to determine Achieved / Unmet status.
--  HLR-COMPLIANCE: DAL assessment
--  HLR-DAL-A: DAL-A compliance criteria
--  HLR-DAL-B: DAL-B compliance criteria
--  HLR-DAL-C: DAL-C compliance criteria
--  HLR-DAL-D: DAL-D compliance criteria
--  HLR-DAL-E: DAL-E compliance criteria

package Adacovex.Compliance.DAL is
   pragma SPARK_Mode (On);

   --  Run all DAL-C assessment checks against the scanned project data.
   --  Evaluates HLR trace coverage, orphan tag absence, test pass rate,
   --  and minimum SPARK proof level. Populates Assessment with pass/fail
   --  results and detailed failure reasons.
   procedure Assess_DAL_C
     (Target_Dir     : String;
      Packages       : Types.Package_Array;
      Pkg_Count      : Natural;
      Proof_Summary  : Types.Proof_Summary;
      Test_Summary   : Types.Test_Summary;
      Assessment     : out Types.DAL_Assessment)
     with Pre  => Pkg_Count <= Types.Max_Packages;

   --  Convenience test: return True iff Assessment.Status = Achieved.
   --  Equivalent to Assessment.Status = DAL_Status'Val (0).
   function Is_DAL_Achieved
     (Assessment : Types.DAL_Assessment) return Boolean
     with Global => null;

end Adacovex.Compliance.DAL;
