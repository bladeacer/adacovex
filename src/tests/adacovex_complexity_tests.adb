with Adacovex.Complexity;
with Adacovex.CPUs;
with Ada.Directories;
with Ada.Text_IO;

package body Adacovex_Complexity_Tests is

   use Ada.Text_IO;

   Fixture_Dir : constant String :=
     Adacovex.CPUs.Get_Temp_Directory & "/adacovex_cx_test";

   --  Write a small fixture tree: one Ada source, one Markdown page, and
   --  one Python script.  The Markdown page exists only to be excluded.
   procedure Make_Fixture is
      F : File_Type;
   begin
      if Ada.Directories.Exists (Fixture_Dir) then
         Ada.Directories.Delete_Tree (Fixture_Dir);
      end if;
      Ada.Directories.Create_Directory (Fixture_Dir);

      Create (F, Out_File, Fixture_Dir & "/sample.ads");
      Put_Line (F, "package Sample is");
      Put_Line (F, "   --  @param X  First operand.");
      Put_Line (F, "   --  @return The sum.");
      Put_Line (F, "   function Add (X : Integer) return Integer;");
      Put_Line (F, "end Sample;");
      Close (F);

      Create (F, Out_File, Fixture_Dir & "/notes.md");
      Put_Line (F, "# Notes");
      Put_Line (F, "A short note for the fixture.");
      Close (F);

      Create (F, Out_File, Fixture_Dir & "/tool.py");
      Put_Line (F, "def run():");
      Put_Line (F, "    if True:");
      Put_Line (F, "        return 1");
      Put_Line (F, "    return 0");
      Close (F);
   end Make_Fixture;

   --  Count the files in Result whose language is Lang.
   --  @param Result  Complexity result to scan.
   --  @param Lang  Display language name to count.
   --  @return Number of files with that language.
   function Count_Lang
     (Result : Adacovex.Complexity.Complexity_Result; Lang : String)
      return Natural
   is
      N : Natural := 0;
   begin
      for FM of Result.Files loop
         if FM.Language_Len = Lang'Length
           and then FM.Language (1 .. FM.Language_Len) = Lang
         then
            N := N + 1;
         end if;
      end loop;
      return N;
   end Count_Lang;

   procedure Run (R : in out Adacovex.Test_Support.Runner'Class) is
   begin
      Make_Fixture;

      --  Without excludes, every supported language is scanned.
      declare
         Res : constant Adacovex.Complexity.Complexity_Result :=
           Adacovex.Complexity.Analyze_Project (Fixture_Dir);
      begin
         R.Check
           (Natural (Res.Files.Length) = 3,
            "no excludes: all three fixture files are scanned");
         R.Check (Count_Lang (Res, "Ada") = 1, "no excludes: Ada found");
         R.Check
           (Count_Lang (Res, "Markdown") = 1, "no excludes: Markdown found");
         R.Check (Count_Lang (Res, "Python") = 1, "no excludes: Python found");
      end;

      --  --excludes=md drops the Markdown file only.
      declare
         Res : constant Adacovex.Complexity.Complexity_Result :=
           Adacovex.Complexity.Analyze_Project (Fixture_Dir, "md");
      begin
         R.Check
           (Natural (Res.Files.Length) = 2,
            "excludes=md: Markdown file is skipped");
         R.Check
           (Count_Lang (Res, "Markdown") = 0,
            "excludes=md: no Markdown remains");
         R.Check (Count_Lang (Res, "Ada") = 1, "excludes=md: Ada kept");
         R.Check (Count_Lang (Res, "Python") = 1, "excludes=md: Python kept");
      end;

      --  A comma-separated list excludes several extensions at once.
      declare
         Res : constant Adacovex.Complexity.Complexity_Result :=
           Adacovex.Complexity.Analyze_Project (Fixture_Dir, "md,rst");
      begin
         R.Check
           (Count_Lang (Res, "Markdown") = 0,
            "excludes=md,rst: Markdown is skipped");
         R.Check
           (Count_Lang (Res, "reStructuredText") = 0,
            "excludes=md,rst: reStructuredText is skipped (harmless)");
      end;

      --  The extension match is case-insensitive.
      declare
         Res : constant Adacovex.Complexity.Complexity_Result :=
           Adacovex.Complexity.Analyze_Project (Fixture_Dir, "MD");
      begin
         R.Check
           (Count_Lang (Res, "Markdown") = 0,
            "excludes=MD: case-insensitive match skips Markdown");
      end;

      --  File-level LOC is computed for non-Ada sources too.
      declare
         Res : constant Adacovex.Complexity.Complexity_Result :=
           Adacovex.Complexity.Analyze_Project (Fixture_Dir);
      begin
         for FM of Res.Files loop
            if FM.Language_Len = 6 and then FM.Language (1 .. 6) = "Python"
            then
               R.Check
                 (FM.LOC = 4, "Python file LOC is counted (4 code lines)");
            end if;
         end loop;
      end;

      --  The fixture is cleaned up after the run.
      if Ada.Directories.Exists (Fixture_Dir) then
         Ada.Directories.Delete_Tree (Fixture_Dir);
      end if;
   end Run;

end Adacovex_Complexity_Tests;
