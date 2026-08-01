with Ada.Text_IO;
with Ada.Exceptions;
with Ada.Command_Line;
with Ada.Calendar;
with Ada.Environment_Variables;
with GNAT.Sockets;
with Adacovex.Types;
with Adacovex.Config;
with Adacovex.Diff;
with Adacovex.Parsers.Source;
with Adacovex.Parsers.GNATprove;
with Adacovex.Parsers.Tests;
with Adacovex.Parsers.DO178C;
with Adacovex.Compliance.DAL;
with Adacovex.Renderers.ANSI;
with Adacovex.Renderers.SVG;
with Adacovex.Renderers.Markdown;
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

   Packages : Package_Vectors.Vector;

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
      Base_Ref : constant String := Cfg.Compare_Base (1 .. Cfg.Compare_Base_Len);
      Tmp_Path : String (1 .. Max_Path);
      Tmp_Len  : Natural := 0;
      OK       : Boolean;
      Base_R   : Adacovex.Diff.Assessment_Result;
      Cur_R    : Adacovex.Diff.Assessment_Result;
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
            "Error: could not create worktree for base ref '" & Base_Ref
            & "' (ref not found or not a git repo)");
         Exit_St := 1;
         return;
      end if;

      Verbose ("base worktree: " & Tmp_Path (1 .. Tmp_Len));
      Base_R := Adacovex.Diff.Assess (Tmp_Path (1 .. Tmp_Len), Cfg.DAL_Target);
      Cur_R := Adacovex.Diff.Assess (Target (1 .. TLen), Cfg.DAL_Target);

      Regressed := Adacovex.Diff.Report_Delta
        (Base_R, Cur_R, Base_Ref, Use_Color);

      Adacovex.Diff.Remove_Worktree (Target (1 .. TLen), Tmp_Path (1 .. Tmp_Len));

      if Regressed or else Cur_R.DAL_Status = Unmet then
         Exit_St := 1;
      else
         Exit_St := 0;
      end if;
   end Run_Diff;

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
        (Target (1 .. TLen), Skip_List (1 .. SLen), Packages);
   end;
   Verbose
     ("  found " & Img (Natural (Packages.Length)) & " packages");

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
   declare
      T_Path : constant String := Target (1 .. TLen) & "/test_result.md";
   begin
      Verbose ("step 3/8: parsing test results from " & T_Path & "...");
      Adacovex.Parsers.Tests.Parse_Test_Result (T_Path, Tests, Success);
   end;

   -- Step 4: Assess DAL compliance
   Verbose ("step 4/8: assessing DAL compliance...");
   Adacovex.Compliance.DAL.Assess_DAL
     (Cfg.DAL_Target, Target (1 .. TLen), Packages, Proof, Tests, DAL_Assess);
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

   -- Step 8: Start HTTP server if requested
   if Cfg.Serve_Mode then
      Verbose
        ("step 8/8: starting HTTP server on port"
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
