with Ada.Text_IO;
with Ada.Exceptions;
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
   use Adacovex.Types;
   Cfg   : Adacovex.Config.CLI_Config;
   Target : String (1 .. Max_Path);
   TLen  : Natural;

   Packages  : Package_Array;
   Pkg_Count : Natural;

   Doc_Metrics : Docstring_Metrics;
   Proof       : Proof_Summary;
   Tests       : Test_Summary;
   DAL_Assess  : DAL_Assessment;

   Success : Boolean;
begin
   Cfg := Adacovex.Config.Parse_CLI;

   TLen := Cfg.Target_Len;
   for I in 1 .. TLen loop
      Target (I) := Cfg.Target_Path (I);
   end loop;

    Ada.Text_IO.Put_Line ("adacovex v" & Adacovex.Version);
    Ada.Text_IO.Put_Line ("Target: " & Target (1 .. TLen));
    if Cfg.Manifest_Len > 0 then
       declare
          MPath : String renames Cfg.Manifest_Path (1 .. Cfg.Manifest_Len);
       begin
          Ada.Text_IO.Put_Line ("Manifest: " & MPath);
       end;
    end if;
    Ada.Text_IO.New_Line;

   -- Step 1: Scan source files
   Ada.Text_IO.Put_Line ("Scanning Ada sources...");
   Adacovex.Parsers.Source.Scan_Project
     (Target (1 .. TLen), Packages, Pkg_Count);
   Doc_Metrics :=
     Adacovex.Parsers.Source.Compute_Docstring_Metrics
       (Packages, Pkg_Count);
   Ada.Text_IO.Put_Line
     ("  Found" & Natural'Image (Pkg_Count) & " packages");
   Ada.Text_IO.New_Line;

   -- Step 2: Parse GNATprove output
   declare
      GP_Path : constant String :=
        Target (1 .. TLen) & "/obj/gnatprove/gnatprove.out";
   begin
      Ada.Text_IO.Put_Line ("Parsing GNATprove output...");
      Adacovex.Parsers.GNATprove.Parse_Prove_Out
        (GP_Path, Proof, Success);
      if Success then
         Ada.Text_IO.Put_Line
           ("  SPARK Level: " & To_String (Proof.Level));
      else
         Ada.Text_IO.Put_Line ("  Could not read GNATprove output");
      end if;
      Ada.Text_IO.New_Line;
   end;

   -- Step 3: Parse test results
   declare
      T_Path : constant String :=
        Target (1 .. TLen) & "/test_result.md";
   begin
      Ada.Text_IO.Put_Line ("Parsing test results...");
      Adacovex.Parsers.Tests.Parse_Test_Result
        (T_Path, Tests, Success);
      if Success then
         Ada.Text_IO.Put_Line
           ("  Passed:" & Natural'Image (Tests.Total_Passed) &
            "  Failed:" & Natural'Image (Tests.Total_Failed));
      else
         Ada.Text_IO.Put_Line ("  Could not read test results");
      end if;
      Ada.Text_IO.New_Line;
   end;

   -- Step 4: Assess DAL compliance
   Ada.Text_IO.Put_Line ("Assessing DO-178C DAL compliance...");
   Adacovex.Compliance.DAL.Assess_DAL_C
     (Target (1 .. TLen), Packages, Pkg_Count,
      Proof, Tests, DAL_Assess);
   Ada.Text_IO.Put_Line
     ("  Status: " & To_String (DAL_Assess.Status));
   Ada.Text_IO.New_Line;

   -- Step 5: Render ANSI summary
   Adacovex.Renderers.ANSI.Render_Summary
     (Doc_Metrics, Proof, Tests, DAL_Assess, Packages, Pkg_Count);

   -- Step 6: Emit SVG badges if requested
   if Cfg.Emit_SVG then
      declare
         Dir : String renames
           Cfg.SVG_Path (1 .. Cfg.SVG_Path_Len);
      begin
         Ada.Text_IO.Put_Line
           ("Writing SVG badges to " & Dir & "...");
         Adacovex.Renderers.SVG.Write_Badge_To_File
           (Dir & "/spark.svg",
            Adacovex.Renderers.SVG.Render_SPARK_Badge (Proof.Level));
         Adacovex.Renderers.SVG.Write_Badge_To_File
           (Dir & "/tests.svg",
            Adacovex.Renderers.SVG.Render_Tests_Badge (Tests));
         Adacovex.Renderers.SVG.Write_Badge_To_File
           (Dir & "/do178c.svg",
            Adacovex.Renderers.SVG.Render_DO178C_Badge (DAL_Assess));
         Ada.Text_IO.Put_Line ("  Done.");
      end;
   end if;

   -- Step 7: Emit Markdown reports if requested
   if Cfg.Emit_Markdown then
      declare
         Dir : String renames
           Cfg.MD_Path (1 .. Cfg.MD_Path_Len);
      begin
         Ada.Text_IO.Put_Line
           ("Writing Markdown reports to " & Dir & "...");
         Adacovex.Renderers.Markdown.Generate_Verification_Report
           (Dir & "/VERIFICATION.md",
            Doc_Metrics, Proof, Tests, DAL_Assess,
            Packages, Pkg_Count);
         Adacovex.Renderers.Markdown.Generate_Trace_Matrix
           (Dir & "/TRACE.md", Packages, Pkg_Count);
         Ada.Text_IO.Put_Line ("  Done.");
      end;
   end if;

   -- Step 8: Start HTTP server if requested
   if Cfg.Serve_Mode then
      declare
         State : Adacovex.Server.HTTP.Server_State;
      begin
         State.Port := Cfg.Port;
         State.Doc_Metrics := Doc_Metrics;
         State.Proof := Proof;
         State.Tests := Tests;
         State.DAL_Assess := DAL_Assess;
         State.Packages := Packages;
         State.Pkg_Count := Pkg_Count;
         Adacovex.Server.HTTP.Start (State);
      end;
   end if;

exception
   when E : others =>
      Ada.Text_IO.Put_Line
        ("Error: " & Ada.Exceptions.Exception_Message (E));
end Adacovex_Main;
