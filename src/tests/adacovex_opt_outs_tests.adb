with Adacovex.Opt_Outs;
with Adacovex.CPUs;
with Ada.Directories;
with Ada.Text_IO;

package body Adacovex_Opt_Outs_Tests is

   Fixture_Dir : constant String :=
     Adacovex.CPUs.Get_Temp_Directory & "/adacovex_optouts_test";

   --  Write a fixture file with exactly the given content.
   --  @param Name  File name inside the fixture directory.
   --  @param Text  Exact file content.
   procedure Write_File (Name : String; Text : String) is
      F : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (F, Ada.Text_IO.Out_File, Fixture_Dir & "/" & Name);
      Ada.Text_IO.Put (F, Text);
      Ada.Text_IO.Close (F);
   end Write_File;

   --  Write a file whose first 30 lines are comments and whose marker line
   --  is given.  The header window is 24 physical lines.
   --  @param Name  File name inside the fixture directory.
   --  @param Marker_Line  Line number that carries the marker.
   procedure Write_Numbered (Name : String; Marker_Line : Natural) is
      F : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (F, Ada.Text_IO.Out_File, Fixture_Dir & "/" & Name);
      for I in 1 .. 30 loop
         if I = Marker_Line then
            Ada.Text_IO.Put_Line (F, "--  no-covex-docstrings");
         else
            Ada.Text_IO.Put_Line (F, "--  filler comment line");
         end if;
      end loop;
      Ada.Text_IO.Put_Line (F, "package Numbered is");
      Ada.Text_IO.Put_Line (F, "end Numbered;");
      Ada.Text_IO.Close (F);
   end Write_Numbered;

   --  Whether the fixture file Name carries a marker for gate G.
   --  @param Name  File name inside the fixture directory.
   --  @param G  Analysis gate to test for.
   --  @return True when the file opts out of that gate.
   function Opt (Name : String; G : Adacovex.Opt_Outs.Gate) return Boolean is
   begin
      return Adacovex.Opt_Outs.File_Opts_Out (Fixture_Dir & "/" & Name, G);
   end Opt;

   procedure Run (R : in out Adacovex.Test_Support.Runner'Class) is
      use Adacovex.Opt_Outs;
      LF : constant String := String'(1 => ASCII.LF);
   begin
      if Ada.Directories.Exists (Fixture_Dir) then
         Ada.Directories.Delete_Tree (Fixture_Dir);
      end if;
      Ada.Directories.Create_Directory (Fixture_Dir);

      --  One marker line in an Ada header opts one gate out, not the others.
      Write_File
        ("single.ads",
         "--  no-covex-docstrings"
         & LF
         & LF
         & "package Single is"
         & LF
         & "end Single;"
         & LF);
      R.Check
        (Opt ("single.ads", Docstrings),
         "Ada header marker opts the file out of docstrings");
      R.Check
        (not Opt ("single.ads", Complexity_Scan),
         "docstrings marker does not opt out of complexity");
      R.Check
        (not Opt ("single.ads", SPARK_Proof),
         "docstrings marker does not opt out of proof");

      --  Two markers on separate header lines opt out of both gates.
      Write_File
        ("multi.adb",
         "--  no-covex-complexity-scan"
         & LF
         & "--  no-covex-spark-proof"
         & LF
         & LF
         & "package body Multi is"
         & LF
         & "end Multi;"
         & LF);
      R.Check
        (Opt ("multi.adb", Complexity_Scan), "complexity marker is detected");
      R.Check
        (Opt ("multi.adb", SPARK_Proof),
         "proof marker is detected on a later header line");
      R.Check
        (not Opt ("multi.adb", Docstrings),
         "complexity/proof markers do not opt out of docstrings");

      --  Matching is case-insensitive.
      Write_File
        ("case.ads",
         "--  No-Covex-SPARK-Proof"
         & LF
         & "package Case_Mix is"
         & LF
         & "end Case_Mix;"
         & LF);
      R.Check
        (Opt ("case.ads", SPARK_Proof), "marker matching is case-insensitive");

      --  The catch-all marker opts out of every gate.
      Write_File
        ("all.ads",
         "--  no-covex-analysis"
         & LF
         & "package All is"
         & LF
         & "end All;"
         & LF);
      R.Check
        (Opt ("all.ads", Complexity_Scan)
         and then Opt ("all.ads", Docstrings)
         and then Opt ("all.ads", SPARK_Proof),
         "no-covex-analysis opts out of all three gates");

      --  A Markdown HTML comment carrier works too.
      Write_File
        ("page.md", "<!-- no-covex-analysis -->" & LF & LF & "# Page" & LF);
      R.Check
        (Opt ("page.md", Complexity_Scan),
         "HTML comment marker opts a Markdown page out");

      --  A comment prefix of another language works: the marker text is
      --  language-independent.
      Write_File
        ("tool.py",
         "# no-covex-complexity-scan"
         & LF
         & LF
         & "def run():"
         & LF
         & "    return 0"
         & LF);
      R.Check
        (Opt ("tool.py", Complexity_Scan),
         "Python comment marker is detected");
      R.Check
        (not Opt ("tool.py", Docstrings),
         "Python complexity marker does not opt out of docstrings");

      --  Prose that only mentions the marker never opts the file out.
      Write_File
        ("prose.ads",
         "--  Every file may mention no-covex-docstrings in its header."
         & LF
         & "package Prose is"
         & LF
         & "end Prose;"
         & LF);
      R.Check
        (not Opt ("prose.ads", Docstrings),
         "a prose mention of the marker does not opt the file out");

      --  A marker after the header block (below the first line of code)
      --  is content, not a directive.
      Write_File
        ("below.ads",
         "package Below is"
         & LF
         & "--  no-covex-docstrings"
         & LF
         & "end Below;"
         & LF);
      R.Check
        (not Opt ("below.ads", Docstrings),
         "a marker below the header block is ignored");

      --  The header window is the first 24 physical lines.
      Write_Numbered ("cap24.ads", 24);
      R.Check
        (Opt ("cap24.ads", Docstrings),
         "a marker on line 24 is inside the header window");
      Write_Numbered ("cap25.ads", 25);
      R.Check
        (not Opt ("cap25.ads", Docstrings),
         "a marker on line 25 is outside the header window");

      --  Unreadable files report False for every gate, never raise.
      R.Check
        (not Opt ("missing.ads", Docstrings)
         and then not Opt ("missing.ads", Complexity_Scan)
         and then not Opt ("missing.ads", SPARK_Proof),
         "a missing file reports no opt-out for every gate");

      Ada.Directories.Delete_Tree (Fixture_Dir);
   end Run;

end Adacovex_Opt_Outs_Tests;
