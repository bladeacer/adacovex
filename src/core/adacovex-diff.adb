with Ada.Text_IO;
with Adacovex.VCS;
with Adacovex.Parsers.Source;
with Adacovex.Parsers.GNATprove;
with Adacovex.Parsers.Tests;
with Adacovex.Compliance.DAL;
with Adacovex.Types;

package body Adacovex.Diff is

   use Adacovex.Types;
   use Adacovex.Types.Implementation;

   function Assess
     (Target_Dir : String;
      DAL_Target : Types.DAL_Level;
      Use_Cache  : Boolean := False) return Assessment_Result
   is
      R      : Assessment_Result;
      Pkgs   : Package_Vectors.Vector;
      Docs   : Docstring_Metrics;
      Proof  : Proof_Summary;
      Tests  : Test_Summary;
      DAL    : DAL_Assessment;
      OK     : Boolean;
      Hits   : Natural := 0;
      Misses : Natural := 0;
   begin
      --  Reuse the cached scan when enabled so an unchanged working tree is
      --  not re-scanned on every differential run.  The base worktree is a
      --  throwaway snapshot, but its entries are content-hashed and evicted
      --  oldest-first, so caching them too is harmless.
      Adacovex.Parsers.Source.Scan_Project_Cached
        (Target_Dir, "", Pkgs, R.Skipped, Hits, Misses, Use_Cache);
      Adacovex.Parsers.Source.Apply_Patches (Target_Dir, Pkgs);
      Docs := Adacovex.Parsers.Source.Compute_Docstring_Metrics (Pkgs);
      R.Packages := Natural (Pkgs.Length);
      R.Subprograms := Docs.Total_Subprograms;
      R.Documented := Docs.Documented_Subprogs;
      R.Coverage_Pct := Docs.Coverage_Pct;

      Adacovex.Parsers.GNATprove.Parse_Prove_From_Project
        (Target_Dir, Proof, OK);
      R.Has_Proof := OK;
      R.Total_VCs := Proof.Total_VCs;
      R.Proved_VCs := Proof.Proved_VCs;
      R.SPARK_Level := Proof.Level;

      Adacovex.Parsers.Tests.Parse_Test_Result_From_Project
        (Target_Dir, Tests, OK);
      R.Has_Tests := OK;
      R.Tests_Passed := Tests.Total_Passed;
      R.Tests_Failed := Tests.Total_Failed;

      Adacovex.Compliance.DAL.Assess_DAL
        (DAL_Target, Target_Dir, Pkgs, Proof, Tests, DAL, Use_Cache);
      R.HLR_Total := DAL.HLR_Total;
      R.HLR_Found := DAL.HLR_Found;
      R.Orphan_Tags := DAL.Orphan_Tags;
      R.DAL_Status := DAL.Status;
      if R.Skipped > 0 then
         --  Skipped sources make the source set incomplete; the assessment
         --  cannot claim compliance for unread code.
         R.DAL_Status := Types.Unmet;
      end if;
      return R;
   end Assess;

   function Assess_Coverage
     (Target_Dir : String; Use_Cache : Boolean := False) return Coverage_Result
   is
      R      : Coverage_Result;
      Pkgs   : Package_Vectors.Vector;
      Docs   : Docstring_Metrics;
      Hits   : Natural := 0;
      Misses : Natural := 0;
   begin
      Adacovex.Parsers.Source.Scan_Project_Cached
        (Target_Dir, "", Pkgs, R.Skipped, Hits, Misses, Use_Cache);
      Adacovex.Parsers.Source.Apply_Patches (Target_Dir, Pkgs);
      Docs := Adacovex.Parsers.Source.Compute_Docstring_Metrics (Pkgs);
      R.Total := Docs.Total_Subprograms;
      R.Documented := Docs.Documented_Subprogs;
      R.Pct := Docs.Coverage_Pct;
      return R;
   end Assess_Coverage;

   function Is_Repo (Target_Dir : String) return Boolean is
   begin
      return Adacovex.VCS.Is_Managed (Target_Dir);
   end Is_Repo;

   function Repo_Kind_Name (Target_Dir : String) return String is
   begin
      return Adacovex.VCS.To_String (Adacovex.VCS.Detect (Target_Dir));
   end Repo_Kind_Name;

   function UX_Note (Target_Dir : String) return String is
   begin
      return Adacovex.VCS.UX_Note (Adacovex.VCS.Detect (Target_Dir));
   end UX_Note;

   procedure Make_Worktree
     (Target_Dir : String;
      Base_Ref   : String;
      Tmp_Path   : out String;
      Tmp_Len    : out Natural;
      Success    : out Boolean)
   is
      Kind : constant Adacovex.VCS.VCS_Kind :=
        Adacovex.VCS.Detect (Target_Dir);
   begin
      Adacovex.VCS.Make_Snapshot
        (Target_Dir, Kind, Base_Ref, Tmp_Path, Tmp_Len, Success);
   end Make_Worktree;

   procedure Remove_Worktree (Target_Dir : String; Tmp_Path : String) is
      Kind : constant Adacovex.VCS.VCS_Kind :=
        Adacovex.VCS.Detect (Target_Dir);
   begin
      Adacovex.VCS.Remove_Snapshot (Target_Dir, Kind, Tmp_Path);
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
            return
              Natural'Image (R.Proved_VCs) & "/" & Natural'Image (R.Total_VCs);
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
            return
              Natural'Image (R.Tests_Passed)
              & "/"
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
            return
              Natural'Image (R.HLR_Found) & "/" & Natural'Image (R.HLR_Total);
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
        ("  -- Differential assessment: base <"
         & Base_Ref
         & "> vs current --");
      Col ("metric", 20);
      Col ("base", 14);
      Ada.Text_IO.Put_Line ("current");

      Row
        ("packages",
         Natural'Image (Base.Packages),
         Natural'Image (Cur.Packages));
      Row
        ("subprograms",
         Natural'Image (Base.Subprograms),
         Natural'Image (Cur.Subprograms));
      Row
        ("documented",
         Natural'Image (Base.Coverage_Pct) & "%",
         Natural'Image (Cur.Coverage_Pct) & "%",
         Bad => Cur.Coverage_Pct < Base.Coverage_Pct);
      Row
        ("HLR traced",
         HLR_Str (Base),
         HLR_Str (Cur),
         Bad => Cur.HLR_Found < Base.HLR_Found);
      Row
        ("orphan tags",
         Orphan_Str (Base),
         Orphan_Str (Cur),
         Bad => (not Base.Orphan_Tags) and Cur.Orphan_Tags);
      Row
        ("spark level",
         Spark_Str (Base),
         Spark_Str (Cur),
         Bad =>
           Base.Has_Proof
           and Cur.Has_Proof
           and Cur.SPARK_Level < Base.SPARK_Level);
      Row
        ("VCs proved",
         VC_Str (Base),
         VC_Str (Cur),
         Bad =>
           Base.Has_Proof
           and Cur.Has_Proof
           and Base.Proved_VCs > 0
           and Cur.Proved_VCs < Base.Proved_VCs);
      Row
        ("tests passed/failed",
         Tests_Str (Base),
         Tests_Str (Cur),
         Bad =>
           Base.Has_Tests
           and Cur.Has_Tests
           and Cur.Tests_Failed > Base.Tests_Failed);
      Row
        ("DAL status",
         Types.To_String (Base.DAL_Status),
         Types.To_String (Cur.DAL_Status),
         Bad =>
           Base.Has_Proof
           and Base.Has_Tests
           and Cur.Has_Proof
           and Cur.Has_Tests
           and Base.DAL_Status = Types.Achieved
           and Cur.DAL_Status = Types.Unmet);
      Row
        ("sources skipped",
         Natural'Image (Base.Skipped),
         Natural'Image (Cur.Skipped),
         Bad => Cur.Skipped > 0);

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
      if Base.Has_Proof
        and Base.Has_Tests
        and Cur.Has_Proof
        and Cur.Has_Tests
        and Base.DAL_Status = Types.Achieved
        and Cur.DAL_Status = Types.Unmet
      then
         Regressed := True;
      end if;
      if Cur.Skipped > 0 then
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

   function Report_Coverage_Delta
     (Base      : Coverage_Result;
      Cur       : Coverage_Result;
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

      function Count_Str (R : Coverage_Result) return String is
      begin
         if R.Total = 0 then
            return "N/A";
         else
            return
              Natural'Image (R.Documented) & "/" & Natural'Image (R.Total);
         end if;
      end Count_Str;

      function Pct_Str (R : Coverage_Result) return String is
      begin
         if R.Total = 0 then
            return "N/A";
         else
            return Natural'Image (R.Pct) & "%";
         end if;
      end Pct_Str;

   begin
      Ada.Text_IO.New_Line;
      Ada.Text_IO.Put_Line
        ("  -- Coverage delta: base <" & Base_Ref & "> vs current --");
      Col ("metric", 20);
      Col ("base", 14);
      Ada.Text_IO.Put_Line ("current");

      Row ("subprograms", Count_Str (Base), Count_Str (Cur));
      Row
        ("docstring coverage",
         Pct_Str (Base),
         Pct_Str (Cur),
         Bad => Cur.Total > 0 and Base.Total > 0 and Cur.Pct < Base.Pct);
      Row
        ("sources skipped",
         Natural'Image (Base.Skipped),
         Natural'Image (Cur.Skipped),
         Bad => Cur.Skipped > 0);

      Ada.Text_IO.New_Line;
      if Base.Total = 0 then
         Ada.Text_IO.Put_Line
           ("  (base tree has no sources; nothing to regress against)");
         return False;
      end if;

      Regressed := Cur.Total > 0 and then Cur.Pct < Base.Pct;
      if Cur.Skipped > 0 then
         Regressed := True;
      end if;
      if Regressed then
         C ("31");
         Ada.Text_IO.Put_Line
           ("  COVERAGE REGRESSION: docstring coverage dropped from"
            & Natural'Image (Base.Pct)
            & "% to"
            & Natural'Image (Cur.Pct)
            & "%.");
      else
         C ("32");
         Ada.Text_IO.Put_Line
           ("  Coverage OK: docstring coverage is"
            & Natural'Image (Cur.Pct)
            & "% (base"
            & Natural'Image (Base.Pct)
            & "%).");
      end if;
      RC;
      Ada.Text_IO.New_Line;

      --  Machine-parseable line for CI gates (e.g. GitHub Actions).
      Ada.Text_IO.Put_Line
        ("coverage_delta: base="
         & Natural'Image (Base.Pct)
         & " current="
         & Natural'Image (Cur.Pct)
         & " regressed="
         & (if Regressed then "yes" else "no"));

      return Regressed;
   end Report_Coverage_Delta;

end Adacovex.Diff;
