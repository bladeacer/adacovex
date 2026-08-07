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

   procedure Verbose (Msg : String) is
   begin
      if Cfg.Verbose then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, Msg);
      end if;
   end Verbose;

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
      DAL_Prop   : String (1 .. 8);
      DPLen      : Natural := 0;
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
      declare
         D : constant String :=
           Adacovex.Renderers.SBOM.DAL_Property_Value (Cfg.DAL_Target);
      begin
         DPLen := D'Length;
         for I in 1 .. DPLen loop
            DAL_Prop (I) := D (D'First + I - 1);
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
         DAL_Prop (1 .. DPLen),
         WOK);

      if WOK then
         Ada.Text_IO.Put_Line
           ("SBOM written to "
            & Out_Path
            & " ("
            & Img (Natural (Graph.Length))
            & " components, root proof level "
            & Proof_Prop (1 .. PPLen)
            & ", DAL target "
            & (if DPLen > 0 then DAL_Prop (1 .. DPLen) else "none")
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
      Adacovex.Parsers.Source.Scan_Project
        (Target (1 .. TLen), Skip_List (1 .. SLen), Packages, Skipped);
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
      Adacovex.Compliance.DAL.Assess_DAL
        (Cfg.DAL_Target,
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

   Verbose ("target: " & Target (1 .. TLen));
   Verbose ("strict mode: " & (if Cfg.Strict_Mode then "on" else "off"));
   if Cfg.Strict_Mode then
      Verbose ("  patches: .adacovex/patches/ applied");
   else
      Verbose ("  skip list: " & Cfg.Skip_Dirs (1 .. Cfg.Skip_Dir_Ct));
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
         OK : Boolean;
      begin
         Adacovex.Prove.Run_Prove (Target (1 .. TLen), OK);
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
      Adacovex.Parsers.Source.Scan_Project
        (Target (1 .. TLen), Skip_List (1 .. SLen), Packages, Skipped_Ct);
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
   Adacovex.Parsers.GNATprove.Parse_Prove_From_Project
     (Target (1 .. TLen), Proof, Success);
   Verbose
     ("  spark level: "
      & Adacovex.Types.To_String (Proof.Level)
      & " ("
      & Img (Proof.Total_VCs)
      & " VCs)");

   -- Step 3: Parse test results
   Verbose ("step 3/8: parsing test results...");
   Adacovex.Parsers.Tests.Parse_Test_Result_From_Project
     (Target (1 .. TLen), Tests, Success);

   -- Step 4: Assess DAL compliance
   Verbose ("step 4/8: assessing DAL compliance...");
   declare
      Field : Desc_Field := (others => ' ');
   begin
      Adacovex.Compliance.DAL.Assess_DAL
        (Cfg.DAL_Target,
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

   if DAL_Assess.Status /= Achieved then
      Exit_St := 1;
   end if;

   -- Step 5: Render ANSI summary (stdout)
   Verbose ("step 5/8: rendering ANSI report...");
   Adacovex.Renderers.ANSI.Render_Summary
     (Doc_Metrics, Proof, Tests, DAL_Assess, Packages, Use_Color);

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
         Adacovex.Renderers.SVG.Write_Badge_To_File
           (Dir & "/do178c.svg",
            Adacovex.Renderers.SVG.Render_DO178C_Badge (DAL_Assess));
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
            Packages);
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
