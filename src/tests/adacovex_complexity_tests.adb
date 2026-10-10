with Adacovex.Complexity;
with Adacovex.CPUs;
with Ada.Containers;
with Ada.Directories;
with Ada.Text_IO;

package body Adacovex_Complexity_Tests is

   use Ada.Text_IO;
   use type Ada.Containers.Count_Type;

   Fixture_Dir : constant String :=
     Adacovex.CPUs.Get_Temp_Directory & "/adacovex_cx_test";

   --  Write a small fixture tree: one Ada source, one Markdown page, and
   --  one Python script. The Markdown page exists only to be excluded.
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

      --  --skip-path is a substring match on the full path, so a fragment
      --  that matches one fixture file drops only that file.
      declare
         Res : constant Adacovex.Complexity.Complexity_Result :=
           Adacovex.Complexity.Analyze_Project (Fixture_Dir, "", "sample");
      begin
         R.Check
           (Count_Lang (Res, "Ada") = 0,
            "skip-path=sample: the Ada fixture is skipped");
         R.Check
           (Count_Lang (Res, "Python") = 1,
            "skip-path=sample: the Python fixture is kept");
      end;

      --  A leading no-covex-complexity-scan marker opts one file out of the
      --  scan without an --excludes entry.
      declare
         F : File_Type;
      begin
         Create (F, Out_File, Fixture_Dir & "/marked.ads");
         Put_Line (F, "--  no-covex-complexity-scan");
         Put_Line (F, "package Marked is");
         Put_Line (F, "end Marked;");
         Close (F);
      end;
      declare
         Res : constant Adacovex.Complexity.Complexity_Result :=
           Adacovex.Complexity.Analyze_Project (Fixture_Dir);
      begin
         R.Check
           (Count_Lang (Res, "Ada") = 1,
            "a marked file is skipped, leaving only the unmarked Ada file");
      end;

      --  Check_Gates: a file exactly at a cap passes, one over fails. The
      --  boundary matters because a cap read as ">=" would fail a file at
      --  the limit and a cap read as ">" is the documented contract.
      declare
         Res   : Adacovex.Complexity.Complexity_Result;
         Files : Adacovex.Complexity.File_Metrics;
         Sub   : Adacovex.Complexity.Subprogram_Info;
      begin
         Files.LOC := 100;
         Files.Complexity := 20;
         Sub.Complexity := 20;
         Files.Subs.Append (Sub);
         Res.Files.Append (Files);
         Res.Total_LOC := 100;
         R.Check
           (Adacovex.Complexity.Check_Gates (Res, 100, 100, 20, 20).Length = 0,
            "a file exactly at every cap passes every gate");
         R.Check
           (Adacovex.Complexity.Check_Gates (Res, 99, 100, 20, 20).Length > 0,
            "a file one line over the LOC cap fails");
         R.Check
           (Adacovex.Complexity.Check_Gates (Res, 100, 100, 19, 20).Length > 0,
            "a function one point over the complexity cap fails");
         R.Check
           (Adacovex.Complexity.Check_Gates (Res, 100, 100, 20, 19).Length > 0,
            "a file one point over the file-complexity cap fails");
         R.Check
           (Adacovex.Complexity.Check_Gates (Res, 100, 99, 20, 20).Length > 0,
            "a file over its codebase-percentage cap fails");
      end;

      --  The fixture is cleaned up after the run.
      if Ada.Directories.Exists (Fixture_Dir) then
         Ada.Directories.Delete_Tree (Fixture_Dir);
      end if;
   end Run;

end Adacovex_Complexity_Tests;
