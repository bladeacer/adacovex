with Ada.Text_IO;
with Ada.Exceptions;
with Ada.Calendar;
with Ada.Environment_Variables;
with Ada.Command_Line;
with Adacovex.Types;
with Adacovex.Config;
with Adacovex.Parsers.Source;
with Adacovex.Parsers.GNATprove;
with Adacovex.Parsers.Tests;
with Adacovex.Compliance.DAL;
with Adacovex.Renderers.ANSI;
with Adacovex.Renderers.SVG;
with Adacovex.Renderers.Markdown;
with Adacovex.Server.HTTP;

procedure Adacovex_Main is
   use Ada.Calendar;
   use Adacovex.Types;

   Start_Time : constant Time := Clock;
   Cfg        : Adacovex.Config.CLI_Config;
   Target     : String (1 .. Max_Path);
   TLen       : Natural;

   Use_Color : Boolean := False;

   Packages  : Package_Vectors.Vector;

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

   Success  : Boolean;
   Exit_St  : Ada.Command_Line.Exit_Status := 0;
   begin
      Cfg := Adacovex.Config.Parse_CLI;

      if Cfg.CLI_Error then
         Ada.Command_Line.Set_Exit_Status (1);
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
   Verbose ("  found " & Natural'Image (Natural (Packages.Length)) & " packages");

   -- Apply docstring patches when in strict mode
   if Cfg.Strict_Mode then
      Verbose ("step 1b: applying docstring patches...");
      Adacovex.Parsers.Source.Apply_Patches
        (Target (1 .. TLen), Packages);
   end if;

   Doc_Metrics :=
     Adacovex.Parsers.Source.Compute_Docstring_Metrics (Packages);
   Verbose ("  docstrings:"
            & Natural'Image (Doc_Metrics.Documented_Subprogs) & "/"
            & Natural'Image (Doc_Metrics.Total_Subprograms));

   -- Step 2: Parse GNATprove output
   Verbose ("step 2/8: parsing GNATprove output...");
   Adacovex.Parsers.GNATprove.Parse_Prove_From_Project
     (Target (1 .. TLen), Proof, Success);
   Verbose ("  spark level: "
            & Adacovex.Types.To_String (Proof.Level)
            & " (" & Natural'Image (Proof.Total_VCs) & " VCs)");

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
     (Cfg.DAL_Target,
      Target (1 .. TLen),
      Packages,
      Proof,
      Tests,
      DAL_Assess);
   Verbose ("  dal status: "
            & Adacovex.Types.To_String (DAL_Assess.Status));

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
      Verbose ("  markdown reports written to " & Cfg.MD_Path (1 .. Cfg.MD_Path_Len));
   end if;

   -- Step 8: Start HTTP server if requested
   if Cfg.Serve_Mode then
      Verbose ("step 8/8: starting HTTP server on port"
               & Positive'Image (Cfg.Port) & "...");
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
