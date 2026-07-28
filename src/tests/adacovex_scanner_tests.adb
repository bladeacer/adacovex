with Ada.Text_IO;             use Ada.Text_IO;
with Ada.Directories;
with Adacovex.Types;          use Adacovex.Types;
with Adacovex.Parsers.Source;

package body Adacovex_Scanner_Tests is

   Tmp_Dir  : constant String := "/tmp/adacovex_scan_test";
   Tmp_File : constant String := Tmp_Dir & "/test_pkg.ads";

   procedure Run (R : in out Adacovex.Test_Support.Runner'Class) is
      Pkg     : Package_Info;
      Success : Boolean;
   begin
      --  Create temp directory
      begin
         Ada.Directories.Create_Path (Tmp_Dir);
      exception
         when others =>
            null;
      end;

      --  Test 1: scan a file with procedure and function, docstring tags, HLR tag
      begin
         declare
            F : File_Type;
         begin
            Create (F, Out_File, Tmp_File);
            Put_Line (F, "--  HLR-SCAN: Test scanner");
            Put_Line (F, "--");
            Put_Line (F, "package Test_Pkg is");
            Put_Line (F, "   pragma Pure;");
            Put_Line (F, "   --  @param X  First parameter.");
            Put_Line (F, "   --  @param Y  Second parameter.");
            Put_Line (F, "   --  @return The sum.");
            Put_Line (F, "   function Add (X, Y : Integer) return Integer;");
            Put_Line (F, "   --  @param Msg  The message.");
            Put_Line (F, "   procedure Log (Msg : String);");
            Put_Line (F, "   procedure No_Docs;");
            Put_Line (F, "end Test_Pkg;");
            Close (F);
         end;
      end;

      Adacovex.Parsers.Source.Scan_Ads_File (Tmp_File, Pkg, Success);
      R.Check (Success, "Test 1: parse succeeded");
      R.Check (Pkg.Name_Len > 0, "Test 1: package name length > 0");
      R.Check (Pkg.Subprogram_Count = 3, "Test 1: 3 subprograms found");
      R.Check (Pkg.Total_HLR_Tags = 1, "Test 1: 1 HLR tag found");
      R.Check
        (Pkg.HLR_Tags (1).Len = 4
         and then Pkg.HLR_Tags (1).Tag (1 .. 4) = "SCAN",
         "Test 1: HLR tag = SCAN");

      --  Check subprogram names
      R.Check
        (Pkg.Subprogram_List (1).Name_Len = 3
         and then Pkg.Subprogram_List (1).Name (1 .. 3) = "Add",
         "Test 1: Subp 1 = Add");
      R.Check
        (Pkg.Subprogram_List (1).Has_Docstring,
         "Test 1: Add has docstring");
      R.Check
        (Pkg.Subprogram_List (1).Doc_Param_Ct = 2,
         "Test 1: Add has 2 documented params");
      R.Check
        (Pkg.Subprogram_List (1).Doc_Return,
         "Test 1: Add has documented return");

      R.Check
        (Pkg.Subprogram_List (2).Name_Len = 3
         and then Pkg.Subprogram_List (2).Name (1 .. 3) = "Log",
         "Test 1: Subp 2 = Log");
      R.Check
        (Pkg.Subprogram_List (2).Has_Docstring,
         "Test 1: Log has docstring");
      R.Check
        (Pkg.Subprogram_List (2).Doc_Param_Ct = 1,
         "Test 1: Log has 1 documented param");
      R.Check
        (not Pkg.Subprogram_List (2).Doc_Return,
         "Test 1: Log has no return");

      R.Check
        (Pkg.Subprogram_List (3).Name_Len = 7
         and then Pkg.Subprogram_List (3).Name (1 .. 7) = "No_Docs",
         "Test 1: Subp 3 = No_Docs");
      R.Check
        (not Pkg.Subprogram_List (3).Has_Docstring,
         "Test 1: No_Docs has no docstring");

      --  Test 2: scan a file with generic function.
      --  `generic` on its own is not detected as a subprogram declaration,
      --  so only `function Clone` counts. The pending docstring tags
      --  (started before `generic`) attach to Clone via Flush_Pending.
      begin
         declare
            F : File_Type;
         begin
            Create (F, Out_File, Tmp_File);
            Put_Line (F, "package Test_Gen is");
            Put_Line (F, "   generic");
            Put_Line (F, "      type T is private;");
            Put_Line (F, "   --  @param Value  The value to clone.");
            Put_Line (F, "   --  @return Cloned value.");
            Put_Line (F, "   function Clone (Value : T) return T;");
            Put_Line (F, "end Test_Gen;");
            Close (F);
         end;
      end;

      Adacovex.Parsers.Source.Scan_Ads_File (Tmp_File, Pkg, Success);
      R.Check (Success, "Test 2: parse succeeded");
      --  only Clone detected, generic line is not a separate subprogram
      R.Check (Pkg.Subprogram_Count >= 1, "Test 2: at least 1 subprogram");
      --  The named subprogram (Clone) should be last
      declare
         Last_Subp : constant Natural := Pkg.Subprogram_Count;
      begin
         R.Check (Last_Subp >= 1, "Test 2: has subprograms");
         if Last_Subp >= 1 then
            R.Check
              (Pkg.Subprogram_List (Last_Subp).Name_Len = 5
               and then Pkg.Subprogram_List (Last_Subp).Name (1 .. 5) = "Clone",
               "Test 2: last subp = Clone");
            R.Check
              (Pkg.Subprogram_List (Last_Subp).Has_Docstring,
               "Test 2: Clone has docstring");
         end if;
      end;

      --  Test 3: scan a file with no subprograms (just a package decl).
      --  Package name is derived from filename (test_pkg.ads -> "test_pkg"),
      --  NOT from parsing `package Just_A_Package is` in the source.
      begin
         declare
            F : File_Type;
         begin
            Create (F, Out_File, Tmp_File);
            Put_Line (F, "package Just_A_Package is");
            Put_Line (F, "   pragma Pure;");
            Put_Line (F, "end Just_A_Package;");
            Close (F);
         end;
      end;

      Adacovex.Parsers.Source.Scan_Ads_File (Tmp_File, Pkg, Success);
      R.Check (Success, "Test 3: parse succeeded");
      R.Check (Pkg.Subprogram_Count = 0, "Test 3: 0 subprograms");
      --  Package name from filename "test_pkg.ads" -> "test_pkg"
      R.Check
        (Pkg.Name_Len = 8 and then Pkg.Name (1 .. 8) = "test_pkg",
         "Test 3: package name from filename = test_pkg");

      --  Test 4: Compute_Docstring_Metrics with known data
      declare
         Packages : Package_Array;
      begin
         --  Package 1: 2 subprograms, both documented
         Packages (1).Subprogram_Count := 2;
         Packages (1).Subprogram_List (1).Has_Docstring := True;
         Packages (1).Subprogram_List (2).Has_Docstring := True;

         --  Package 2: 3 subprograms, 1 documented
         Packages (2).Subprogram_Count := 3;
         Packages (2).Subprogram_List (1).Has_Docstring := True;
         Packages (2).Subprogram_List (2).Has_Docstring := False;
         Packages (2).Subprogram_List (3).Has_Docstring := False;

         declare
            M : constant Docstring_Metrics :=
              Adacovex.Parsers.Source.Compute_Docstring_Metrics (Packages, 2);
         begin
            R.Check
              (M.Total_Subprograms = 5,
               "Compute_Metrics: total subprograms = 5");
            R.Check
              (M.Documented_Subprogs = 3,
               "Compute_Metrics: documented = 3");
            R.Check
              (M.Coverage_Pct = 60,
               "Compute_Metrics: coverage = 60%");
         end;
      end;

      --  Test 5: Compute_Docstring_Metrics with empty data
      declare
         M : constant Docstring_Metrics :=
           Adacovex.Parsers.Source.Compute_Docstring_Metrics
             ((others => <>), 0);
      begin
         R.Check
           (M.Total_Subprograms = 0,
            "Compute_Metrics empty: total = 0");
         R.Check
           (M.Coverage_Pct = 0,
            "Compute_Metrics empty: coverage = 0%");
      end;

      --  Test 6: After-declaration docstring tags on last subprogram
      begin
         declare
            F : File_Type;
         begin
            Create (F, Out_File, Tmp_File);
            Put_Line (F, "package After_Decl is");
            Put_Line (F, "   pragma Pure;");
            Put_Line (F, "   function Add (X, Y : Integer) return Integer;");
            Put_Line (F, "   --  @param X  First parameter.");
            Put_Line (F, "   --  @param Y  Second parameter.");
            Put_Line (F, "   --  @return The sum.");
            Put_Line (F, "end After_Decl;");
            Close (F);
         end;
      end;

      Adacovex.Parsers.Source.Scan_Ads_File (Tmp_File, Pkg, Success);
      R.Check (Success, "Test 6: parse succeeded");
      R.Check (Pkg.Subprogram_Count >= 1, "Test 6: at least 1 subprogram");
      declare
         Add_Idx : constant Natural := Pkg.Subprogram_Count;
      begin
         R.Check (Add_Idx >= 1, "Test 6: has subprograms");
         if Add_Idx >= 1 then
            R.Check
              (Pkg.Subprogram_List (Add_Idx).Has_Docstring,
               "Test 6: after-decl tags attached to last subprogram");
            R.Check
              (Pkg.Subprogram_List (Add_Idx).Doc_Param_Ct >= 2,
               "Test 6: after-decl has 2 documented params");
            R.Check
              (Pkg.Subprogram_List (Add_Idx).Doc_Return,
               "Test 6: after-decl has documented return");
         end if;
      end;

      --  Test 7: @field tag support
      begin
         declare
            F : File_Type;
         begin
            Create (F, Out_File, Tmp_File);
            Put_Line (F, "package Field_Test is");
            Put_Line (F, "   pragma Pure;");
            Put_Line (F, "   --  @field Some component description.");
            Put_Line (F, "   procedure Proc;");
            Put_Line (F, "end Field_Test;");
            Close (F);
         end;
      end;

      Adacovex.Parsers.Source.Scan_Ads_File (Tmp_File, Pkg, Success);
      R.Check (Success, "Test 7: parse succeeded");
      R.Check (Pkg.Subprogram_Count >= 1, "Test 7: at least 1 subprogram");
      R.Check
        (Pkg.Subprogram_List (Pkg.Subprogram_Count).Has_Docstring,
         "Test 7: @field sets Has_Docstring");

      --  Test 8: @formal tag (recognized but does not set Has_Docstring)
      begin
         declare
            F : File_Type;
         begin
            Create (F, Out_File, Tmp_File);
            Put_Line (F, "package Formal_Test is");
            Put_Line (F, "   pragma Pure;");
            Put_Line (F, "   --  @formal T  Generic type parameter.");
            Put_Line (F, "   procedure Proc;");
            Put_Line (F, "end Formal_Test;");
            Close (F);
         end;
      end;

      Adacovex.Parsers.Source.Scan_Ads_File (Tmp_File, Pkg, Success);
      R.Check (Success, "Test 8: parse succeeded");
      R.Check (Pkg.Subprogram_Count >= 1, "Test 8: at least 1 subprogram");
      R.Check
        (not Pkg.Subprogram_List (Pkg.Subprogram_Count).Has_Docstring,
         "Test 8: @formal alone does not set Has_Docstring");

      --  Cleanup
      begin
         Ada.Directories.Delete_File (Tmp_File);
         Ada.Directories.Delete_Tree (Tmp_Dir);
      exception
         when others =>
            null;
      end;

   end Run;

end Adacovex_Scanner_Tests;
