with Ada.Text_IO;
with Ada.Directories;
with Adacovex.Types;          use Adacovex.Types;
with Adacovex.Parsers.Tests;

package body Adacovex_TestParser_Tests is

   procedure Run (R : in out Adacovex.Test_Support.Runner'Class) is
      use Ada.Text_IO;
      F        : File_Type;
      Summary  : Test_Summary;
      Success  : Boolean;
      Tmp_Path : constant String := "/tmp/adacovex_test_result.txt";
   begin

      --  Test 1: mixed pass/fail categories
      begin
         Create (F, Out_File, Tmp_Path);
         Put_Line (F, "  | - | Types conversions|21| PASS     |");
         Put_Line (F, "  | - | DAL compliance| 2| FAIL     |");
         New_Line (F);
         Put_Line (F, "  Passed: 21  Failed: 2");
         Close (F);
      end;

      Adacovex.Parsers.Tests.Parse_Test_Result (Tmp_Path, Summary, Success);
      R.Check (Success, "Test 1: parse succeeded");
      R.Check (Summary.Total_Passed = 21, "Test 1: Total_Passed = 21");
      R.Check (Summary.Total_Failed = 2, "Test 1: Total_Failed = 2");
      R.Check (Summary.Category_Count = 2, "Test 1: Category_Count = 2");
      R.Check
        (Summary.Categories (1).Cat_Len = 17
         and then Summary.Categories (1).Category (1) = 'T',
         "Test 1: Cat 1 name = 'Types conversions'");
      R.Check
        (Summary.Categories (1).Test_Count = 21,
         "Test 1: Cat 1 Test_Count = 21");
      R.Check
        (Summary.Categories (1).Status = Pass,
         "Test 1: Cat 1 Status = Pass");
      R.Check
        (Summary.Categories (2).Cat_Len = 14
         and then Summary.Categories (2).Category (1) = 'D',
         "Test 1: Cat 2 name = 'DAL compliance'");
      R.Check
        (Summary.Categories (2).Test_Count = 2,
         "Test 1: Cat 2 Test_Count = 2");
      R.Check
        (Summary.Categories (2).Status = Fail,
         "Test 1: Cat 2 Status = Fail");

      begin
         Ada.Directories.Delete_File (Tmp_Path);
      exception
         when others =>
            null;
      end;

      --  Test 2: three categories, all pass (AUnit-like)
      begin
         Create (F, Out_File, Tmp_Path);
         Put_Line (F, "  | - | CRDT.Merge|15| PASS     |");
         Put_Line (F, "  | - | CRDT.Add|10| PASS     |");
         Put_Line (F, "  | - | CRDT.Remove| 5| PASS     |");
         New_Line (F);
         Put_Line (F, "  Passed: 30  Failed: 0");
         Close (F);
      end;

      Adacovex.Parsers.Tests.Parse_Test_Result (Tmp_Path, Summary, Success);
      R.Check (Success, "Test 2: parse succeeded");
      R.Check (Summary.Total_Passed = 30, "Test 2: Total_Passed = 30");
      R.Check (Summary.Total_Failed = 0, "Test 2: Total_Failed = 0");
      R.Check (Summary.Category_Count = 3, "Test 2: Category_Count = 3");
      R.Check
        (Summary.Categories (1).Test_Count = 15
         and then Summary.Categories (1).Status = Pass,
         "Test 2: Cat 1 = CRDT.Merge 15 PASS");
      R.Check
        (Summary.Categories (2).Test_Count = 10
         and then Summary.Categories (2).Status = Pass,
         "Test 2: Cat 2 = CRDT.Add 10 PASS");
      R.Check
        (Summary.Categories (3).Test_Count = 5
         and then Summary.Categories (3).Status = Pass,
         "Test 2: Cat 3 = CRDT.Remove 5 PASS");

      begin
         Ada.Directories.Delete_File (Tmp_Path);
      exception
         when others =>
            null;
      end;

      --  Test 3: empty / zero results (no category rows)
      begin
         Create (F, Out_File, Tmp_Path);
         Put_Line (F, "  Passed: 0  Failed: 0");
         Close (F);
      end;

      Adacovex.Parsers.Tests.Parse_Test_Result (Tmp_Path, Summary, Success);
      R.Check (Success, "Test 3: parse succeeded");
      R.Check (Summary.Total_Passed = 0, "Test 3: Total_Passed = 0");
      R.Check (Summary.Total_Failed = 0, "Test 3: Total_Failed = 0");
      R.Check (Summary.Category_Count = 0, "Test 3: Category_Count = 0");

      begin
         Ada.Directories.Delete_File (Tmp_Path);
      exception
         when others =>
            null;
      end;

      --  Test 4: all categories failed
      begin
         Create (F, Out_File, Tmp_Path);
         Put_Line (F, "  | - | Unit tests|10| FAIL     |");
         Put_Line (F, "  | - | Integration tests| 5| FAIL     |");
         New_Line (F);
         Put_Line (F, "  Passed: 0  Failed: 15");
         Close (F);
      end;

      Adacovex.Parsers.Tests.Parse_Test_Result (Tmp_Path, Summary, Success);
      R.Check (Success, "Test 4: parse succeeded");
      R.Check (Summary.Total_Passed = 0, "Test 4: Total_Passed = 0");
      R.Check (Summary.Total_Failed = 15, "Test 4: Total_Failed = 15");
      R.Check (Summary.Category_Count = 2, "Test 4: Category_Count = 2");
      R.Check
        (Summary.Categories (1).Status = Fail,
         "Test 4: Cat 1 Status = Fail");
      R.Check
        (Summary.Categories (2).Status = Fail,
         "Test 4: Cat 2 Status = Fail");

      begin
         Ada.Directories.Delete_File (Tmp_Path);
      exception
         when others =>
            null;
      end;

   end Run;

end Adacovex_TestParser_Tests;
