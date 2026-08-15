with Ada.Text_IO;
with Ada.Exceptions;
with Ada.Command_Line;
with Ada.Calendar;
with Ada.Environment_Variables;
with GNAT.Sockets;
with Adacovex.Types;
with Adacovex.Config;
with Adacovex.Diff;
with Adacovex.Prove;
with Adacovex.Parsers.Source;
with Adacovex.Parsers.GNATprove;
with Adacovex.Parsers.Tests;
with Adacovex.Parsers.DO178C;
with Adacovex.Parsers.Manifest;
with Adacovex.Compliance.DAL;
with Adacovex.Renderers.ANSI;
with Adacovex.Renderers.SVG;
with Adacovex.Renderers.Markdown;
with Adacovex.Renderers.SBOM;
with Adacovex.Server.HTTP;
with Adacovex.Cache;

procedure Adacovex_Main is
   use Ada.Calendar;
   use Adacovex.Types, Adacovex.Types.Implementation;

   function Img (N : Natural) return String is
      S : constant String := Natural'Image (N);
   begin
      return S (2 .. S'Last);
   end Img;

   Start_Time : constant Time := Clock;
   Cfg        : Adacovex.Config.CLI_Config;
   Target     : String (1 .. Max_Path);
   TLen       : Natural;

   Use_Color : Boolean := False;

   Packages   : Package_Vectors.Vector;
   Skipped_Ct : Natural := 0;

   Doc_Metrics : Docstring_Metrics;
   Proof       : Proof_Summary;
   Tests       : Test_Summary;
   DAL_Assess  : DAL_Assessment;

   Cache_Hits   : Natural := 0;
   Cache_Misses : Natural := 0;

   package Proof_Store is new Adacovex.Cache.Serialization (Proof_Summary);
   package Test_Store is new Adacovex.Cache.Serialization (Test_Summary);

   procedure Verbose (Msg : String) is
   begin
      if Cfg.Verbose then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, Msg);
      end if;
   end Verbose;

   --  Collapse "." and ".." segments out of an absolute path so File_Path
   --  values stored in the result cache do not depend on how --target was
   --  spelled (e.g. "./.." vs ".").  Keeps the leading slash and clamps ".."
   --  at the filesystem root.
   function Normalize_Path (S : String) return String is
      Out_Buf : String (1 .. Max_Path) := (others => ' ');
      Out_Len : Natural := 0;
      Seg_Buf : String (1 .. 512) := (others => ' ');
      Seg_Len : Natural := 0;
      I       : Natural := S'First;

      procedure Flush_Seg is
      begin
         if Seg_Len = 0 then
            return;
         end if;
         if Seg_Len = 1 and then Seg_Buf (1) = '.' then
            null;
         elsif Seg_Len = 2
           and then Seg_Buf (1) = '.'
           and then Seg_Buf (2) = '.'
         then
            while Out_Len > 0 and then Out_Buf (Out_Len) /= '/' loop
               Out_Len := Out_Len - 1;
            end loop;
            if Out_Len > 1 then
               Out_Len := Out_Len - 1;
            end if;
         else
            if Out_Len > 0 and then Out_Buf (Out_Len) /= '/' then
               Out_Len := Out_Len + 1;
               Out_Buf (Out_Len) := '/';
            end if;
            if Out_Len + Seg_Len <= Out_Buf'Last then
               Out_Buf (Out_Len + 1 .. Out_Len + Seg_Len) :=
                 Seg_Buf (1 .. Seg_Len);
               Out_Len := Out_Len + Seg_Len;
            end if;
         end if;
         Seg_Len := 0;
      end Flush_Seg;

   begin
      if S'Length >= 1 and then S (S'First) = '/' then
         Out_Len := 1;
         Out_Buf (1) := '/';
      end if;
      while I <= S'Last loop
         if S (I) = '/' then
            Flush_Seg;
         else
            if Seg_Len < Seg_Buf'Last then
               Seg_Len := Seg_Len + 1;
               Seg_Buf (Seg_Len) := S (I);
            end if;
         end if;
         I := I + 1;
      end loop;
      Flush_Seg;
      if Out_Len = 0 then
         Out_Len := 1;
         Out_Buf (1) := '/';
      end if;
      return Out_Buf (1 .. Out_Len);
   end Normalize_Path;

   Success : Boolean;
   Exit_St : Ada.Command_Line.Exit_Status := 0;

   --  Differential mode (--compare-base): assess the target at a git base
   --  ref and at the current working tree, report the delta, and set the
   --  exit code to 1 on regression or current DAL failure.
   procedure Run_Diff is
      Base_Ref  : constant String :=
        Cfg.Compare_Base (1 .. Cfg.Compare_Base_Len);
      Tmp_Path  : String (1 .. Max_Path);
      Tmp_Len   : Natural := 0;
      OK        : Boolean;
      Base_R    : Adacovex.Diff.Assessment_Result;
      Cur_R     : Adacovex.Diff.Assessment_Result;
      Regressed : Boolean;
   begin
      if not Adacovex.Diff.Is_Git_Repo (Target (1 .. TLen)) then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "Error: --compare-base requires "
            & Target (1 .. TLen)
            & " to be a git repository");
         Exit_St := 1;
         return;
      end if;

      Adacovex.Diff.Make_Worktree
        (Target (1 .. TLen), Base_Ref, Tmp_Path, Tmp_Len, OK);
      if not OK then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "Error: could not create worktree for base ref '"
            & Base_Ref
            & "' (ref not found or not a git repo)");
         Exit_St := 1;
         return;
      end if;

      Verbose ("base worktree: " & Tmp_Path (1 .. Tmp_Len));
      Base_R := Adacovex.Diff.Assess (Tmp_Path (1 .. Tmp_Len), Cfg.DAL_Target);
      Cur_R := Adacovex.Diff.Assess (Target (1 .. TLen), Cfg.DAL_Target);

      Regressed :=
        Adacovex.Diff.Report_Delta (Base_R, Cur_R, Base_Ref, Use_Color);

      Adacovex.Diff.Remove_Worktree
        (Target (1 .. TLen), Tmp_Path (1 .. Tmp_Len));

      if Regressed or else Cur_R.DAL_Status = Unmet then
         Exit_St := 1;
      else
         Exit_St := 0;
      end if;
   end Run_Diff;

   --  Coverage-gate mode (--coverage-delta): compare docstring coverage at a
   --  git base ref against the current working tree. Only scans sources and
   --  computes docstring metrics, so it works even when the base revision
   --  does not commit build artifacts. Exit code is 1 if coverage dropped.
   procedure Run_Coverage is
      Base_Ref  : constant String :=
        Cfg.Coverage_Delta (1 .. Cfg.Coverage_Delta_Len);
      Tmp_Path  : String (1 .. Max_Path);
      Tmp_Len   : Natural := 0;
      OK        : Boolean;
      Base_R    : Adacovex.Diff.Coverage_Result;
      Cur_R     : Adacovex.Diff.Coverage_Result;
      Regressed : Boolean;
   begin
      if not Adacovex.Diff.Is_Git_Repo (Target (1 .. TLen)) then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "Error: --coverage-delta requires "
            & Target (1 .. TLen)
            & " to be a git repository");
         Exit_St := 1;
         return;
      end if;

      Adacovex.Diff.Make_Worktree
        (Target (1 .. TLen), Base_Ref, Tmp_Path, Tmp_Len, OK);
      if not OK then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "Error: could not create worktree for base ref '"
            & Base_Ref
            & "' (ref not found or not a git repo)");
         Exit_St := 1;
         return;
      end if;

      Verbose ("base worktree: " & Tmp_Path (1 .. Tmp_Len));
      Base_R := Adacovex.Diff.Assess_Coverage (Tmp_Path (1 .. Tmp_Len));
      Cur_R := Adacovex.Diff.Assess_Coverage (Target (1 .. TLen));

      Regressed :=
        Adacovex.Diff.Report_Coverage_Delta
          (Base_R, Cur_R, Base_Ref, Use_Color);

      Adacovex.Diff.Remove_Worktree
        (Target (1 .. TLen), Tmp_Path (1 .. Tmp_Len));

      if Regressed then
         Exit_St := 1;
      else
         Exit_St := 0;
      end if;
   end Run_Coverage;

   --  Generate an SBOM for the target using the assessment state already
   --  computed (Packages, Proof, DAL_Assess).  Used by both the explicit
   --  `adacovex sbom` subcommand and the automatic SBOM emitted at the end
   --  of every assessment.  Prints the SBOM location on success; never
   --  raises and never changes the assessment exit code (failures are
   --  warnings only).
   procedure Generate_SBOM
     (Skip_List : String;
      SLen      : Natural;
      Out_Path  : String;
      Fail_Hard : Boolean := False)
   is
      Proof_Prop : String (1 .. 16);
      PPLen      : Natural := 0;
      Graph      : Adacovex.Types.Implementation.Component_Vectors.Vector;
      GOK, WOK   : Boolean;
   begin
      declare
         D : constant String :=
           Adacovex.Renderers.SBOM.Proof_Level_Property (Proof.Level);
      begin
         PPLen := D'Length;
         for I in 1 .. PPLen loop
            Proof_Prop (I) := D (D'First + I - 1);
         end loop;
      end;

      Adacovex.Parsers.Manifest.Build_Dependency_Graph
        (Target (1 .. TLen),
         Cfg.Manifest_Path (1 .. Cfg.Manifest_Len),
         Graph,
         GOK);
      if not GOK then
         if Fail_Hard then
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "Error: could not resolve dependency graph (no manifest?)");
         else
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "Warning: could not resolve dependency graph; skipping SBOM");
         end if;
         if Fail_Hard then
            Exit_St := 1;
         end if;
         return;
      end if;

      Adacovex.Renderers.SBOM.Write_SBOM
        (Cfg.SBOM_Format,
         Out_Path,
         Graph,
         Proof_Prop (1 .. PPLen),
         Cfg.Standard_Target,
         Cfg.DAL_Target,
         WOK);

      if WOK then
         Ada.Text_IO.Put_Line
           ("SBOM written to "
            & Out_Path
            & " ("
            & Img (Natural (Graph.Length))
            & " components, root proof level "
            & Proof_Prop (1 .. PPLen)
            & ", standard "
            & Adacovex.Types.To_String (Cfg.Standard_Target)
            & ", level "
            & Adacovex.Types.Standard_Level_Name
                (Cfg.Standard_Target, Cfg.DAL_Target)
            & ")");
      --  Do NOT touch Exit_St here: the automatic SBOM (Fail_Hard False)
      --  must never change the assessment exit code.  Only the explicit
      --  `adacovex sbom` subcommand (Fail_Hard True) leaves the default 0
      --  on success.

      else
         if Fail_Hard then
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "Error: could not write SBOM to " & Out_Path);
            Exit_St := 1;
         else
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "Warning: could not write SBOM to " & Out_Path);
         end if;
      end if;
   end Generate_SBOM;

   --  SBOM mode (adacovex sbom): run the assessment pipeline to derive the
   --  proof-aware properties, resolve the dependency graph from the Alire
   --  manifest / alire.lock / .gpr files, and emit a CycloneDX 1.5, SPDX
   --  2.3, or Markdown document.  Exit code is 0 when the SBOM is written,
   --  1 on failure; the DAL status is informational only.
   procedure Run_SBOM is
      Skip_List : String (1 .. Max_Path);
      SLen      : Natural := 0;
      Skipped   : Natural;
      Out_Path  : constant String := Cfg.SBOM_Out (1 .. Cfg.SBOM_Out_Len);
   begin
      Verbose ("sbom mode: resolving dependency graph and generating SBOM...");

      if not Cfg.Strict_Mode then
         SLen := Cfg.Skip_Dir_Ct;
         for I in 1 .. SLen loop
            Skip_List (I) := Cfg.Skip_Dirs (I);
         end loop;
      end if;
      Adacovex.Parsers.Source.Scan_Project_Cached
        (Target (1 .. TLen),
         Skip_List (1 .. SLen),
         Packages,
         Skipped,
         Cache_Hits,
         Cache_Misses,
         Use_Cache => Cfg.Cache_Enabled);
      if Skipped > 0 then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "Warning: "
            & Img (Skipped)
            & " source file(s) skipped: line exceeds Max_Line");
      end if;
      if Cfg.Strict_Mode then
         Adacovex.Parsers.Source.Apply_Patches (Target (1 .. TLen), Packages);
      end if;
      Doc_Metrics :=
        Adacovex.Parsers.Source.Compute_Docstring_Metrics (Packages);

      Adacovex.Parsers.GNATprove.Parse_Prove_From_Project
        (Target (1 .. TLen), Proof, Success);
      Adacovex.Parsers.Tests.Parse_Test_Result_From_Project
        (Target (1 .. TLen), Tests, Success);
      Adacovex.Compliance.DAL.Assess_Standard
        (Cfg.Standard_Target,
         Cfg.DAL_Target,
         Target (1 .. TLen),
         Packages,
         Proof,
         Tests,
         DAL_Assess);

      Generate_SBOM (Skip_List (1 .. SLen), SLen, Out_Path, Fail_Hard => True);
   end Run_SBOM;

begin
   Cfg := Adacovex.Config.Parse_CLI;

   if Cfg.CLI_Error then
      Ada.Command_Line.Set_Exit_Status (1);
      return;
   end if;

   if Cfg.Help_Requested then
      Ada.Command_Line.Set_Exit_Status (0);
      return;
   end if;

   --  Determine ANSI color support (assume TTY, overridden by NO_COLOR)
   Use_Color := not Ada.Environment_Variables.Exists ("NO_COLOR");

   TLen := Cfg.Target_Len;
   for I in 1 .. TLen loop
      Target (I) := Cfg.Target_Path (I);
   end loop;
   declare
      Norm : constant String := Normalize_Path (Target (1 .. TLen));
   begin
      TLen := Norm'Length;
      Target (1 .. TLen) := Norm;
   end;

   Verbose ("target: " & Target (1 .. TLen));

   --  Configure the on-disk result cache.
   if Cfg.Cache_Enabled then
      if Cfg.Cache_Dir_Len > 0 then
         Adacovex.Cache.Set_Cache_Dir (Cfg.Cache_Dir (1 .. Cfg.Cache_Dir_Len));
      end if;
      Adacovex.Cache.Set_Cache_Policy (Cfg.Cache_Max_Entries);
      Verbose
        ("result cache: enabled (cap=" & Img (Cfg.Cache_Max_Entries) & ")");
   else
      Verbose ("result cache: disabled");
   end if;

   Verbose ("strict mode: " & (if Cfg.Strict_Mode then "on" else "off"));
   if Cfg.Strict_Mode then
      Verbose ("  patches: .adacovex/patches/ applied");
   else
      Verbose ("  skip list: " & Cfg.Skip_Dirs (1 .. Cfg.Skip_Dir_Ct));
   end if;

   -- Status mode: report toolchain + platform status and exit (no
   -- assessment, no scanning).  Run_Status never deploys or downloads
   -- anything, so it prints its own header and skips the normal one.
   if Cfg.Status_Mode then
      declare
         OK : Boolean;
      begin
         Adacovex.Prove.Run_Status (Target (1 .. TLen), OK);
         Ada.Command_Line.Set_Exit_Status (if OK then 0 else 1);
      end;
      return;
   end if;

   Ada.Text_IO.Put_Line
     ("adacovex v" & Adacovex.Version & " -- " & Target (1 .. TLen));
   if Cfg.Manifest_Len > 0 then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "  manifest: " & Cfg.Manifest_Path (1 .. Cfg.Manifest_Len));
   end if;

   -- Differential mode: compare against a git base ref and exit.
   if Cfg.Compare_Base_Len > 0 then
      Run_Diff;
      Ada.Command_Line.Set_Exit_Status (Exit_St);
      return;
   end if;

   -- Coverage-gate mode: check docstring coverage delta against a base ref.
   if Cfg.Coverage_Delta_Len > 0 then
      Run_Coverage;
      Ada.Command_Line.Set_Exit_Status (Exit_St);
      return;
   end if;

   -- Prove mode: run gnatprove on the target, then fall through to the normal
   -- assessment pipeline (which parses the freshly generated gnatprove.out).
   -- gnatprove is resolved from the toolchain, so the target needs no
   -- alire.toml dependency.
   if Cfg.Prove_Mode then
      Verbose ("prove mode: resolving gnatprove and running proof...");
      declare
         OK   : Boolean;
         Opts : constant Adacovex.Prove.Prove_Options :=
           (Jobs              => Cfg.Prove_Jobs,
            Level             => Cfg.Prove_Level,
            Timeout           => Cfg.Prove_Timeout,
            Steps             => Cfg.Prove_Steps,
            Memlimit          => Cfg.Prove_Memlimit,
            Force             => Cfg.Prove_Force,
            No_Loop_Unrolling => Cfg.Prove_No_Loop_Unroll,
            No_Inlining       => Cfg.Prove_No_Inlining,
            Cache             => Cfg.Cache_Enabled);
      begin
         Adacovex.Prove.Run_Prove (Target (1 .. TLen), Opts, OK);
         if not OK then
            Ada.Command_Line.Set_Exit_Status (1);
            return;
         end if;
      end;
   end if;

   -- SBOM mode: generate a proof-aware software bill of materials.
   if Cfg.SBOM_Mode then
      Run_SBOM;
      Ada.Command_Line.Set_Exit_Status (Exit_St);
      return;
   end if;

   -- Step 1: Scan source files (strict mode scans everything + applies patches)
   Verbose ("step 1/8: scanning source files...");
   declare
      Skip_List : String (1 .. Max_Path);
      SLen      : Natural := 0;
   begin
      if not Cfg.Strict_Mode then
         SLen := Cfg.Skip_Dir_Ct;
         for I in 1 .. SLen loop
            Skip_List (I) := Cfg.Skip_Dirs (I);
         end loop;
      end if;
      Adacovex.Parsers.Source.Scan_Project_Cached
        (Target (1 .. TLen),
         Skip_List (1 .. SLen),
         Packages,
         Skipped_Ct,
         Cache_Hits,
         Cache_Misses,
         Use_Cache => Cfg.Cache_Enabled);
      if Skipped_Ct > 0 then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "Warning: "
            & Img (Skipped_Ct)
            & " source file(s) skipped: line exceeds Max_Line");
      end if;
   end;
   Verbose ("  found " & Img (Natural (Packages.Length)) & " packages");

   -- Apply docstring patches when in strict mode
   if Cfg.Strict_Mode then
      Verbose ("step 1b: applying docstring patches...");
      Adacovex.Parsers.Source.Apply_Patches (Target (1 .. TLen), Packages);
   end if;

   Doc_Metrics := Adacovex.Parsers.Source.Compute_Docstring_Metrics (Packages);
   Verbose
     ("  docstrings:"
      & Img (Doc_Metrics.Documented_Subprogs)
      & "/"
      & Img (Doc_Metrics.Total_Subprograms));

   -- Step 2: Parse GNATprove output
   Verbose ("step 2/8: parsing GNATprove output...");
   declare
      Pth   : constant String :=
        Adacovex.Parsers.GNATprove.Find_Prove_Output (Target (1 .. TLen));
      Key   : String (1 .. 72);
      Key_L : Natural;
      Blob  : String (1 .. Adacovex.Cache.Max_Cache_Blob);
      Blen  : Natural;
      Found : Boolean;
   begin
      if Cfg.Cache_Enabled and then Pth'Length > 0 then
         declare
            H : constant String := Adacovex.Cache.Hash_File (Pth);
         begin
            Key (1 .. 6) := "prove:";
            Key (7 .. 6 + H'Length) := H;
            Key_L := 6 + H'Length;
            Adacovex.Cache.Get_Cached (Key (1 .. Key_L), Blob, Blen, Found);
            if Found and then Proof_Store.Deserialize (Blob (1 .. Blen), Proof)
            then
               Cache_Hits := Cache_Hits + 1;
               Success := True;
            else
               Adacovex.Parsers.GNATprove.Parse_Prove_From_Project
                 (Target (1 .. TLen), Proof, Success);
               if Success then
                  Cache_Misses := Cache_Misses + 1;
                  declare
                     S_Blob : constant String := Proof_Store.Serialize (Proof);
                  begin
                     if S_Blob'Length > 0 then
                        Adacovex.Cache.Put_Cached
                          (Key (1 .. Key_L), S_Blob, Success);
                     end if;
                  end;
               end if;
            end if;
         end;
      else
         Adacovex.Parsers.GNATprove.Parse_Prove_From_Project
           (Target (1 .. TLen), Proof, Success);
      end if;
   end;
   Verbose
     ("  spark level: "
      & Adacovex.Types.To_String (Proof.Level)
      & " ("
      & Img (Proof.Total_VCs)
      & " VCs)");

   -- Step 3: Parse test results
   Verbose ("step 3/8: parsing test results...");
   declare
      Pth   : constant String :=
        Adacovex.Parsers.Tests.Find_Test_Result (Target (1 .. TLen));
      Key   : String (1 .. 72);
      Key_L : Natural;
      Blob  : String (1 .. Adacovex.Cache.Max_Cache_Blob);
      Blen  : Natural;
      Found : Boolean;
   begin
      if Cfg.Cache_Enabled and then Pth'Length > 0 then
         declare
            H : constant String := Adacovex.Cache.Hash_File (Pth);
         begin
            Key (1 .. 6) := "tests:";
            Key (7 .. 6 + H'Length) := H;
            Key_L := 6 + H'Length;
            Adacovex.Cache.Get_Cached (Key (1 .. Key_L), Blob, Blen, Found);
            if Found and then Test_Store.Deserialize (Blob (1 .. Blen), Tests)
            then
               Cache_Hits := Cache_Hits + 1;
               Success := True;
            else
               Adacovex.Parsers.Tests.Parse_Test_Result_From_Project
                 (Target (1 .. TLen), Tests, Success);
               if Success then
                  Cache_Misses := Cache_Misses + 1;
                  declare
                     S_Blob : constant String := Test_Store.Serialize (Tests);
                  begin
                     if S_Blob'Length > 0 then
                        Adacovex.Cache.Put_Cached
                          (Key (1 .. Key_L), S_Blob, Success);
                     end if;
                  end;
               end if;
            end if;
         end;
      else
         Adacovex.Parsers.Tests.Parse_Test_Result_From_Project
           (Target (1 .. TLen), Tests, Success);
      end if;
   end;

   -- Step 4: Assess compliance (standard-aware level label)
   Verbose ("step 4/8: assessing compliance...");
   declare
      Field : Desc_Field := (others => ' ');
   begin
      Adacovex.Compliance.DAL.Assess_Standard
        (Cfg.Standard_Target,
         Cfg.DAL_Target,
         Target (1 .. TLen),
         Packages,
         Proof,
         Tests,
         DAL_Assess);
      if Skipped_Ct > 0 then
         --  A skipped source file means the source set is incomplete; the
         --  assessment cannot claim compliance for unread code, so the DAL is
         --  Unmet regardless of the other criteria.
         declare
            Msg : constant String :=
              Img (Skipped_Ct)
              & " source file(s) skipped: line exceeds Max_Line";
         begin
            if Msg'Length <= Max_Desc_Str then
               Field (1 .. Msg'Length) := Msg;
            end if;
            DAL_Assess.Failed_Reasons.Append (Field);
         end;
         DAL_Assess.Status := Unmet;
         Exit_St := 1;
      end if;
   end;
   Verbose ("  dal status: " & Adacovex.Types.To_String (DAL_Assess.Status));

   --  CI threshold gates (--require-spark / --require-docstrings /
   --  --require-tests / --require-proof).  When set, the assessment fails
   --  loudly (exit code 1, explicit reason) if the target is below the
   --  pinned minimum -- an extra gate on top of the DAL criteria that lets a
   --  workflow require e.g. Platinum SPARK, 100% docstrings, 336 passing
   --  tests, and 100% proved VCs and fail if any slips.
   declare
      All_Pass : Boolean := True;
      Prf_Cov  : Natural := 0;
   begin
      if Proof.Total_VCs > 0 then
         Prf_Cov := (Proof.Proved_VCs * 100) / Proof.Total_VCs;
      end if;

      if Cfg.Require_SPARK_Set and then Proof.Level < Cfg.Require_SPARK then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "  CI GATE: SPARK level "
            & Adacovex.Types.To_String (Proof.Level)
            & " below required "
            & Adacovex.Types.To_String (Cfg.Require_SPARK)
            & " (--require-spark)");
         All_Pass := False;
      end if;

      if Cfg.Require_Docstrings_Set
        and then Doc_Metrics.Coverage_Pct < Cfg.Require_Docstrings
      then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "  CI GATE: docstring coverage "
            & Img (Doc_Metrics.Coverage_Pct)
            & "% below required "
            & Img (Cfg.Require_Docstrings)
            & "% (--require-docstrings)");
         All_Pass := False;
      end if;

      if Cfg.Require_Tests_Set and then Tests.Total_Passed < Cfg.Require_Tests
      then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "  CI GATE: "
            & Img (Tests.Total_Passed)
            & " passing tests below required "
            & Img (Cfg.Require_Tests)
            & " (--require-tests)");
         All_Pass := False;
      end if;

      if Cfg.Require_Proof_Set and then Prf_Cov < Cfg.Require_Proof then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "  CI GATE: proved-VC coverage "
            & Img (Prf_Cov)
            & "% below required "
            & Img (Cfg.Require_Proof)
            & "% (--require-proof)");
         All_Pass := False;
      end if;

      if not All_Pass then
         Exit_St := 1;
      end if;
   end;

   if DAL_Assess.Status /= Achieved then
      Exit_St := 1;
   end if;

   -- Step 5: Render ANSI summary (stdout)
   Verbose ("step 5/8: rendering ANSI report...");
   Adacovex.Renderers.ANSI.Render_Summary
     (Doc_Metrics,
      Proof,
      Tests,
      DAL_Assess,
      Packages,
      Use_Color,
      Cfg.Standard_All,
      Cache_Hits,
      Cache_Misses,
      Adacovex.Cache.Eviction_Count);

   -- Step 6: Emit SVG badges if requested
   if Cfg.Emit_SVG then
      Verbose ("step 6/8: emitting SVG badges...");
      declare
         Dir : String renames Cfg.SVG_Path (1 .. Cfg.SVG_Path_Len);
      begin
         Adacovex.Renderers.SVG.Write_Badge_To_File
           (Dir & "/spark.svg",
            Adacovex.Renderers.SVG.Render_SPARK_Badge (Proof.Level));
         Adacovex.Renderers.SVG.Write_Badge_To_File
           (Dir & "/tests.svg",
            Adacovex.Renderers.SVG.Render_Tests_Badge (Tests));
         if Cfg.Standard_All then
            for Std in Adacovex.Types.Compliance_Standard loop
               Adacovex.Renderers.SVG.Write_Badge_To_File
                 (Dir & "/" & Adacovex.Types.Standard_Slug (Std) & ".svg",
                  Adacovex.Renderers.SVG.Render_Compliance_Badge
                    (DAL_Assess, Std));
            end loop;
         else
            Adacovex.Renderers.SVG.Write_Badge_To_File
              (Dir
               & "/"
               & Adacovex.Types.Standard_Slug (DAL_Assess.Standard)
               & ".svg",
               Adacovex.Renderers.SVG.Render_Compliance_Badge
                 (DAL_Assess, DAL_Assess.Standard));
         end if;
         Adacovex.Renderers.SVG.Write_Badge_To_File
           (Dir & "/docs.svg",
            Adacovex.Renderers.SVG.Render_Docstring_Badge (Doc_Metrics));
         Verbose ("  svg badges written to " & Dir);
      end;
   end if;

   -- Step 7: Emit Markdown reports if requested
   if Cfg.Emit_Markdown then
      Verbose ("step 7/8: emitting Markdown reports...");
      declare
         Dir : String renames Cfg.MD_Path (1 .. Cfg.MD_Path_Len);
      begin
         Adacovex.Renderers.Markdown.Generate_Verification_Report
           (Dir & "/VERIFICATION.md",
            Doc_Metrics,
            Proof,
            Tests,
            DAL_Assess,
            Packages,
            Cfg.Standard_All);
         Adacovex.Renderers.Markdown.Generate_Trace_Matrix
           (Dir & "/TRACE.md", Packages);
      end;
      Verbose
        ("  markdown reports written to "
         & Cfg.MD_Path (1 .. Cfg.MD_Path_Len));
   end if;

   -- Step 8: Automatically emit a proof-aware SBOM (unless --no-sbom)
   if not Cfg.No_SBOM then
      Verbose
        ("step 8/9: generating automatic SBOM in "
         & SBOM_Format_Kind'Image (Cfg.SBOM_Format)
         & " format...");
      declare
         Skip_List : String (1 .. Max_Path);
         SLen      : Natural := 0;
      begin
         if not Cfg.Strict_Mode then
            SLen := Cfg.Skip_Dir_Ct;
            for I in 1 .. SLen loop
               Skip_List (I) := Cfg.Skip_Dirs (I);
            end loop;
         end if;
         Generate_SBOM
           (Skip_List (1 .. SLen), SLen, Cfg.SBOM_Out (1 .. Cfg.SBOM_Out_Len));
      end;
   end if;

   -- Step 9: Start HTTP server if requested
   if Cfg.Serve_Mode then
      Verbose
        ("step 9/9: starting HTTP server on port"
         & Img (Natural (Cfg.Port))
         & "...");
      declare
         State : Adacovex.Server.HTTP.Server_State;
      begin
         State.Port := Cfg.Port;
         State.Doc_Metrics := Doc_Metrics;
         State.Proof := Proof;
         State.Tests := Tests;
         State.DAL_Assess := DAL_Assess;
         State.Packages := Packages;
         State.All_Standards := Cfg.Standard_All;
         Adacovex.Server.HTTP.Start (State);
      end;
   end if;

   -- Timing footer
   declare
      Elapsed : constant Duration := Clock - Start_Time;
   begin
      Ada.Text_IO.Put_Line ("Completed in" & Duration'Image (Elapsed));
   end;

   Ada.Command_Line.Set_Exit_Status (Exit_St);

exception
   when E : others =>
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "Error: " & Ada.Exceptions.Exception_Message (E));
      Ada.Command_Line.Set_Exit_Status (1);
end Adacovex_Main;
