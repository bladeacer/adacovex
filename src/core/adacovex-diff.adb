with Ada.Text_IO;
with GNAT.OS_Lib;
with Adacovex.Parsers.Source;
with Adacovex.Parsers.GNATprove;
with Adacovex.Parsers.Tests;
with Adacovex.Compliance.DAL;
with Adacovex.Types;

package body Adacovex.Diff is

   use Adacovex.Types;
   use Adacovex.Types.Implementation;

   function Run_Git (Dir : String; Args : GNAT.OS_Lib.Argument_List) return Boolean is
      use GNAT.OS_Lib;
      Args_L : GNAT.OS_Lib.Argument_List (1 .. Args'Length + 2);
      K      : Positive := 1;
      OK     : Boolean;
      Code   : Integer;
      Git    : String_Access := Locate_Exec_On_Path ("git");
   begin
      if Git = null then
         return False;
      end if;
      Args_L (K) := new String'("-C");
      K := K + 1;
      Args_L (K) := new String'(Dir);
      K := K + 1;
      for I in Args'Range loop
         Args_L (K) := Args (I);
         K := K + 1;
      end loop;
      Spawn (Git.all, Args_L (1 .. K - 1), "/dev/null", OK, Code, Err_To_Out => True);
      Free (Git);
      return OK and then Code = 0;
   end Run_Git;

   function Assess
     (Target_Dir : String; DAL_Target : Types.DAL_Level) return Assessment_Result
   is
      R     : Assessment_Result;
      Pkgs  : Package_Vectors.Vector;
      Docs  : Docstring_Metrics;
      Proof : Proof_Summary;
      Tests : Test_Summary;
      DAL   : DAL_Assessment;
      OK    : Boolean;
   begin
      Adacovex.Parsers.Source.Scan_Project (Target_Dir, "", Pkgs);
      Adacovex.Parsers.Source.Apply_Patches (Target_Dir, Pkgs);
      Docs := Adacovex.Parsers.Source.Compute_Docstring_Metrics (Pkgs);
      R.Packages := Natural (Pkgs.Length);
      R.Subprograms := Docs.Total_Subprograms;
      R.Documented := Docs.Documented_Subprogs;
      R.Coverage_Pct := Docs.Coverage_Pct;

      Adacovex.Parsers.GNATprove.Parse_Prove_From_Project (Target_Dir, Proof, OK);
      R.Has_Proof := OK;
      R.Total_VCs := Proof.Total_VCs;
      R.Proved_VCs := Proof.Proved_VCs;
      R.SPARK_Level := Proof.Level;

      declare
         T_Path : constant String := Target_Dir & "/test_result.md";
      begin
         Adacovex.Parsers.Tests.Parse_Test_Result (T_Path, Tests, OK);
      end;
      R.Has_Tests := OK;
      R.Tests_Passed := Tests.Total_Passed;
      R.Tests_Failed := Tests.Total_Failed;

      Adacovex.Compliance.DAL.Assess_DAL
        (DAL_Target, Target_Dir, Pkgs, Proof, Tests, DAL);
      R.HLR_Total := DAL.HLR_Total;
      R.HLR_Found := DAL.HLR_Found;
      R.Orphan_Tags := DAL.Orphan_Tags;
      R.DAL_Status := DAL.Status;
      return R;
   end Assess;

   function Is_Git_Repo (Target_Dir : String) return Boolean is
   begin
      return Run_Git
        (Target_Dir,
         (new String'("rev-parse"), new String'("--is-inside-work-tree")));
   end Is_Git_Repo;

   procedure Make_Worktree
     (Target_Dir : String;
      Base_Ref   : String;
      Tmp_Path   : out String;
      Tmp_Len    : out Natural;
      Success    : out Boolean)
   is
      Pid     : constant Integer :=
        GNAT.OS_Lib.Pid_To_Integer (GNAT.OS_Lib.Current_Process_Id);
      Pid_Img : constant String := Integer'Image (Pid);
      Tmp_S   : constant String :=
        "/tmp/adacovex-diff-" & Pid_Img (2 .. Pid_Img'Last);
   begin
      Tmp_Len := Tmp_S'Length;
      for I in Tmp_S'Range loop
         Tmp_Path (I - Tmp_S'First + 1) := Tmp_S (I);
      end loop;

      --  Clean up any stale worktree from a previous run, then create.
      Remove_Worktree (Target_Dir, Tmp_Path (1 .. Tmp_Len));
      Success := Run_Git
        (Target_Dir,
         (new String'("worktree"),
          new String'("add"),
          new String'("--detach"),
          new String'(Tmp_Path (1 .. Tmp_Len)),
          new String'(Base_Ref)));
      if not Success then
         Tmp_Len := 0;
      end if;
   end Make_Worktree;

   procedure Remove_Worktree (Target_Dir : String; Tmp_Path : String) is
      Ignored : Boolean;
   begin
      Ignored := Run_Git
        (Target_Dir,
         (new String'("worktree"),
          new String'("remove"),
          new String'("--force"),
          new String'(Tmp_Path)));
   end Remove_Worktree;

   function Report_Delta
     (Base      : Assessment_Result;
      Cur       : Assessment_Result;
      Base_Ref  : String;
      Use_Color : Boolean := False) return Boolean
   is
      ESC       : constant String := ASCII.ESC & "[";
      Regressed : Boolean := False;

      procedure C (Color : String) is
      begin
         if Use_Color then
            Ada.Text_IO.Put (ESC & Color & "m");
         end if;
      end C;

      procedure RC is
      begin
         if Use_Color then
            Ada.Text_IO.Put (ESC & "0m");
         end if;
      end RC;

      procedure Col (S : String; W : Natural) is
      begin
         Ada.Text_IO.Put (S);
         for I in S'Length + 1 .. W loop
            Ada.Text_IO.Put (" ");
         end loop;
      end Col;

      function VC_Str (R : Assessment_Result) return String is
      begin
         if R.Has_Proof then
            return Natural'Image (R.Proved_VCs) & "/"
              & Natural'Image (R.Total_VCs);
         else
            return "N/A";
         end if;
      end VC_Str;

      function Spark_Str (R : Assessment_Result) return String is
      begin
         if R.Has_Proof then
            return Types.To_String (R.SPARK_Level);
         else
            return "N/A";
         end if;
      end Spark_Str;

      function Tests_Str (R : Assessment_Result) return String is
      begin
         if R.Has_Tests then
            return Natural'Image (R.Tests_Passed) & "/"
              & Natural'Image (R.Tests_Failed);
         else
            return "N/A";
         end if;
      end Tests_Str;

      function Orphan_Str (R : Assessment_Result) return String is
      begin
         if R.Orphan_Tags then
            return "present";
         else
            return "none";
         end if;
      end Orphan_Str;

      function HLR_Str (R : Assessment_Result) return String is
      begin
         if R.HLR_Total = 0 then
            return "N/A";
         else
            return Natural'Image (R.HLR_Found) & "/"
              & Natural'Image (R.HLR_Total);
         end if;
      end HLR_Str;

      procedure Row (Label, B, Cur_Val : String; Bad : Boolean := False) is
      begin
         Col (Label, 20);
         Col (B, 14);
         if Bad then
            C ("31");
         end if;
         Ada.Text_IO.Put (Cur_Val);
         RC;
         Ada.Text_IO.New_Line;
      end Row;

   begin
      Ada.Text_IO.New_Line;
      Ada.Text_IO.Put_Line
        ("  -- Differential assessment: base <" & Base_Ref & "> vs current --");
      Col ("metric", 20);
      Col ("base", 14);
      Ada.Text_IO.Put_Line ("current");

      Row ("packages",
           Natural'Image (Base.Packages),
           Natural'Image (Cur.Packages));
      Row ("subprograms",
           Natural'Image (Base.Subprograms),
           Natural'Image (Cur.Subprograms));
      Row ("documented",
           Natural'Image (Base.Coverage_Pct) & "%",
           Natural'Image (Cur.Coverage_Pct) & "%",
           Bad => Cur.Coverage_Pct < Base.Coverage_Pct);
      Row ("HLR traced",
           HLR_Str (Base),
           HLR_Str (Cur),
           Bad => Cur.HLR_Found < Base.HLR_Found);
      Row ("orphan tags",
           Orphan_Str (Base),
           Orphan_Str (Cur),
           Bad => (not Base.Orphan_Tags) and Cur.Orphan_Tags);
      Row ("spark level",
           Spark_Str (Base),
           Spark_Str (Cur),
           Bad => Base.Has_Proof and Cur.Has_Proof
             and Cur.SPARK_Level < Base.SPARK_Level);
      Row ("VCs proved",
           VC_Str (Base),
           VC_Str (Cur),
           Bad => Base.Has_Proof and Cur.Has_Proof
             and Base.Proved_VCs > 0 and Cur.Proved_VCs < Base.Proved_VCs);
      Row ("tests passed/failed",
           Tests_Str (Base),
           Tests_Str (Cur),
           Bad => Base.Has_Tests and Cur.Has_Tests
             and Cur.Tests_Failed > Base.Tests_Failed);
      Row ("DAL status",
           Types.To_String (Base.DAL_Status),
           Types.To_String (Cur.DAL_Status),
           Bad => Base.Has_Proof and Base.Has_Tests and Cur.Has_Proof
             and Cur.Has_Tests
             and Base.DAL_Status = Types.Achieved
             and Cur.DAL_Status = Types.Unmet);

      --  Regression determination.
      if Cur.Coverage_Pct < Base.Coverage_Pct then
         Regressed := True;
      end if;
      if Cur.HLR_Found < Base.HLR_Found then
         Regressed := True;
      end if;
      if (not Base.Orphan_Tags) and Cur.Orphan_Tags then
         Regressed := True;
      end if;
      if Base.Has_Proof and Cur.Has_Proof then
         if Cur.SPARK_Level < Base.SPARK_Level then
            Regressed := True;
         end if;
         if Base.Proved_VCs > 0 and Cur.Proved_VCs < Base.Proved_VCs then
            Regressed := True;
         end if;
      end if;
      if Base.Has_Tests and Cur.Has_Tests then
         if Cur.Tests_Failed > Base.Tests_Failed then
            Regressed := True;
         end if;
      end if;
      if Base.Has_Proof and Base.Has_Tests and Cur.Has_Proof and Cur.Has_Tests
        and Base.DAL_Status = Types.Achieved and Cur.DAL_Status = Types.Unmet
      then
         Regressed := True;
      end if;

      Ada.Text_IO.New_Line;
      if Regressed then
         C ("31");
         Ada.Text_IO.Put_Line
           ("  REGRESSION DETECTED: fix the highlighted metrics before pushing.");
      else
         C ("32");
         Ada.Text_IO.Put_Line ("  No regression detected. Safe to push.");
      end if;
      RC;
      Ada.Text_IO.New_Line;

      if (not Base.Has_Proof) or (not Base.Has_Tests) then
         Ada.Text_IO.Put_Line
           ("  Note: base lacks proof/test artifacts (build outputs are not");
         Ada.Text_IO.Put_Line
           ("  versioned). Commit gnatprove.out and test_result.md, or run the");
         Ada.Text_IO.Put_Line
           ("  assessment on the base worktree, to compare VC and test data.");
      end if;

      return Regressed;
   end Report_Delta;

end Adacovex.Diff;
