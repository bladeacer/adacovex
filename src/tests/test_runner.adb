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
with Adacovex_Cache_Tests;
with Adacovex_IR_Tests;
with Adacovex_Man_Tests;
with Adacovex_VCS_Tests;
with Adacovex_Server_Tests;
with Adacovex_Prove_Patch_Tests;
with Adacovex_TZ_ANSI_Tests;
with Adacovex_Complexity_Tests;
with Adacovex_Opt_Outs_Tests;
with Adacovex_Dir_Cache_Tests;
with Adacovex_Diff_Tests;
with Adacovex_Prove_Runner_Tests;
with Adacovex_ANSI_Tests;
with Adacovex_CPUs_Tests;
with Adacovex_Do178C_Tests;
with Adacovex_Completion_Tests;

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
   R_Cache       : Runner;
   R_IR          : Runner;
   R_Man         : Runner;
   R_VCS         : Runner;
   R_Server      : Runner;
   R_ProvePatch  : Runner;
   R_TZANSI      : Runner;
   R_Complexity  : Runner;
   R_OptOuts     : Runner;
   R_DirCache    : Runner;
   R_Diff        : Runner;
   R_ProveRunner : Runner;
   R_ANSI        : Runner;
   R_CPUs        : Runner;
   R_Do178C      : Runner;
   R_Completion  : Runner;

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
         Row ("Result cache", R_Cache);
         Row ("IR synthesis", R_IR);
         Row ("Man page renderer", R_Man);
         Row ("VCS support", R_VCS);
         Row ("Server routing", R_Server);
         Row ("Proof patches", R_ProvePatch);
         Row ("Timezone + ANSI", R_TZANSI);
         Row ("Complexity check", R_Complexity);
         Row ("Opt-out markers", R_OptOuts);
         Row ("Dir cache", R_DirCache);
         Row ("Diff reports", R_Diff);
         Row ("Prove runner", R_ProveRunner);
         Row ("ANSI terminal report", R_ANSI);
         Row ("CPU and jobs", R_CPUs);
         Row ("HLR/LLR parsing", R_Do178C);
         Row ("Completion scripts", R_Completion);
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
         Row ("Result cache", R_Cache);
         Row ("IR synthesis", R_IR);
         Row ("Man page renderer", R_Man);
         Row ("VCS support", R_VCS);
         Row ("Server routing", R_Server);
         Row ("Proof patches", R_ProvePatch);
         Row ("Timezone + ANSI", R_TZANSI);
         Row ("Complexity check", R_Complexity);
         Row ("Opt-out markers", R_OptOuts);
         Row ("Dir cache", R_DirCache);
         Row ("Diff reports", R_Diff);
         Row ("Prove runner", R_ProveRunner);
         Row ("ANSI terminal report", R_ANSI);
         Row ("CPU and jobs", R_CPUs);
         Row ("HLR/LLR parsing", R_Do178C);
         Row ("Completion scripts", R_Completion);
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
   Adacovex_Cache_Tests.Run (R_Cache);
   Adacovex_IR_Tests.Run (R_IR);
   Adacovex_Man_Tests.Run (R_Man);
   Adacovex_VCS_Tests.Run (R_VCS);
   Adacovex_Server_Tests.Run (R_Server);
   Adacovex_Prove_Patch_Tests.Run (R_ProvePatch);
   Adacovex_TZ_ANSI_Tests.Run (R_TZANSI);
   Adacovex_Complexity_Tests.Run (R_Complexity);
   Adacovex_Opt_Outs_Tests.Run (R_OptOuts);
   Adacovex_Dir_Cache_Tests.Run (R_DirCache);
   Adacovex_Diff_Tests.Run (R_Diff);
   Adacovex_Prove_Runner_Tests.Run (R_ProveRunner);
   Adacovex_ANSI_Tests.Run (R_ANSI);
   Adacovex_CPUs_Tests.Run (R_CPUs);
   Adacovex_Do178C_Tests.Run (R_Do178C);
   Adacovex_Completion_Tests.Run (R_Completion);

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
     + R_Cache.Passed
     + R_IR.Passed
     + R_Man.Passed
     + R_VCS.Passed
     + R_Server.Passed
     + R_ProvePatch.Passed
     + R_TZANSI.Passed
     + R_Complexity.Passed
     + R_OptOuts.Passed
     + R_DirCache.Passed
     + R_Diff.Passed
     + R_ProveRunner.Passed
     + R_ANSI.Passed
     + R_CPUs.Passed
     + R_Do178C.Passed
     + R_Completion.Passed;
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
     + R_Cache.Failed
     + R_IR.Failed
     + R_Man.Failed
     + R_VCS.Failed
     + R_Server.Failed
     + R_ProvePatch.Failed
     + R_TZANSI.Failed
     + R_Complexity.Failed
     + R_OptOuts.Failed
     + R_DirCache.Failed
     + R_Diff.Failed
     + R_ProveRunner.Failed
     + R_ANSI.Failed
     + R_CPUs.Failed
     + R_Do178C.Failed
     + R_Completion.Failed;

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
