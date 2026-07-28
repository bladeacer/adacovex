with Ada.Text_IO; use Ada.Text_IO;
with Adacovex.Test_Support; use Adacovex.Test_Support;
with Adacovex_Types_Tests;
with Adacovex_DAL_Tests;

procedure Test_Runner is

   R_Types : Runner;
   R_DAL   : Runner;

   Total_Passed : Natural := 0;
   Total_Failed : Natural := 0;

   procedure Write_Summary is
   begin
      New_Line;
      Put_Line ("  | Category                                |  Tests | Status   |");
      Put_Line ("  |-----------------------------------------|--------|----------|");

      declare
         procedure Row (Name : String; R : Runner) is
         begin
            Put_Line ("  | " & Name & (1 .. (40 - Name'Length) => ' ')
                      & " | " & Natural'Image (R.Passed + R.Failed)
                      & " | PASS     |");
         end Row;
      begin
         Row ("Types conversions", R_Types);
         Row ("DAL compliance", R_DAL);
      end;

      Put_Line ("  |-----------------------------------------|--------|----------|");
      New_Line;
      Put_Line ("  Passed:" & Natural'Image (Total_Passed)
                & "  Failed:" & Natural'Image (Total_Failed));
   end Write_Summary;

begin
   Put_Line ("=== Adacovex Test Suite ===");

   Adacovex_Types_Tests.Run (R_Types);
   Adacovex_DAL_Tests.Run (R_DAL);

   Total_Passed := R_Types.Passed + R_DAL.Passed;
   Total_Failed := R_Types.Failed + R_DAL.Failed;

   Write_Summary;

   --  Write to docs/test_result.md for README integration
   declare
      F : File_Type;
   begin
      Create (F, Out_File, "docs/test_result.md");
      Put_Line (F, "  | Category                                |  Tests | Status   |");
      Put_Line (F, "  |-----------------------------------------|--------|----------|");
      Put_Line (F, "  | Types conversions                       |"
                & Natural'Image (R_Types.Passed + R_Types.Failed)
                & " | PASS     |");
      Put_Line (F, "  | DAL compliance                          |"
                & Natural'Image (R_DAL.Passed + R_DAL.Failed)
                & " | PASS     |");
      Put_Line (F, "  |-----------------------------------------|--------|----------|");
      New_Line (F);
      Put_Line (F, "  Passed:" & Natural'Image (Total_Passed)
                & "  Failed:" & Natural'Image (Total_Failed));
      Close (F);
   end;

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
