with Adacovex.Types;
use Adacovex.Types, Adacovex.Types.Implementation;
with Adacovex.Compliance.DAL;

package body Adacovex_DAL_Tests is

   procedure Run (R : in out Adacovex.Test_Support.Runner'Class) is
   begin
      declare
         Assessment : DAL_Assessment;
      begin
         Assessment :=
           (Target_DAL             => DAL_C,
            Status                 => Achieved,
            HLR_Total              => 10,
            HLR_Found              => 10,
            LLR_Total              => 5,
            LLR_Found              => 5,
            All_Subprograms_Traced => True,
            Orphan_Tags            => False,
            Tests_Passing          => True,
            Min_SPARK_Level_Met    => True,
            Failed_Reasons         => DAL_Failure_Vectors.Empty_Vector);
         R.Check
           (Adacovex.Compliance.DAL.Is_DAL_Achieved (Assessment),
            "Is_DAL_Achieved True when Status = Achieved");
      end;

      declare
         Assessment : DAL_Assessment;
      begin
         Assessment :=
           (Target_DAL             => DAL_C,
            Status                 => Unmet,
            HLR_Total              => 10,
            HLR_Found              => 5,
            LLR_Total              => 5,
            LLR_Found              => 3,
            All_Subprograms_Traced => False,
            Orphan_Tags            => True,
            Tests_Passing          => False,
            Min_SPARK_Level_Met    => False,
            Failed_Reasons         => DAL_Failure_Vectors.Empty_Vector);
         R.Check
           (not Adacovex.Compliance.DAL.Is_DAL_Achieved (Assessment),
            "Is_DAL_Achieved False when Status = Unmet");
      end;
   end Run;

end Adacovex_DAL_Tests;
