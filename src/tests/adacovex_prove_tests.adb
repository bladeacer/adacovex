with Ada.Text_IO;    use Ada.Text_IO;
with Adacovex.Types; use Adacovex.Types;
with Adacovex.Parsers.GNATprove;

package body Adacovex_Prove_Tests is

   procedure Run (R : in out Adacovex.Test_Support.Runner'Class) is
   begin
      declare
         S : Proof_Summary;
      begin
         S := (Functional_Ct => 5, Functional_Proved => 5, others => <>);
         R.Check
           (Adacovex.Parsers.GNATprove.Determine_SPARK_Level (S) = Platinum,
            "Determine_SPARK_Level: Platinum");
      end;

      declare
         S : Proof_Summary;
      begin
         S :=
           (Runtime_Checks => 10,
            Runtime_Proved => 10,
            Assertions     => 5,
            Assert_Proved  => 5,
            others         => <>);
         R.Check
           (Adacovex.Parsers.GNATprove.Determine_SPARK_Level (S) = Gold,
            "Determine_SPARK_Level: Gold");
      end;

      declare
         S : Proof_Summary;
      begin
         S := (Unproved => 1, others => <>);
         R.Check
           (Adacovex.Parsers.GNATprove.Determine_SPARK_Level (S) = Silver,
            "Determine_SPARK_Level: Silver (unproved > 0)");
      end;

      declare
         S : Proof_Summary;
      begin
         S :=
           (Runtime_Checks => 10,
            Runtime_Proved => 10,
            Assertions     => 5,
            Assert_Proved  => 3,
            others         => <>);
         R.Check
           (Adacovex.Parsers.GNATprove.Determine_SPARK_Level (S) = Silver,
            "Determine_SPARK_Level: Silver (assertions not met)");
      end;

      declare
         S : Proof_Summary;
      begin
         S :=
           (Flow_Checks    => 7,
            Flow_Proved    => 7,
            Runtime_Checks => 10,
            Runtime_Proved => 5,
            others         => <>);
         R.Check
           (Adacovex.Parsers.GNATprove.Determine_SPARK_Level (S) = Bronze,
            "Determine_SPARK_Level: Bronze");
      end;

      declare
         S : Proof_Summary;
      begin
         S := (Runtime_Checks => 1, Flow_Checks => 1, others => <>);
         R.Check
           (Adacovex.Parsers.GNATprove.Determine_SPARK_Level (S) = Stone,
            "Determine_SPARK_Level: Stone");
      end;

      declare
         F       : File_Type;
         Summary : Proof_Summary;
         Success : Boolean;
      begin
         Create (F, Out_File, "/tmp/adacovex_test_prove_out.txt");
         Put_Line (F, "   Flow Dependencies            7       7 (100%)");
         Put_Line (F, "   Run-time Checks             15      15 (100%)");
         Put_Line (F, "   Assertions                   2       2 (100%)");
         Put_Line (F, "   Functional Contracts         5       5 (100%)");
         Put_Line (F, "   All checks proved           29      29 (100%)");
         Put_Line
           (F,
            "   Total                    29       0      29       0       .");
         Close (F);

         Adacovex.Parsers.GNATprove.Parse_Prove_Out
           ("/tmp/adacovex_test_prove_out.txt", Summary, Success);

         R.Check (Success, "Parse_Prove_Out: success");
         R.Check (Summary.Flow_Checks = 7, "Parse_Prove_Out: Flow_Checks = 7");
         R.Check (Summary.Flow_Proved = 7, "Parse_Prove_Out: Flow_Proved = 7");
         R.Check
           (Summary.Runtime_Checks = 15,
            "Parse_Prove_Out: Runtime_Checks = 15");
         R.Check
           (Summary.Runtime_Proved = 15,
            "Parse_Prove_Out: Runtime_Proved = 15");
         R.Check (Summary.Assertions = 2, "Parse_Prove_Out: Assertions = 2");
         R.Check
           (Summary.Assert_Proved = 2, "Parse_Prove_Out: Assert_Proved = 2");
         R.Check
           (Summary.Functional_Ct = 5, "Parse_Prove_Out: Functional_Ct = 5");
         R.Check
           (Summary.Functional_Proved = 5,
            "Parse_Prove_Out: Functional_Proved = 5");
         R.Check (Summary.Total_VCs = 29, "Parse_Prove_Out: Total_VCs = 29");
         R.Check (Summary.Proved_VCs = 29, "Parse_Prove_Out: Proved_VCs = 29");
         R.Check (Summary.Unproved = 0, "Parse_Prove_Out: Unproved = 0");
         R.Check
           (Summary.Level = Platinum, "Parse_Prove_Out: Level = Platinum");
      end;

      declare
         F       : File_Type;
         Summary : Proof_Summary;
         Success : Boolean;
      begin
         Create (F, Out_File, "/tmp/adacovex_test_prove_out.txt");
         Put_Line (F, "   Flow Dependencies            7       7 (100%)");
         Put_Line (F, "   Run-time Checks             12      10 (83%)");
         Put_Line (F, "   Assertions                   2       2 (100%)");
         Put_Line
           (F,
            "   Total                    29       0      26       0       3");
         Close (F);

         Adacovex.Parsers.GNATprove.Parse_Prove_Out
           ("/tmp/adacovex_test_prove_out.txt", Summary, Success);

         R.Check (Success, "Parse_Prove_Out (Silver): success");
         R.Check
           (Summary.Total_VCs = 29,
            "Parse_Prove_Out (Silver): Total_VCs = 29");
         R.Check
           (Summary.Proved_VCs = 26,
            "Parse_Prove_Out (Silver): Proved_VCs = 26");
         R.Check
           (Summary.Unproved = 3, "Parse_Prove_Out (Silver): Unproved = 3");
         R.Check
           (Summary.Level = Silver,
            "Parse_Prove_Out (Silver): Level = Silver");
      end;
   end Run;

end Adacovex_Prove_Tests;
