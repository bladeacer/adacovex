with Ada.Text_IO;    use Ada.Text_IO;
with Ada.Directories;
with Adacovex.Types; use Adacovex.Types;
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
      R.Check
        (Natural (Pkg.Subprograms.Length) = 3, "Test 1: 3 subprograms found");
      R.Check (Natural (Pkg.HLR_Tags.Length) = 1, "Test 1: 1 HLR tag found");
      R.Check
        (Pkg.HLR_Tags (1).Len = 4
         and then Pkg.HLR_Tags (1).Tag (1 .. 4) = "SCAN",
         "Test 1: HLR tag = SCAN");

      --  Check subprogram names
      R.Check
        (Pkg.Subprograms (1).Name_Len = 3
         and then Pkg.Subprograms (1).Name (1 .. 3) = "Add",
         "Test 1: Subp 1 = Add");
      R.Check (Pkg.Subprograms (1).Has_Docstring, "Test 1: Add has docstring");
      R.Check
        (Pkg.Subprograms (1).Doc_Param_Ct = 2,
         "Test 1: Add has 2 documented params");
      R.Check
        (Pkg.Subprograms (1).Doc_Return, "Test 1: Add has documented return");

      R.Check
        (Pkg.Subprograms (2).Name_Len = 3
         and then Pkg.Subprograms (2).Name (1 .. 3) = "Log",
         "Test 1: Subp 2 = Log");
      R.Check (Pkg.Subprograms (2).Has_Docstring, "Test 1: Log has docstring");
      R.Check
        (Pkg.Subprograms (2).Doc_Param_Ct = 1,
         "Test 1: Log has 1 documented param");
      R.Check
        (not Pkg.Subprograms (2).Doc_Return, "Test 1: Log has no return");

      R.Check
        (Pkg.Subprograms (3).Name_Len = 7
         and then Pkg.Subprograms (3).Name (1 .. 7) = "No_Docs",
         "Test 1: Subp 3 = No_Docs");
      R.Check
        (not Pkg.Subprograms (3).Has_Docstring,
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
      R.Check
        (Natural (Pkg.Subprograms.Length) >= 1,
         "Test 2: at least 1 subprogram");
      --  The named subprogram (Clone) should be last
      declare
         Last_Subp : constant Positive := Positive (Pkg.Subprograms.Length);
      begin
         R.Check (Last_Subp >= 1, "Test 2: has subprograms");
         if Last_Subp >= 1 then
            R.Check
              (Pkg.Subprograms (Last_Subp).Name_Len = 5
               and then Pkg.Subprograms (Last_Subp).Name (1 .. 5) = "Clone",
               "Test 2: last subp = Clone");
            R.Check
              (Pkg.Subprograms (Last_Subp).Has_Docstring,
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
      R.Check (Natural (Pkg.Subprograms.Length) = 0, "Test 3: 0 subprograms");
      --  Package name from filename "test_pkg.ads" -> "test_pkg"
      R.Check
        (Pkg.Name_Len = 8 and then Pkg.Name (1 .. 8) = "test_pkg",
         "Test 3: package name from filename = test_pkg");

      --  Test 4: Compute_Docstring_Metrics with known data
      declare
         SP1  : Subprogram_Info := (others => <>);
         SP2  : Subprogram_Info := (others => <>);
         SP3  : Subprogram_Info := (others => <>);
         SP4  : Subprogram_Info := (others => <>);
         SP5  : Subprogram_Info := (others => <>);
         P1   : Package_Info := (others => <>);
         P2   : Package_Info := (others => <>);
         Pkgs : Package_Vectors.Vector;
      begin
         SP1.Has_Docstring := True;
         SP2.Has_Docstring := True;
         SP3.Has_Docstring := True;
         SP4.Has_Docstring := False;
         SP5.Has_Docstring := False;
         P1.Subprograms.Append (SP1);
         P1.Subprograms.Append (SP2);
         P2.Subprograms.Append (SP3);
         P2.Subprograms.Append (SP4);
         P2.Subprograms.Append (SP5);
         Pkgs.Append (P1);
         Pkgs.Append (P2);

         declare
            M : constant Docstring_Metrics :=
              Adacovex.Parsers.Source.Compute_Docstring_Metrics (Pkgs);
         begin
            R.Check
              (M.Total_Subprograms = 5,
               "Compute_Metrics: total subprograms = 5");
            R.Check
              (M.Documented_Subprogs = 3, "Compute_Metrics: documented = 3");
            R.Check (M.Coverage_Pct = 60, "Compute_Metrics: coverage = 60%");
         end;
      end;

      --  Test 5: Compute_Docstring_Metrics with empty data
      declare
         M : constant Docstring_Metrics :=
           Adacovex.Parsers.Source.Compute_Docstring_Metrics
             (Package_Vectors.Empty_Vector);
      begin
         R.Check (M.Total_Subprograms = 0, "Compute_Metrics empty: total = 0");
         R.Check (M.Coverage_Pct = 0, "Compute_Metrics empty: coverage = 0%");
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
      R.Check
        (Natural (Pkg.Subprograms.Length) >= 1,
         "Test 6: at least 1 subprogram");
      declare
         Add_Idx : constant Positive := Positive (Pkg.Subprograms.Length);
      begin
         R.Check (Add_Idx >= 1, "Test 6: has subprograms");
         if Add_Idx >= 1 then
            R.Check
              (Pkg.Subprograms (Add_Idx).Has_Docstring,
               "Test 6: after-decl tags attached to last subprogram");
            R.Check
              (Pkg.Subprograms (Add_Idx).Doc_Param_Ct >= 2,
               "Test 6: after-decl has 2 documented params");
            R.Check
              (Pkg.Subprograms (Add_Idx).Doc_Return,
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
      R.Check
        (Natural (Pkg.Subprograms.Length) >= 1,
         "Test 7: at least 1 subprogram");
      R.Check
        (Pkg.Subprograms (Positive (Pkg.Subprograms.Length)).Has_Docstring,
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
      R.Check
        (Natural (Pkg.Subprograms.Length) >= 1,
         "Test 8: at least 1 subprogram");
      R.Check
        (not Pkg.Subprograms (Positive (Pkg.Subprograms.Length)).Has_Docstring,
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
