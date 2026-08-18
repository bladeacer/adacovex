with Ada.Text_IO; use Ada.Text_IO;
with Ada.Directories;
with Adacovex.Types;
use Adacovex.Types, Adacovex.Types.Implementation;
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

      --  Test 9: single-space docstring prefix (`-- `) is recognized.
      begin
         declare
            F : File_Type;
         begin
            Create (F, Out_File, Tmp_File);
            Put_Line (F, "package Style1 is");
            Put_Line (F, "   pragma Pure;");
            Put_Line (F, "   -- Clear the screen.");
            Put_Line (F, "   procedure Single_Space;");
            Put_Line (F, "end Style1;");
            Close (F);
         end;
      end;

      Adacovex.Parsers.Source.Scan_Ads_File (Tmp_File, Pkg, Success);
      R.Check (Success, "Test 9: parse succeeded");
      R.Check
        (Natural (Pkg.Subprograms.Length) >= 1
         and then Pkg.Subprograms (Positive (Pkg.Subprograms.Length))
                    .Has_Docstring,
         "Test 9: single-space `-- ` prefix sets Has_Docstring");

      --  Test 10: tab-separated docstring prefix (`--<TAB>`) is recognized.
      begin
         declare
            F : File_Type;
         begin
            Create (F, Out_File, Tmp_File);
            Put_Line (F, "package Style2 is");
            Put_Line (F, "   pragma Pure;");
            Put_Line (F, "   --" & ASCII.HT & "Clear the screen.");
            Put_Line (F, "   procedure Tab_Separated;");
            Put_Line (F, "end Style2;");
            Close (F);
         end;
      end;

      Adacovex.Parsers.Source.Scan_Ads_File (Tmp_File, Pkg, Success);
      R.Check (Success, "Test 10: parse succeeded");
      R.Check
        (Natural (Pkg.Subprograms.Length) >= 1
         and then Pkg.Subprograms (Positive (Pkg.Subprograms.Length))
                    .Has_Docstring,
         "Test 10: tab-separated prefix sets Has_Docstring");

      --  Test 11: @parameter is accepted as an alias of @param.
      begin
         declare
            F : File_Type;
         begin
            Create (F, Out_File, Tmp_File);
            Put_Line (F, "package Style3 is");
            Put_Line (F, "   pragma Pure;");
            Put_Line (F, "   --  @parameter X  First parameter.");
            Put_Line (F, "   procedure Alias_Param (X : Integer);");
            Put_Line (F, "end Style3;");
            Close (F);
         end;
      end;

      Adacovex.Parsers.Source.Scan_Ads_File (Tmp_File, Pkg, Success);
      R.Check (Success, "Test 11: parse succeeded");
      R.Check
        (Natural (Pkg.Subprograms.Length) >= 1
         and then Pkg.Subprograms (Positive (Pkg.Subprograms.Length))
                    .Has_Docstring,
         "Test 11: @parameter sets Has_Docstring");
      R.Check
        (Pkg.Subprograms (Positive (Pkg.Subprograms.Length)).Doc_Param_Ct >= 1,
         "Test 11: @parameter counts as a documented param");

      --  Test 12: @returns is accepted as an alias of @return.
      begin
         declare
            F : File_Type;
         begin
            Create (F, Out_File, Tmp_File);
            Put_Line (F, "package Style4 is");
            Put_Line (F, "   pragma Pure;");
            Put_Line (F, "   --  @returns The computed value.");
            Put_Line (F, "   function Alias_Return return Integer;");
            Put_Line (F, "end Style4;");
            Close (F);
         end;
      end;

      Adacovex.Parsers.Source.Scan_Ads_File (Tmp_File, Pkg, Success);
      R.Check (Success, "Test 12: parse succeeded");
      R.Check
        (Natural (Pkg.Subprograms.Length) >= 1
         and then Pkg.Subprograms (Positive (Pkg.Subprograms.Length))
                    .Has_Docstring,
         "Test 12: @returns sets Has_Docstring");
      R.Check
        (Pkg.Subprograms (Positive (Pkg.Subprograms.Length)).Doc_Return,
         "Test 12: @returns sets Doc_Return");

      --  Test 13: @brief and @summary mark a subprogram as documented.
      begin
         declare
            F : File_Type;
         begin
            Create (F, Out_File, Tmp_File);
            Put_Line (F, "package Style5 is");
            Put_Line (F, "   pragma Pure;");
            Put_Line (F, "   --  @brief Brief summary.");
            Put_Line (F, "   procedure Brief_Proc;");
            Put_Line (F, "   --  @summary Longer summary text.");
            Put_Line (F, "   procedure Summary_Proc;");
            Put_Line (F, "end Style5;");
            Close (F);
         end;
      end;

      Adacovex.Parsers.Source.Scan_Ads_File (Tmp_File, Pkg, Success);
      R.Check (Success, "Test 13: parse succeeded");
      R.Check
        (Natural (Pkg.Subprograms.Length) >= 2
         and then Pkg.Subprograms (1).Has_Docstring,
         "Test 13: @brief sets Has_Docstring");
      R.Check
        (Natural (Pkg.Subprograms.Length) >= 2
         and then Pkg.Subprograms (2).Has_Docstring,
         "Test 13: @summary sets Has_Docstring");

      --  Test 14: a single-line declaration longer than 8192 chars is still
      --  parsed (buffer constraints no longer silently drop generated lines).
      begin
         declare
            F    : File_Type;
            Big  : String (1 .. 12000);
            BLen : Natural := 0;
            procedure Add (S : String) is
            begin
               for I in S'Range loop
                  BLen := BLen + 1;
                  Big (BLen) := S (I);
               end loop;
            end Add;
         begin
            Create (F, Out_File, Tmp_File);
            Put_Line (F, "package Long_Line_Test is");
            Put_Line (F, "   pragma Pure;");
            Add ("   procedure Huge_Proc (");
            for I in 1 .. 600 loop
               Add
                 ("P"
                  & Natural'Image (I) (2 .. Natural'Image (I)'Last)
                  & " : Integer; ");
            end loop;
            Add ("Last : Integer);");
            Put_Line (F, Big (1 .. BLen));
            Put_Line (F, "end Long_Line_Test;");
            Close (F);
            R.Check (BLen > 8192, "Test 14: generated line exceeds old limit");
         end;
      end;

      Adacovex.Parsers.Source.Scan_Ads_File (Tmp_File, Pkg, Success);
      R.Check (Success, "Test 14: parse succeeded");
      R.Check
        (Natural (Pkg.Subprograms.Length) >= 1
         and then Pkg.Subprograms (Positive (Pkg.Subprograms.Length)).Name_Len
                  = 9
         and then Pkg.Subprograms (Positive (Pkg.Subprograms.Length)).Name
                    (1 .. 9)
                  = "Huge_Proc",
         "Test 14: subprogram on a >8192-char line is parsed");

      --  Test 15: Google-style Args:/Returns: sections.
      begin
         declare
            F : File_Type;
         begin
            Create (F, Out_File, Tmp_File);
            Put_Line (F, "package Google_Style is");
            Put_Line (F, "   --  Adds two numbers.");
            Put_Line (F, "   --  Args:");
            Put_Line (F, "   --      X (int):  First operand.");
            Put_Line (F, "   --      Y (int):  Second operand.");
            Put_Line (F, "   --  Returns:");
            Put_Line (F, "   --      The sum of X and Y.");
            Put_Line (F, "   function G_Add (X, Y : Integer) return Integer;");
            Put_Line (F, "   --  Divides two numbers.");
            Put_Line (F, "   --  Args:");
            Put_Line (F, "   --      A (int):  Dividend.");
            Put_Line (F, "   procedure G_Div (A : Integer);");
            Put_Line (F, "   procedure G_No_Docs;");
            Put_Line (F, "end Google_Style;");
            Close (F);
         end;
      end;

      Adacovex.Parsers.Source.Scan_Ads_File (Tmp_File, Pkg, Success);
      R.Check (Success, "Test 15: parse succeeded");
      R.Check
        (Natural (Pkg.Subprograms.Length) = 3, "Test 15: 3 subprograms found");
      R.Check
        (Pkg.Subprograms (1).Has_Docstring,
         "Test 15: Google Args/Returns marks documented");
      R.Check
        (Pkg.Subprograms (1).Doc_Param_Ct = 2,
         "Test 15: Google Args block counts 2 params");
      R.Check
        (Pkg.Subprograms (1).Doc_Return,
         "Test 15: Google Returns marks return");
      R.Check
        (Pkg.Subprograms (2).Has_Docstring
         and then Pkg.Subprograms (2).Doc_Param_Ct = 1,
         "Test 15: Google Args single param");
      R.Check
        (not Pkg.Subprograms (3).Has_Docstring,
         "Test 15: no docstring without section headers");

      --  Test 16: Sphinx-style reST field lists.
      begin
         declare
            F : File_Type;
         begin
            Create (F, Out_File, Tmp_File);
            Put_Line (F, "package Sphinx_Style is");
            Put_Line (F, "   --  Subtracts two numbers.");
            Put_Line (F, "   --  :param X: First operand.");
            Put_Line (F, "   --  :param Y: Second operand.");
            Put_Line (F, "   --  :returns: The difference.");
            Put_Line (F, "   function S_Sub (X, Y : Integer) return Integer;");
            Put_Line (F, "   --  Prints a message.");
            Put_Line (F, "   --  :param Msg: The message to print.");
            Put_Line (F, "   --  :rtype: None.");
            Put_Line (F, "   procedure S_Print (Msg : String);");
            Put_Line (F, "   procedure S_No_Docs;");
            Put_Line (F, "end Sphinx_Style;");
            Close (F);
         end;
      end;

      Adacovex.Parsers.Source.Scan_Ads_File (Tmp_File, Pkg, Success);
      R.Check (Success, "Test 16: parse succeeded");
      R.Check
        (Natural (Pkg.Subprograms.Length) = 3, "Test 16: 3 subprograms found");
      R.Check
        (Pkg.Subprograms (1).Has_Docstring
         and then Pkg.Subprograms (1).Doc_Param_Ct = 2
         and then Pkg.Subprograms (1).Doc_Return,
         "Test 16: Sphinx :param:/:returns: parsed");
      R.Check
        (Pkg.Subprograms (2).Has_Docstring
         and then Pkg.Subprograms (2).Doc_Param_Ct = 1,
         "Test 16: Sphinx :param: single + :rtype: documented");
      R.Check
        (not Pkg.Subprograms (3).Has_Docstring,
         "Test 16: no docstring without field lists");

      --  Test 17: a physical line longer than Max_Line is rejected explicitly.
      --  The file must not be processed (no partial AST), and Scan_Ads_File
      --  returns Success = False.
      begin
         declare
            F    : File_Type;
            Big  : String (1 .. Adacovex.Types.Max_Line + 100);
            BLen : Natural := 0;
         begin
            for I in Big'Range loop
               Big (BLen + 1) := 'x';
               BLen := BLen + 1;
            end loop;
            Create (F, Out_File, Tmp_File);
            Put_Line (F, "package Overflow_Test is");
            Put_Line (F, "   pragma Pure;");
            Put_Line (F, Big (1 .. BLen));
            Put_Line (F, "   procedure Proc;");
            Put_Line (F, "end Overflow_Test;");
            Close (F);
            R.Check
              (BLen = Adacovex.Types.Max_Line + 100,
               "Test 17: overflow line exceeds Max_Line");
         end;
      end;

      Adacovex.Parsers.Source.Scan_Ads_File (Tmp_File, Pkg, Success);
      R.Check (not Success, "Test 17: overflow line makes scan fail");
      R.Check
        (Natural (Pkg.Subprograms.Length) = 0,
         "Test 17: no partial AST on overflow");

      --  Test 18: a physical line exactly Max_Line chars long (exact buffer
      --  fit) is NOT an overflow; the following lines still parse.
      begin
         declare
            F    : File_Type;
            Big  : String (1 .. Adacovex.Types.Max_Line);
            BLen : Natural := 0;
         begin
            for I in Big'Range loop
               Big (BLen + 1) := 'y';
               BLen := BLen + 1;
            end loop;
            Create (F, Out_File, Tmp_File);
            Put_Line (F, "package Exact_Fit_Test is");
            Put_Line (F, "   pragma Pure;");
            Put_Line (F, Big (1 .. BLen));
            Put_Line (F, "   procedure After_Exact;");
            Put_Line (F, "end Exact_Fit_Test;");
            Close (F);
            R.Check
              (BLen = Adacovex.Types.Max_Line,
               "Test 18: exact-fit line = Max_Line");
         end;
      end;

      Adacovex.Parsers.Source.Scan_Ads_File (Tmp_File, Pkg, Success);
      R.Check (Success, "Test 18: exact-fit line parses fine");
      R.Check
        (Natural (Pkg.Subprograms.Length) >= 1
         and then Pkg.Subprograms (Positive (Pkg.Subprograms.Length)).Name_Len
                  = 11
         and then Pkg.Subprograms (Positive (Pkg.Subprograms.Length)).Name
                    (1 .. 11)
                  = "After_Exact",
         "Test 18: subprogram after exact-fit line is parsed");

      --  Test 19: Scan_Project counts files skipped for line overflow in
      --  Skipped_Ct and keeps parsing the rest of the tree.
      begin
         declare
            F    : File_Type;
            Big  : String (1 .. Adacovex.Types.Max_Line + 100);
            BLen : Natural := 0;
         begin
            for I in Big'Range loop
               Big (BLen + 1) := 'z';
               BLen := BLen + 1;
            end loop;
            Create (F, Out_File, Tmp_File);
            Put_Line (F, "package Overflow_Scan is");
            Put_Line (F, "   pragma Pure;");
            Put_Line (F, Big (1 .. BLen));
            Put_Line (F, "end Overflow_Scan;");
            Close (F);
         end;
         declare
            Pkgs       : Package_Vectors.Vector;
            Skipped_Ct : Natural;
            Ok_File    : constant String := Tmp_Dir & "/ok_pkg.ads";
         begin
            declare
               F : File_Type;
            begin
               Create (F, Out_File, Ok_File);
               Put_Line (F, "package Ok_Pkg is");
               Put_Line (F, "   --  @param X  A parameter.");
               Put_Line (F, "   procedure Ok_Proc (X : Integer);");
               Put_Line (F, "end Ok_Pkg;");
               Close (F);
            end;
            Adacovex.Parsers.Source.Scan_Project
              (Tmp_Dir, "", Pkgs, Skipped_Ct);
            R.Check
              (Skipped_Ct = 1, "Test 19: Skipped_Ct counts overflow file");
            R.Check
              (Natural (Pkgs.Length) = 1,
               "Test 19: healthy .ads still parsed");
            Ada.Directories.Delete_File (Ok_File);
         end;
      end;

      --  Test 20: oversized subprogram names, HLR tags, and docstring values
      --  are clamped to their fixed buffers instead of raising
      --  Constraint_Error.
      begin
         declare
            F      : File_Type;
            Big    : String (1 .. 200);
            HLR    : String (1 .. 70);
            Doc    : String (1 .. 200);
            BigLen : Natural := 0;
         begin
            for I in Big'Range loop
               Big (I) := (if I mod 2 = 0 then 'a' else 'b');
               BigLen := BigLen + 1;
            end loop;
            for I in HLR'Range loop
               HLR (I) := 'A';
            end loop;
            for I in Doc'Range loop
               Doc (I) := 'x';
            end loop;
            Create (F, Out_File, Tmp_File);
            Put_Line (F, "--  HLR-" & HLR);
            Put_Line (F, "package Oversized is");
            Put_Line (F, "   pragma Pure;");
            Put_Line (F, "   --  @param X  " & Doc);
            Put_Line (F, "   procedure " & Big & " (X : Integer);");
            Put_Line (F, "end Oversized;");
            Close (F);
         end;

         Adacovex.Parsers.Source.Scan_Ads_File (Tmp_File, Pkg, Success);
         R.Check (Success, "Test 20: oversized input parses without crash");
         R.Check
           (Natural (Pkg.HLR_Tags.Length) = 1
            and then Pkg.HLR_Tags (1).Len = Adacovex.Types.Max_Id_Str,
            "Test 20: HLR tag clamped to Max_Id_Str");
         R.Check
           (Natural (Pkg.Subprograms.Length) = 1
            and then Pkg.Subprograms (1).Name_Len
                     = Adacovex.Types.Max_Desc_Str,
            "Test 20: subprogram name clamped to Max_Desc_Str");
      end;

      --  Test 21: word-boundary matching (identifiers prefixed with
      --  `function`/`procedure` are not subprograms) and OOP modifiers
      --  (`overriding` / `not overriding`) are recognized.
      begin
         declare
            F : File_Type;
         begin
            Create (F, Out_File, Tmp_File);
            Put_Line (F, "package Oop_Boundary is");
            Put_Line (F, "   pragma Pure;");
            Put_Line (F, "   functionality : Integer := 0;");
            Put_Line (F, "   procedure_holder : Integer := 0;");
            Put_Line (F, "   --  @param X  Value to reset.");
            Put_Line (F, "   overriding procedure Reset (X : Integer);");
            Put_Line (F, "   --  @return The current value.");
            Put_Line (F, "   not overriding function Value return Integer;");
            Put_Line (F, "end Oop_Boundary;");
            Close (F);
         end;
      end;

      Adacovex.Parsers.Source.Scan_Ads_File (Tmp_File, Pkg, Success);
      R.Check (Success, "Test 21: parse succeeded");
      R.Check
        (Natural (Pkg.Subprograms.Length) = 2,
         "Test 21: 2 subprograms (boundary excludes identifiers)");
      R.Check
        (Natural (Pkg.Subprograms.Length) >= 1
         and then Pkg.Subprograms (1).Name_Len = 5
         and then Pkg.Subprograms (1).Name (1 .. 5) = "Reset"
         and then Pkg.Subprograms (1).Has_Docstring
         and then Pkg.Subprograms (1).Doc_Param_Ct = 1,
         "Test 21: overriding procedure parsed with name Reset");
      R.Check
        (Natural (Pkg.Subprograms.Length) >= 2
         and then Pkg.Subprograms (2).Name_Len = 5
         and then Pkg.Subprograms (2).Name (1 .. 5) = "Value"
         and then Pkg.Subprograms (2).Has_Docstring
         and then Pkg.Subprograms (2).Doc_Return,
         "Test 21: not overriding function parsed with name Value");

      --  Test 22: a cached scan from a different directory must not leak its
      --  File_Path.  Scan entries are keyed by file content hash, so scanning
      --  an identical file in a second directory (e.g. a --coverage-delta /
      --  --compare-base base snapshot) used to hit the entry cached from the
      --  first directory and carry its absolute path -- which broke
      --  Relative_Path consumers such as Apply_Patches and HLR traceability.
      begin
         declare
            Cache_A : constant String := "/tmp/adacovex_scan_cache_a";
            Cache_B : constant String := "/tmp/adacovex_scan_cache_b";
            File_A  : constant String := Cache_A & "/pkg.ads";
            File_B  : constant String := Cache_B & "/pkg.ads";
            F       : File_Type;
            Pkgs_A  : Package_Vectors.Vector;
            Pkgs_B  : Package_Vectors.Vector;
            Skip_A  : Natural := 0;
            Skip_B  : Natural := 0;
            Hits_A  : Natural := 0;
            Misses_A : Natural := 0;
            Hits_B  : Natural := 0;
            Misses_B : Natural := 0;
         begin
            Ada.Directories.Create_Path (Cache_A);
            Ada.Directories.Create_Path (Cache_B);
            Create (F, Out_File, File_A);
            Put_Line (F, "package Cache_Pkg is");
            Put_Line (F, "   --  @param X  Value.");
            Put_Line (F, "   procedure Touch (X : Integer);");
            Put_Line (F, "end Cache_Pkg;");
            Close (F);
            --  Byte-identical content in the second tree.
            Ada.Directories.Copy_File (File_A, File_B);

            --  First scan populates the content-hash cache.
            Adacovex.Parsers.Source.Scan_Project_Cached
              (Cache_A, "", Pkgs_A, Skip_A, Hits_A, Misses_A, True);
            --  Second scan must hit the same entries but use its own paths.
            Adacovex.Parsers.Source.Scan_Project_Cached
              (Cache_B, "", Pkgs_B, Skip_B, Hits_B, Misses_B, True);

            R.Check
              (Natural (Pkgs_A.Length) = 1
               and then Natural (Pkgs_B.Length) = 1,
               "Test 22: both cached scans parsed the package");
            if Natural (Pkgs_A.Length) = 1
              and then Natural (Pkgs_B.Length) = 1
            then
               R.Check
                 (Pkgs_B (1).Path_Len = File_B'Length
                  and then Pkgs_B (1).File_Path (1 .. File_B'Length) = File_B,
                  "Test 22: cached hit rewrites File_Path to the scanned tree");
               R.Check
                 (Pkgs_A (1).Path_Len = File_A'Length
                  and then Pkgs_A (1).File_Path (1 .. File_A'Length) = File_A,
                  "Test 22: first scan keeps its own File_Path");
            end if;

            Ada.Directories.Delete_Tree (Cache_A);
            Ada.Directories.Delete_Tree (Cache_B);
         exception
            when others =>
               null;
         end;
      end;

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
