with Ada.Text_IO;           use Ada.Text_IO;
with Adacovex.Test_Support; use Adacovex.Test_Support;
with Adacovex_Types_Tests;
with Adacovex_DAL_Tests;
with Adacovex_Scanner_Tests;
with Adacovex_Prove_Tests;
with Adacovex_TestParser_Tests;
with Adacovex_Config_Tests;
with Adacovex_Renderer_SVG_Tests;
with Adacovex_Renderer_Tests;
with Adacovex_SBOM_Tests;
with Adacovex_IR_Tests;

procedure Test_Runner is

   R_Types       : Runner;
   R_DAL         : Runner;
   R_Scanner     : Runner;
   R_Prove       : Runner;
   R_TestParser  : Runner;
   R_Config      : Runner;
   R_RendererSVG : Runner;
   R_Renderers   : Runner;
   R_SBOM        : Runner;
   R_IR          : Runner;

   Total_Passed : Natural := 0;
   Total_Failed : Natural := 0;

   procedure Write_Output (Out_File : File_Type; File_Name : String) is
   begin
      Put_Line
        (Out_File,
         "  | Category                                |  Tests | Status   |");
      Put_Line
        (Out_File,
         "  |-----------------------------------------|--------|----------|");

      declare
         procedure Row (Name : String; R : Runner) is
            TCount : constant Natural := R.Passed + R.Failed;
         begin
            Put_Line
              (Out_File,
               "  | "
               & Name
               & (1 .. (40 - Name'Length) => ' ')
               & " | "
               & Natural'Image (TCount)
               & " |"
               & (if R.Failed = 0 then " PASS     |" else " FAIL     |"));
         end Row;
      begin
         Row ("Types conversions", R_Types);
         Row ("DAL compliance", R_DAL);
         Row ("Source scanner", R_Scanner);
         Row ("GNATprove parser", R_Prove);
         Row ("Test-result parser", R_TestParser);
         Row ("CLI config", R_Config);
         Row ("SVG renderer", R_RendererSVG);
         Row ("HTML/Markdown renderers", R_Renderers);
         Row ("SBOM generator", R_SBOM);
         Row ("IR synthesis", R_IR);
      end;

      Put_Line
        (Out_File,
         "  |-----------------------------------------|--------|----------|");
      New_Line (Out_File);
      Put_Line
        (Out_File,
         "  Passed:"
         & Natural'Image (Total_Passed)
         & "  Failed:"
         & Natural'Image (Total_Failed));
   end Write_Output;

   procedure Write_Results is
      F : File_Type;
   begin
      --  Write to project root (for ./test_result.md)
      begin
         Create (F, Out_File, "test_result.md");
         Write_Output (F, "test_result.md");
         Close (F);
      exception
         when others =>
            null;
      end;

      --  Write to docs/ (for git-tracking)
      begin
         Create (F, Out_File, "docs/test_result.md");
         Write_Output (F, "docs/test_result.md");
         Close (F);
      exception
         when others =>
            null;
      end;
   end Write_Results;

   procedure Print_Summary is
   begin
      New_Line;
      Put_Line
        ("  | Category                                |  Tests | Status   |");
      Put_Line
        ("  |-----------------------------------------|--------|----------|");

      declare
         procedure Row (Name : String; R : Runner) is
            TCount : constant Natural := R.Passed + R.Failed;
         begin
            Put_Line
              ("  | "
               & Name
               & (1 .. (40 - Name'Length) => ' ')
               & " | "
               & Natural'Image (TCount)
               & " |"
               & (if R.Failed = 0 then " PASS     |" else " FAIL     |"));
         end Row;
      begin
         Row ("Types conversions", R_Types);
         Row ("DAL compliance", R_DAL);
         Row ("Source scanner", R_Scanner);
         Row ("GNATprove parser", R_Prove);
         Row ("Test-result parser", R_TestParser);
         Row ("CLI config", R_Config);
         Row ("SVG renderer", R_RendererSVG);
         Row ("HTML/Markdown renderers", R_Renderers);
         Row ("SBOM generator", R_SBOM);
         Row ("IR synthesis", R_IR);
      end;

      Put_Line
        ("  |-----------------------------------------|--------|----------|");
      New_Line;
      Put_Line
        ("  Passed:"
         & Natural'Image (Total_Passed)
         & "  Failed:"
         & Natural'Image (Total_Failed));
   end Print_Summary;

begin
   Put_Line ("=== Adacovex Test Suite ===");

   Adacovex_Types_Tests.Run (R_Types);
   Adacovex_DAL_Tests.Run (R_DAL);
   Adacovex_Scanner_Tests.Run (R_Scanner);
   Adacovex_Prove_Tests.Run (R_Prove);
   Adacovex_TestParser_Tests.Run (R_TestParser);
   Adacovex_Config_Tests.Run (R_Config);
   Adacovex_Renderer_SVG_Tests.Run (R_RendererSVG);
   Adacovex_Renderer_Tests.Run (R_Renderers);
   Adacovex_SBOM_Tests.Run (R_SBOM);
   Adacovex_IR_Tests.Run (R_IR);

   Total_Passed :=
     R_Types.Passed
     + R_DAL.Passed
     + R_Scanner.Passed
     + R_Prove.Passed
     + R_TestParser.Passed
     + R_Config.Passed
     + R_RendererSVG.Passed
     + R_Renderers.Passed
     + R_SBOM.Passed
     + R_IR.Passed;
   Total_Failed :=
     R_Types.Failed
     + R_DAL.Failed
     + R_Scanner.Failed
     + R_Prove.Failed
     + R_TestParser.Failed
     + R_Config.Failed
     + R_RendererSVG.Failed
     + R_Renderers.Failed
     + R_SBOM.Failed
     + R_IR.Failed;

   Print_Summary;
   Write_Results;

   New_Line;
   Put_Line ("=== Results ===");
   Put_Line ("  Passed:" & Natural'Image (Total_Passed));
   Put_Line ("  Failed:" & Natural'Image (Total_Failed));

   if Total_Failed = 0 then
      Put_Line ("=== ALL TESTS PASSED ===");
   else
      Put_Line ("=== SOME TESTS FAILED ===");
   end if;
end Test_Runner;
