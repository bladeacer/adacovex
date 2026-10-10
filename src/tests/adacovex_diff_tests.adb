with Adacovex.Diff;
with Adacovex.Types;
with Adacovex.CPUs;
with Ada.Directories;
with Ada.Text_IO;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package body Adacovex_Diff_Tests is

   Capture_Path : constant String :=
     Adacovex.CPUs.Get_Temp_Directory & "/adacovex_diff_capture.txt";

   Plain_Dir : constant String :=
     Adacovex.CPUs.Get_Temp_Directory & "/adacovex_diff_plain";
   Git_Dir   : constant String :=
     Adacovex.CPUs.Get_Temp_Directory & "/adacovex_diff_git";

   --  One captured report: the returned verdict plus the printed text.
   type Captured is record
      Regressed : Boolean := False;
      Text      : Unbounded_String;
   end record;

   --  Run Report with standard output redirected into the capture file.
   --  @param Report  Report call to run (its verdict is captured too).
   --  @return The verdict and the text the report printed.
   function Run_Captured
     (Report : not null access function return Boolean) return Captured
   is
      F    : Ada.Text_IO.File_Type;
      G    : Ada.Text_IO.File_Type;
      Line : String (1 .. 1024);
      Last : Natural;
      Res  : Captured;
   begin
      Ada.Text_IO.Create (F, Ada.Text_IO.Out_File, Capture_Path);
      Ada.Text_IO.Set_Output (F);
      Res.Regressed := Report.all;
      Ada.Text_IO.Flush (F);
      Ada.Text_IO.Set_Output (Ada.Text_IO.Standard_Output);
      Ada.Text_IO.Close (F);

      Ada.Text_IO.Open (G, Ada.Text_IO.In_File, Capture_Path);
      while not Ada.Text_IO.End_Of_File (G) loop
         Ada.Text_IO.Get_Line (G, Line, Last);
         Append (Res.Text, Line (1 .. Last));
         Append (Res.Text, ASCII.LF);
      end loop;
      Ada.Text_IO.Close (G);
      Ada.Directories.Delete_File (Capture_Path);
      return Res;
   end Run_Captured;

   --  True when Needle appears in Haystack.
   --  @param Haystack  Captured report text.
   --  @param Needle  Substring to look for.
   --  @return True when the substring is present.
   function Has_Text
     (Haystack : Unbounded_String; Needle : String) return Boolean
   is
      S : constant String := To_String (Haystack);
   begin
      if Needle'Length = 0 or else Needle'Length > S'Length then
         return False;
      end if;
      for I in S'First .. S'Last - Needle'Length + 1 loop
         if S (I .. I + Needle'Length - 1) = Needle then
            return True;
         end if;
      end loop;
      return False;
   end Has_Text;

   --  Build a docstring-coverage snapshot.
   --  @param Documented  Documented subprogram count.
   --  @param Total  Scanned subprogram count.
   --  @param Pct  Coverage percentage.
   --  @param Skipped  Skipped file count.
   --  @return The coverage snapshot.
   function Cov
     (Documented : Natural;
      Total      : Natural;
      Pct        : Natural;
      Skipped    : Natural := 0) return Adacovex.Diff.Coverage_Result is
   begin
      return
        (Documented => Documented,
         Total      => Total,
         Pct        => Pct,
         Skipped    => Skipped);
   end Cov;

   --  Build a full-assessment snapshot with the metrics a test varies.
   --  @param Pct  Docstring coverage percentage.
   --  @param HLR_Total  HLR tag count.
   --  @param HLR_Found  Traced HLR tag count.
   --  @param Orphan  Whether orphan HLR tags are present.
   --  @param Has_Proof  Whether proof artifacts were available.
   --  @param Proved  Proved VC count.
   --  @param Total_VCs  Total VC count.
   --  @param Level  SPARK proof level.
   --  @param Has_Tests  Whether test results were available.
   --  @param Failed  Failed test count.
   --  @param DAL_Status  DAL compliance status.
   --  @param Skipped  Skipped source count.
   --  @return The assessment snapshot.
   function Asmt
     (Pct        : Natural;
      HLR_Total  : Natural := 0;
      HLR_Found  : Natural := 0;
      Orphan     : Boolean := False;
      Has_Proof  : Boolean := False;
      Proved     : Natural := 0;
      Total_VCs  : Natural := 0;
      Level      : Adacovex.Types.SPARK_Level := Adacovex.Types.Stone;
      Has_Tests  : Boolean := False;
      Failed     : Natural := 0;
      DAL_Status : Adacovex.Types.DAL_Status := Adacovex.Types.Achieved;
      Skipped    : Natural := 0) return Adacovex.Diff.Assessment_Result is
   begin
      return
        (Coverage_Pct => Pct,
         HLR_Total    => HLR_Total,
         HLR_Found    => HLR_Found,
         Orphan_Tags  => Orphan,
         Has_Proof    => Has_Proof,
         Proved_VCs   => Proved,
         Total_VCs    => Total_VCs,
         SPARK_Level  => Level,
         Has_Tests    => Has_Tests,
         Tests_Failed => Failed,
         DAL_Status   => DAL_Status,
         Skipped      => Skipped,
         others       => <>);
   end Asmt;

   procedure Run (R : in out Adacovex.Test_Support.Runner'Class) is
      Cap : Captured;
   begin
      --  Coverage-delta gate: a base tree with no sources compares nothing.
      declare
         Base : constant Adacovex.Diff.Coverage_Result := Cov (0, 0, 0);
         Cur  : constant Adacovex.Diff.Coverage_Result := Cov (4, 5, 80);

         function Report return Boolean is
         begin
            return Adacovex.Diff.Report_Coverage_Delta (Base, Cur, "main");
         end Report;
      begin
         Cap := Run_Captured (Report'Access);
         R.Check
           (not Cap.Regressed,
            "an empty base tree reports no coverage regression");
         R.Check
           (Has_Text (Cap.Text, "no sources"),
            "an empty base tree says there is nothing to regress against");
      end;

      --  Coverage-delta gate: a coverage drop is a regression.
      declare
         Base : constant Adacovex.Diff.Coverage_Result := Cov (10, 10, 100);
         Cur  : constant Adacovex.Diff.Coverage_Result := Cov (8, 10, 80);

         function Report return Boolean is
         begin
            return Adacovex.Diff.Report_Coverage_Delta (Base, Cur, "main");
         end Report;
      begin
         Cap := Run_Captured (Report'Access);
         R.Check (Cap.Regressed, "a coverage drop is a regression");
         R.Check
           (Has_Text (Cap.Text, "COVERAGE REGRESSION"),
            "a coverage drop prints the regression banner");
         R.Check
           (Has_Text (Cap.Text, "regressed=yes"),
            "the machine line reports regressed=yes");
      end;

      --  Coverage-delta gate: equal or better coverage is not a regression.
      declare
         Base : constant Adacovex.Diff.Coverage_Result := Cov (8, 10, 80);
         Cur  : constant Adacovex.Diff.Coverage_Result := Cov (9, 10, 90);

         function Report return Boolean is
         begin
            return Adacovex.Diff.Report_Coverage_Delta (Base, Cur, "main");
         end Report;
      begin
         Cap := Run_Captured (Report'Access);
         R.Check (not Cap.Regressed, "a coverage gain is not a regression");
         R.Check
           (Has_Text (Cap.Text, "Coverage OK"),
            "a coverage gain prints the OK banner");
         R.Check
           (Has_Text (Cap.Text, "regressed=no"),
            "the machine line reports regressed=no");
      end;

      --  Coverage-delta gate: a skipped source is a regression on its own.
      declare
         Base : constant Adacovex.Diff.Coverage_Result := Cov (10, 10, 100);
         Cur  : constant Adacovex.Diff.Coverage_Result := Cov (10, 10, 100, 1);

         function Report return Boolean is
         begin
            return Adacovex.Diff.Report_Coverage_Delta (Base, Cur, "main");
         end Report;
      begin
         Cap := Run_Captured (Report'Access);
         R.Check (Cap.Regressed, "a skipped source is a coverage regression");
      end;

      --  Colour is only emitted when it is requested.
      declare
         Base : constant Adacovex.Diff.Coverage_Result := Cov (1, 1, 100);
         Cur  : constant Adacovex.Diff.Coverage_Result := Cov (1, 1, 100);

         function Report return Boolean is
         begin
            return
              Adacovex.Diff.Report_Coverage_Delta
                (Base, Cur, "main", Use_Color => True);
         end Report;
      begin
         Cap := Run_Captured (Report'Access);
         R.Check
           (Has_Text (Cap.Text, String'(1 => ASCII.ESC)),
            "the coverage report colours its output when asked");
      end;

      --  Full delta: identical snapshots are safe to push.
      declare
         Base : constant Adacovex.Diff.Assessment_Result := Asmt (100);
         Cur  : constant Adacovex.Diff.Assessment_Result := Asmt (100);

         function Report return Boolean is
         begin
            return Adacovex.Diff.Report_Delta (Base, Cur, "main");
         end Report;
      begin
         Cap := Run_Captured (Report'Access);
         R.Check
           (not Cap.Regressed, "identical assessments are not a regression");
         R.Check
           (Has_Text (Cap.Text, "No regression detected"),
            "an unchanged tree prints the safe-to-push banner");
         R.Check
           (Has_Text (Cap.Text, "base lacks proof/test artifacts"),
            "a base without build artifacts is called out");
      end;

      --  Full delta: each metric that can regress on its own.
      declare
         type Case_Kind is
           (Cov_Drop,
            Skipped,
            HLR_Lost,
            Orphan,
            Level_Drop,
            VC_Drop,
            Test_Fail,
            DAL_Lost);
      begin
         for K in Case_Kind loop
            declare
               Base : Adacovex.Diff.Assessment_Result := Asmt (100);
               Cur  : Adacovex.Diff.Assessment_Result := Asmt (100);
               Msg  : constant String := Case_Kind'Image (K);

               function Report return Boolean is
               begin
                  return Adacovex.Diff.Report_Delta (Base, Cur, "main");
               end Report;
            begin
               case K is
                  when Cov_Drop   =>
                     Cur.Coverage_Pct := 80;

                  when Skipped    =>
                     Cur.Skipped := 1;

                  when HLR_Lost   =>
                     Base.HLR_Total := 10;
                     Base.HLR_Found := 10;
                     Cur.HLR_Total := 10;
                     Cur.HLR_Found := 8;

                  when Orphan     =>
                     Cur.Orphan_Tags := True;

                  when Level_Drop =>
                     Base.Has_Proof := True;
                     Base.Proved_VCs := 100;
                     Base.Total_VCs := 100;
                     Base.SPARK_Level := Adacovex.Types.Platinum;
                     Cur.Has_Proof := True;
                     Cur.Proved_VCs := 100;
                     Cur.Total_VCs := 100;
                     Cur.SPARK_Level := Adacovex.Types.Gold;

                  when VC_Drop    =>
                     Base.Has_Proof := True;
                     Base.Proved_VCs := 100;
                     Base.Total_VCs := 100;
                     Cur.Has_Proof := True;
                     Cur.Proved_VCs := 90;
                     Cur.Total_VCs := 100;

                  when Test_Fail  =>
                     Base.Has_Tests := True;
                     Cur.Has_Tests := True;
                     Cur.Tests_Failed := 1;

                  when DAL_Lost   =>
                     Base.Has_Proof := True;
                     Base.Has_Tests := True;
                     Base.DAL_Status := Adacovex.Types.Achieved;
                     Cur.Has_Proof := True;
                     Cur.Has_Tests := True;
                     Cur.DAL_Status := Adacovex.Types.Unmet;
               end case;

               Cap := Run_Captured (Report'Access);
               R.Check (Cap.Regressed, "regression detected: " & Msg);
               R.Check
                 (Has_Text (Cap.Text, "REGRESSION DETECTED"),
                  "regression banner printed: " & Msg);
            end;
         end loop;
      end;

      --  Full delta: an improved tree is not a regression.
      declare
         Base : constant Adacovex.Diff.Assessment_Result := Asmt (80);
         Cur  : constant Adacovex.Diff.Assessment_Result := Asmt (100);

         function Report return Boolean is
         begin
            return Adacovex.Diff.Report_Delta (Base, Cur, "main");
         end Report;
      begin
         Cap := Run_Captured (Report'Access);
         R.Check
           (not Cap.Regressed,
            "an improved docstring coverage is not a regression");
      end;

      --  VCS awareness of the differential modes.
      if Ada.Directories.Exists (Plain_Dir) then
         Ada.Directories.Delete_Tree (Plain_Dir);
      end if;
      Ada.Directories.Create_Directory (Plain_Dir);
      R.Check
        (not Adacovex.Diff.Is_Repo (Plain_Dir),
         "a plain directory is not a supported repository");
      R.Check
        (Adacovex.Diff.Repo_Kind_Name (Plain_Dir) = "",
         "an unknown repository kind is reported as an empty string");
      R.Check
        (Adacovex.Diff.UX_Note (Plain_Dir) = "",
         "no conversion note is printed without a legacy VCS");

      if Ada.Directories.Exists (Git_Dir) then
         Ada.Directories.Delete_Tree (Git_Dir);
      end if;
      Ada.Directories.Create_Directory (Git_Dir);
      Ada.Directories.Create_Directory (Git_Dir & "/.git");
      R.Check
        (Adacovex.Diff.Is_Repo (Git_Dir),
         "a .git marker marks a supported repository");
      R.Check
        (Adacovex.Diff.Repo_Kind_Name (Git_Dir) = "git",
         "the repository kind is reported as git");
      R.Check
        (Adacovex.Diff.UX_Note (Git_Dir) = "",
         "a supported VCS needs no conversion note");

      Ada.Directories.Delete_Tree (Plain_Dir);
      Ada.Directories.Delete_Tree (Git_Dir);
   end Run;

end Adacovex_Diff_Tests;
