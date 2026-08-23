with Ada.Text_IO;    use Ada.Text_IO;
with Adacovex.Types; use Adacovex.Types;
with Adacovex.Parsers.GNATprove;
with Adacovex.CPUs;

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

      --  Empty summary (zero VCs) must be Stone, not Gold
      declare
         S : Proof_Summary := (others => <>);
      begin
         R.Check
           (Adacovex.Parsers.GNATprove.Determine_SPARK_Level (S) = Stone,
            "Determine_SPARK_Level: empty summary is Stone");
      end;

      declare
         F       : File_Type;
         Summary : Proof_Summary;
         Success : Boolean;
      begin
         Create
           (F,
            Out_File,
            Adacovex.CPUs.Get_Temp_Directory & "/adacovex_test_prove_out.txt");
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
           (Adacovex.CPUs.Get_Temp_Directory & "/adacovex_test_prove_out.txt",
            Summary,
            Success);

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
         Create
           (F,
            Out_File,
            Adacovex.CPUs.Get_Temp_Directory & "/adacovex_test_prove_out.txt");
         Put_Line (F, "   Flow Dependencies            7       7 (100%)");
         Put_Line (F, "   Run-time Checks             12      10 (83%)");
         Put_Line (F, "   Assertions                   2       2 (100%)");
         Put_Line
           (F,
            "   Total                    29       0      26       0       3");
         Close (F);

         Adacovex.Parsers.GNATprove.Parse_Prove_Out
           (Adacovex.CPUs.Get_Temp_Directory & "/adacovex_test_prove_out.txt",
            Summary,
            Success);

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

      --  Modern summary layout: Total | Flow | Provers | Justified | Unproved
      --  Proved = Total - Justified - Unproved (28 all solved, split 10/18).
      declare
         F       : File_Type;
         Summary : Proof_Summary;
         Success : Boolean;
      begin
         Create
           (F,
            Out_File,
            Adacovex.CPUs.Get_Temp_Directory & "/adacovex_test_prove_out.txt");
         Put_Line
           (F,
            "SPARK Analysis results   Total    Flow     Provers   Justified   Unproved");
         Put_Line
           (F,
            "Run-time Checks              12      .     12 (CVC5)           .          .");
         Put_Line
           (F,
            "Total                         28  10 (36%)  18 (64%)           .          .");
         Close (F);

         Adacovex.Parsers.GNATprove.Parse_Prove_Out
           (Adacovex.CPUs.Get_Temp_Directory & "/adacovex_test_prove_out.txt",
            Summary,
            Success);

         R.Check (Success, "Parse_Prove_Out (modern Total): success");
         R.Check
           (Summary.Total_VCs = 28,
            "Parse_Prove_Out (modern Total): Total_VCs = 28");
         R.Check
           (Summary.Proved_VCs = 28,
            "Parse_Prove_Out (modern Total): Proved_VCs = 28");
         R.Check
           (Summary.Justified = 0,
            "Parse_Prove_Out (modern Total): Justified = 0");
         R.Check
           (Summary.Unproved = 0,
            "Parse_Prove_Out (modern Total): Unproved = 0");
         R.Check
           (Summary.Level = Gold,
            "Parse_Prove_Out (modern Total): Level = Gold (run-time proved, no functional)");
      end;

      --  Modern layout with non-empty Flow + Initialization rows:
      --  Initialization must NOT clobber the Flow Dependencies values.
      declare
         F       : File_Type;
         Summary : Proof_Summary;
         Success : Boolean;
      begin
         Create
           (F,
            Out_File,
            Adacovex.CPUs.Get_Temp_Directory & "/adacovex_test_prove_out.txt");
         Put_Line
           (F,
            "SPARK Analysis results   Total    Flow     Provers   Justified   Unproved");
         Put_Line
           (F,
            "Flow Dependencies          11  11 (100%)           .           .          .");
         Put_Line
           (F,
            "Initialization              3   3 (100%)           .           .          .");
         Put_Line
           (F,
            "Run-time Checks            12      .     12 (CVC5)           .          .");
         Put_Line
           (F,
            "Assertions                  2      .      2 (CVC5)           .          .");
         Put_Line
           (F,
            "Functional Contracts        4      .      4 (CVC5)           .          .");
         Put_Line
           (F,
            "Total                       28  10 (36%)  18 (64%)           .          .");
         Close (F);

         Adacovex.Parsers.GNATprove.Parse_Prove_Out
           (Adacovex.CPUs.Get_Temp_Directory & "/adacovex_test_prove_out.txt",
            Summary,
            Success);

         R.Check (Success, "Parse_Prove_Out (init row): success");
         R.Check
           (Summary.Flow_Checks = 11,
            "Parse_Prove_Out (init row): Flow_Checks = 11");
         R.Check
           (Summary.Flow_Proved = 11,
            "Parse_Prove_Out (init row): Flow_Proved = 11");
         R.Check
           (Summary.Init_Checks = 3,
            "Parse_Prove_Out (init row): Init_Checks = 3");
         R.Check
           (Summary.Init_Proved = 3,
            "Parse_Prove_Out (init row): Init_Proved = 3");
         R.Check
           (Summary.Total_VCs = 28,
            "Parse_Prove_Out (init row): Total_VCs = 28");
         R.Check
           (Summary.Proved_VCs = 28,
            "Parse_Prove_Out (init row): Proved_VCs = 28");
      end;

      --  Justified VCs do not downgrade the SPARK level: a summary with all
      --  functional contracts proved and some VCs justified (but none
      --  unproved) is still Platinum, since justifications are an accepted
      --  way to discharge decidedly-unprovable checks.
      declare
         S : Proof_Summary;
      begin
         S :=
           (Functional_Ct     => 5,
            Functional_Proved => 5,
            Total_VCs         => 29,
            Justified         => 4,
            others            => <>);
         R.Check
           (Adacovex.Parsers.GNATprove.Determine_SPARK_Level (S) = Platinum,
            "Determine_SPARK_Level: justified VCs keep Platinum");
      end;

      --  Justified VCs are counted neither proved nor unproved: Proved =
      --  Total - Justified - Unproved.
      declare
         F       : File_Type;
         Summary : Proof_Summary;
         Success : Boolean;
      begin
         Create
           (F,
            Out_File,
            Adacovex.CPUs.Get_Temp_Directory & "/adacovex_test_prove_out.txt");
         Put_Line
           (F,
            "SPARK Analysis results   Total    Flow     Provers   Justified   Unproved");
         Put_Line
           (F,
            "Flow Dependencies          11  11 (100%)           .           .          .");
         Put_Line
           (F,
            "Run-time Checks            12      .     12 (CVC5)           .          .");
         Put_Line
           (F,
            "Functional Contracts        5      .      5 (CVC5)           .          .");
         Put_Line
           (F,
            "Total                       28  10 (36%)  14 (50%)           4          .");
         Close (F);

         Adacovex.Parsers.GNATprove.Parse_Prove_Out
           (Adacovex.CPUs.Get_Temp_Directory & "/adacovex_test_prove_out.txt",
            Summary,
            Success);

         R.Check (Success, "Parse_Prove_Out (justified): success");
         R.Check
           (Summary.Total_VCs = 28,
            "Parse_Prove_Out (justified): Total_VCs = 28");
         R.Check
           (Summary.Justified = 4,
            "Parse_Prove_Out (justified): Justified = 4");
         R.Check
           (Summary.Unproved = 0, "Parse_Prove_Out (justified): Unproved = 0");
         R.Check
           (Summary.Proved_VCs = 24,
            "Parse_Prove_Out (justified): Proved = 28 - 4 - 0");
         R.Check
           (Summary.Functional_Proved = 5,
            "Parse_Prove_Out (justified): Functional_Proved = 5");
         R.Check
           (Summary.Level = Platinum,
            "Parse_Prove_Out (justified): Level = Platinum");
      end;

      --  Units analyzed/skipped rows are parsed from the .out header.
      declare
         F       : File_Type;
         Summary : Proof_Summary;
         Success : Boolean;
      begin
         Create
           (F,
            Out_File,
            Adacovex.CPUs.Get_Temp_Directory & "/adacovex_test_prove_out.txt");
         Put_Line (F, "Summary of SPARK analysis");
         Put_Line (F, "=========================");
         Put_Line (F, "   Analyzed 28 units");
         Put_Line (F, "   skipped 3 units");
         Put_Line
           (F,
            "SPARK Analysis results   Total    Flow     Provers   Justified   Unproved");
         Put_Line
           (F,
            "Total                       28  10 (36%)  18 (64%)           .          .");
         Close (F);

         Adacovex.Parsers.GNATprove.Parse_Prove_Out
           (Adacovex.CPUs.Get_Temp_Directory & "/adacovex_test_prove_out.txt",
            Summary,
            Success);

         R.Check (Success, "Parse_Prove_Out (units): success");
         R.Check
           (Summary.Units_Analyzed = 28,
            "Parse_Prove_Out (units): Units_Analyzed = 28");
         R.Check
           (Summary.Units_Skipped = 3,
            "Parse_Prove_Out (units): Units_Skipped = 3");
      end;

      --  gnatprove v16 real-world row: the Provers column holds "." and the
      --  Flow column carries a percentage, but field positions are stable, so
      --  the field-based extractor must read Total=3, Justified=. (0) and
      --  Unproved=1 (33%) off the same row.  This is exactly the output both
      --  gnatprove 15.1.0 and 16.1.0 produce (verified against both).
      declare
         F       : File_Type;
         Summary : Proof_Summary;
         Success : Boolean;
      begin
         Create
           (F,
            Out_File,
            Adacovex.CPUs.Get_Temp_Directory & "/adacovex_test_prove_out.txt");
         Put_Line
           (F,
            "SPARK Analysis results        Total       Flow     Provers   Justified   Unproved");
         Put_Line
           (F,
            "Run-time Checks                   1          .           .           .          1");
         Put_Line
           (F,
            "Functional Contracts              1          .    1 (CVC5)           .          .");
         Put_Line
           (F,
            "Termination                       1          1           .           .          .");
         Put_Line
           (F,
            "Total                             3    1 (33%)     1 (33%)           .    1 (33%)");
         Close (F);

         Adacovex.Parsers.GNATprove.Parse_Prove_Out
           (Adacovex.CPUs.Get_Temp_Directory & "/adacovex_test_prove_out.txt",
            Summary,
            Success);

         R.Check (Success, "Parse_Prove_Out (v16 Total): success");
         R.Check
           (Summary.Total_VCs = 3, "Parse_Prove_Out (v16 Total): Total = 3");
         R.Check
           (Summary.Justified = 0,
            "Parse_Prove_Out (v16 Total): Justified = 0 (.)");
         R.Check
           (Summary.Unproved = 1,
            "Parse_Prove_Out (v16 Total): Unproved = 1 (33%)");
         R.Check
           (Summary.Proved_VCs = 2,
            "Parse_Prove_Out (v16 Total): Proved = 3 - 0 - 1");
         R.Check
           (Summary.Level = Silver,
            "Parse_Prove_Out (v16 Total): Level = Silver (unproved > 0)");
      end;

      --  gnatprove v15 style: the Provers column is filled with a percentage
      --  (`326 (65%)`) rather than ".", but field positions 5/6 are
      --  unchanged, so Justified and Unproved must still be extracted.
      declare
         F       : File_Type;
         Summary : Proof_Summary;
         Success : Boolean;
      begin
         Create
           (F,
            Out_File,
            Adacovex.CPUs.Get_Temp_Directory & "/adacovex_test_prove_out.txt");
         Put_Line
           (F,
            "SPARK Analysis results        Total       Flow     Provers   Justified   Unproved");
         Put_Line
           (F,
            "Flow Dependencies               8   8 (100%)           .           .          .");
         Put_Line
           (F,
            "Run-time Checks                 22      .   21 (CVC5)           1          .");
         Put_Line
           (F,
            "Total                           30  8 (27%)   20 (70%)          1   1 (33%)");
         Close (F);

         Adacovex.Parsers.GNATprove.Parse_Prove_Out
           (Adacovex.CPUs.Get_Temp_Directory & "/adacovex_test_prove_out.txt",
            Summary,
            Success);

         R.Check (Success, "Parse_Prove_Out (v15 Total): success");
         R.Check
           (Summary.Total_VCs = 30, "Parse_Prove_Out (v15 Total): Total = 30");
         R.Check
           (Summary.Justified = 1,
            "Parse_Prove_Out (v15 Total): Justified = 1");
         R.Check
           (Summary.Unproved = 1,
            "Parse_Prove_Out (v15 Total): Unproved = 1 (33%)");
         R.Check
           (Summary.Proved_VCs = 28,
            "Parse_Prove_Out (v15 Total): Proved = 30 - 1 - 1");
         R.Check
           (Summary.Runtime_Proved = 21,
            "Parse_Prove_Out (v15 Total): Runtime_Proved = 21");
      end;

      --  A physical line longer than Max_Line in the .out file is rejected
      --  explicitly (no partial proof summary).
      declare
         F       : File_Type;
         Summary : Proof_Summary;
         Success : Boolean;
         Big     : String (1 .. Adacovex.Types.Max_Line + 50);
         BLen    : Natural := 0;
      begin
         for I in Big'Range loop
            Big (BLen + 1) := 'q';
            BLen := BLen + 1;
         end loop;
         Create
           (F,
            Out_File,
            Adacovex.CPUs.Get_Temp_Directory & "/adacovex_test_prove_out.txt");
         Put_Line
           (F,
            "SPARK Analysis results   Total    Flow     Provers   Justified   Unproved");
         Put_Line (F, Big (1 .. BLen));
         Put_Line
           (F,
            "Total                       28  10 (36%)  18 (64%)           .          .");
         Close (F);
         R.Check
           (BLen = Adacovex.Types.Max_Line + 50,
            "Parse_Prove_Out (overflow): line exceeds Max_Line");

         Adacovex.Parsers.GNATprove.Parse_Prove_Out
           (Adacovex.CPUs.Get_Temp_Directory & "/adacovex_test_prove_out.txt",
            Summary,
            Success);

         R.Check
           (not Success,
            "Parse_Prove_Out (overflow): parse fails, no partial summary");
         R.Check
           (Summary.Total_VCs = 0,
            "Parse_Prove_Out (overflow): no partial VC counts");
      end;
   end Run;

end Adacovex_Prove_Tests;
