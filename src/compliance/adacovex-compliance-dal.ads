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

    --  Run DAL compliance assessment for any DAL level (A-E).
    --  Evaluates HLR trace coverage, orphan tag absence, test pass rate,
    --  and minimum SPARK proof level (per-level criteria). Populates
    --  Assessment with pass/fail results and detailed failure reasons.
    --  @param Level  Target DAL level (A-E).
    --  @param Target_Dir  Project root directory.
    --  @param Packages  Scanned package array.
    --  @param Pkg_Count  Number of packages.
    --  @param Proof_Summary  GNATprove proof results.
    --  @param Test_Summary  Test run results.
    --  @param Assessment  Output DAL assessment record.
    procedure Assess_DAL
      (Level         : Types.DAL_Level;
       Target_Dir    : String;
       Packages      : Types.Package_Array;
       Pkg_Count     : Natural;
       Proof_Summary : Types.Proof_Summary;
       Test_Summary  : Types.Test_Summary;
       Assessment    : out Types.DAL_Assessment)
    with Pre => Pkg_Count <= Types.Max_Packages;

    --  Convenience test: return True if Assessment.Status = Achieved.
    --  Equivalent to Assessment.Status = DAL_Status'Val (0).
    --  @param Assessment  DAL assessment record.
    --  @return True if Assessment.Status = Achieved.
    function Is_DAL_Achieved (Assessment : Types.DAL_Assessment) return Boolean
    with Global => null;

end Adacovex.Compliance.DAL;
