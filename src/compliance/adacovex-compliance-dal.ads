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

   use type Types.DAL_Level;

   --  Run DAL compliance assessment for any DAL level (A-E).
   --  Evaluates HLR trace coverage, orphan tag absence, test pass rate,
   --  and minimum SPARK proof level (per-level criteria). The routine
   --  populates Assessment with pass/fail results and detailed failure reasons.
   --  @param Level  Target DAL level (A-E).
   --  @param Target_Dir  Project root directory.
   --  @param Packages  Scanned package vector.
   --  @param Proof_Summary  GNATprove proof results.
   --  @param Test_Summary  Test run results.
   --  @param Assessment  Output DAL assessment record.
   --  @param Use_Cache  When True the HLR.md/LLR.md parses are served from
   --    the on-disk result cache when unchanged; when False they are always
   --    re-parsed (--no-cache).
   procedure Assess_DAL
     (Level         : Types.DAL_Level;
      Target_Dir    : String;
      Packages      : Types.Implementation.Package_Vectors.Vector;
      Proof_Summary : Types.Proof_Summary;
      Test_Summary  : Types.Implementation.Test_Summary;
      Assessment    : out Types.Implementation.DAL_Assessment;
      Use_Cache     : Boolean := False);

   --  Convenience test: if Assessment.Status = Achieved, return True.
   --  Equivalent to Assessment.Status = DAL_Status'Val (0).
   --  @param Assessment  DAL assessment record.
   --  @return True if Assessment.Status = Achieved.
   function Is_DAL_Achieved
     (Assessment : Types.Implementation.DAL_Assessment) return Boolean
   with Global => null;

   --  Minimum SPARK proof level required for a target DAL level.
   --  DAL-A needs Gold, DAL-B Silver, DAL-C Bronze, and DAL-D/DAL-E Stone.
   --  @param Level  Target DAL level (A-E).
   --  @return The minimum SPARK level that satisfies the criteria of the level.
   function Min_SPARK_For (Level : Types.DAL_Level) return Types.SPARK_Level
   with
     SPARK_Mode => On,
     Post       => Min_SPARK_For'Result in Types.Stone .. Types.Gold,
     Global     => null;

   --  Returns True when the DAL level requires a passing test suite. Only
   --  DAL-E does not need the test criterion.
   --  @param Level  Target DAL level (A-E).
   --  @return True unless Level is DAL-E.
   function Need_Tests (Level : Types.DAL_Level) return Boolean
   with
     SPARK_Mode => On,
     Post       => Need_Tests'Result = not (Level = Types.DAL_E),
     Global     => null;

   --  Run a standard-aware assessment. The routine delegates to Assess_DAL.
   --  The evidence checks are identical across DO-178C, ISO 26262, and
   --  IEC 62304. It then records the standard of the level label. Renderers
   --  can then print "ASIL B" or "Class A" instead of "DAL C".
   --  @param Standard  Compliance standard (DO_178C, ISO_26262, IEC_62304).
   --  @param Level  Rigor tier (reused DAL level A-E).
   --  @param Target_Dir  Project root directory.
   --  @param Packages  Scanned package vector.
   --  @param Proof_Summary  GNATprove proof results.
   --  @param Test_Summary  Test run results.
   --  @param Assessment  Output assessment record (Standard field set).
   --  @param Use_Cache  When True the HLR.md/LLR.md parses are served from
   --    the on-disk result cache when unchanged (see Assess_DAL).
   procedure Assess_Standard
     (Standard      : Types.Compliance_Standard;
      Level         : Types.DAL_Level;
      Target_Dir    : String;
      Packages      : Types.Implementation.Package_Vectors.Vector;
      Proof_Summary : Types.Proof_Summary;
      Test_Summary  : Types.Implementation.Test_Summary;
      Assessment    : out Types.Implementation.DAL_Assessment;
      Use_Cache     : Boolean := False);

end Adacovex.Compliance.DAL;
