with Adacovex.Spark_Coverage;
with Adacovex.CPUs;
with Adacovex.Types;
with Ada.Containers;
with Ada.Directories;
with Ada.Text_IO;

package body Adacovex_Spark_Coverage_Tests is

   use Ada.Text_IO;
   use type Ada.Containers.Count_Type;

   Fixture_Dir : constant String :=
     Adacovex.CPUs.Get_Temp_Directory & "/adacovex_spark_cov_test";

   --  Write a small fixture: one Ada body, a gnatprove.out with one
   --  proved unit plus one skipped entity, and a compact SARIF stream
   --  with one proved check and one proof warning.
   procedure Make_Fixture is
      F : File_Type;
   begin
      if Ada.Directories.Exists (Fixture_Dir) then
         Ada.Directories.Delete_Tree (Fixture_Dir);
      end if;
      Ada.Directories.Create_Directory (Fixture_Dir);
      Ada.Directories.Create_Directory (Fixture_Dir & "/src");
      Ada.Directories.Create_Directory (Fixture_Dir & "/obj");
      Ada.Directories.Create_Directory (Fixture_Dir & "/obj/gnatprove");

      Create (F, Out_File, Fixture_Dir & "/src/foo.adb");
      Put_Line (F, "package body Foo is");
      Put_Line (F, "");
      Put_Line (F, "   procedure Do_It is");
      Put_Line (F, "   begin");
      Put_Line (F, "      null;");
      Put_Line (F, "   end Do_It;");
      Put_Line (F, "");
      Put_Line (F, "   procedure Helped is");
      Put_Line (F, "   begin");
      Put_Line (F, "      null;");
      Put_Line (F, "   end Helped;");
      Put_Line (F, "");
      Put_Line (F, "end Foo;");
      Close (F);

      Create (F, Out_File, Fixture_Dir & "/obj/gnatprove/gnatprove.out");
      Put_Line (F, "GNATprove 16.1.0");
      Put_Line
        (F, "in unit foo, 1 subprograms and packages out of 2 analyzed");
      Put_Line
        (F, "  Foo.Helped at foo.adb:9 skipped; body is SPARK_Mode => Off");
      Close (F);

      Create (F, Out_File, Fixture_Dir & "/obj/gnatprove/gnatprove.sarif");
      Put
        (F,
         "{""version"":""2.1.0"",""runs"":[{""results"":[{""ruleId"":""vc1"",""kind"":""pass"",""level"":""none"",""locations"":[{""physicalLocation"":{""artifactLocation"":{""uri"":""foo.adb""},""region"":{""startLine"":5}}}],");
      Put
        (F,
         """logicalLocations"":[{""name"":""Foo.Do_It""}]},{""ruleId"":""warn1"",""kind"":""pass"",""level"":""warning"",""locations"":"
         & "[{""physicalLocation"":{""artifactLocation"":{""uri"":""foo.adb""},""region"":{""startLine"":5}}}],""logicalLocations"":[{""name"":""Foo.Do_It""}]}]}]}");
      Close (F);
   end Make_Fixture;

   procedure Run (R : in out Adacovex.Test_Support.Runner'Class) is
      use Adacovex.Types.Implementation;
   begin
      Make_Fixture;

      declare
         Units   : Spark_Coverage_Vectors.Vector;
         Groups  : Spark_Group_Vectors.Vector;
         Totals  : Spark_Coverage_Totals;
         Skipped : Natural;
         OK      : Boolean;
      begin
         Adacovex.Spark_Coverage.Analyze
           (Fixture_Dir,
            "",
            Adacovex.Types.Group_File,
            Units,
            Groups,
            Totals,
            Skipped,
            OK);
         R.Check (OK, "fixture artefacts are accepted (Proof_Ok)");
         R.Check
           (Totals.Subs_Proved = 1 and then Totals.Subs_Total = 2,
            "subprogram metric: 1 of 2 analysed is proved");
         R.Check
           (Totals.Checks_Proved = 1 and then Totals.Checks_Total = 1,
            "VC metric: the warning is not a verification condition");
         R.Check (Totals.Warnings = 1, "one proof warning is counted");
         R.Check
           (Totals.Off_Work_Queue > 0,
            "skipped pure-logic subprogram lands in the work queue");
         R.Check
           (Totals.Off_IO_Bound = 0 and then Totals.Off_Irreducible = 0,
            "no I/O-bound or irreducible subprogram in the fixture");
         R.Check
           (Totals.Stmts_Proved > 0,
            "statement metric: proved statements counted from the body");
         R.Check
           (Totals.Stmts_Proved <= Totals.Stmts_Total,
            "statement metric: proved does not exceed the total");
         R.Check
           (Natural (Groups.Length) = 1,
            "one group row for the one fixture file");
         R.Check
           (Groups (1).Stmts_Total = Totals.Stmts_Total,
            "group totals equal the tree totals (ratio of sums)");
      end;

      --  A missing artefact set fails loudly: Proof_Ok is False.
      declare
         Units   : Spark_Coverage_Vectors.Vector;
         Groups  : Spark_Group_Vectors.Vector;
         Totals  : Spark_Coverage_Totals;
         Skipped : Natural;
         OK      : Boolean;
      begin
         Adacovex.Spark_Coverage.Analyze
           (Fixture_Dir & "/src",
            "",
            Adacovex.Types.Group_File,
            Units,
            Groups,
            Totals,
            Skipped,
            OK);
         R.Check (not OK, "missing proof artefacts fail loudly");
      end;

      --  Line classifier and marker detection.
      R.Check
        (Adacovex.Spark_Coverage.Count_Line_Statements ("   X := 1;") = 1,
         "one simple statement per terminated statement");
      R.Check
        (Adacovex.Spark_Coverage.Count_Line_Statements ("      --  null;") = 0,
         "a comment line is not a statement");
      R.Check
        (Adacovex.Spark_Coverage.Line_Is_IO_Bound
           ("   Put_Line (F, S);  --  Ada.Text_IO")
         or else Adacovex.Spark_Coverage.Line_Is_IO_Bound
                   ("with Ada.Text_IO;"),
         "an I/O with-clause is detected");
      R.Check
        (Adacovex.Spark_Coverage.Line_Opts_Out ("   pragma SPARK_Mode (Off);"),
         "an explicit SPARK_Mode (Off) pragma is detected");
      R.Check
        (not Adacovex.Spark_Coverage.Line_Opts_Out
               ("   --  pragma SPARK_Mode (Off) is not code"),
         "a comment that names the pragma is not an opt-out");

      --  Metric extraction and the gate message.
      declare
         Proved : Natural;
         Total  : Natural;
         Msg    : Adacovex.Types.Path_Field;
         MLen   : Natural;
      begin
         Adacovex.Spark_Coverage.Metric_Values
           ((Stmts_Proved  => 3,
             Stmts_Total   => 4,
             Subs_Proved   => 1,
             Subs_Total    => 2,
             Checks_Proved => 5,
             Checks_Total  => 5,
             others        => <>),
            Adacovex.Types.Metric_Checks,
            Proved,
            Total);
         R.Check (Proved = 5 and then Total = 5, "VC metric extracted");
         Adacovex.Spark_Coverage.Gate_Failure_Message
           (Adacovex.Types.Metric_Statements, 3, 10, 50, Msg, MLen);
         R.Check (MLen > 0, "gate failure message is not empty");
      end;
   end Run;

end Adacovex_Spark_Coverage_Tests;
