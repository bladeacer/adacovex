with Adacovex.Renderers.ANSI;
with Adacovex.Types;
with Adacovex.CPUs;
with Ada.Directories;
with Ada.Text_IO;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package body Adacovex_ANSI_Tests is

   Capture_Path : constant String :=
     Adacovex.CPUs.Get_Temp_Directory & "/adacovex_ansi_capture.txt";

   --  Whether Needle appears in Haystack.
   --  @param Haystack  Captured report text.
   --  @param Needle  Substring to look for.
   --  @return True when the substring is present.
   function Has_Text
     (Haystack : Unbounded_String; Needle : String) return Boolean
   is
      S : constant String := To_String (Haystack);
   begin
      if Needle'Length = 0 or else Needle'Length > S'Length then
         return False;
      end if;
      for I in S'First .. S'Last - Needle'Length + 1 loop
         if S (I .. I + Needle'Length - 1) = Needle then
            return True;
         end if;
      end loop;
      return False;
   end Has_Text;

   --  A docstring-coverage metric set with the given percentage.
   --  @param Pct  Coverage percentage to report.
   --  @return The metric set.
   function Doc (Pct : Natural) return Adacovex.Types.Docstring_Metrics is
      D : Adacovex.Types.Docstring_Metrics;
   begin
      D.Total_Subprograms := 10;
      D.Documented_Subprogs := 10 * Pct / 100;
      D.Coverage_Pct := Pct;
      return D;
   end Doc;

   --  A package vector holding one documented and one undocumented
   --  subprogram, plus one HLR tag when With_HLR is True.
   --  @param With_HLR  Whether the package carries an HLR tag.
   --  @return The package vector.
   function Pkgs
     (With_HLR : Boolean := True)
      return Adacovex.Types.Implementation.Package_Vectors.Vector
   is
      use Adacovex.Types;
      V : Adacovex.Types.Implementation.Package_Vectors.Vector;
      P : Adacovex.Types.Implementation.Package_Info;
      S : Adacovex.Types.Subprogram_Info;
      T : Adacovex.Types.HLR_Tag_Entry;
   begin
      P.Name_Len := 6;
      P.Name (1 .. 6) := "Sample";
      P.Path_Len := 12;
      P.File_Path (1 .. 12) := "sample.ads  ";

      S.Name_Len := 7;
      S.Name (1 .. 7) := "Add_Two";
      S.Line_Number := 42;
      S.Has_Docstring := False;
      P.Subprograms.Append (S);

      S.Name_Len := 7;
      S.Name (1 .. 7) := "Get_One";
      S.Line_Number := 51;
      S.Has_Docstring := True;
      P.Subprograms.Append (S);

      if With_HLR then
         T.Len := 11;
         T.Tag (1 .. 11) := "HLR-SAMPLE1";
         P.HLR_Tags.Append (T);
      end if;

      V.Append (P);
      return V;
   end Pkgs;

   --  Render a summary with standard output redirected into the capture
   --  file, and return the captured text.
   --  @param Doc  Docstring coverage metrics.
   --  @param Proof  Proof summary.
   --  @param Tests  Test summary.
   --  @param DAL  DAL assessment.
   --  @param Packages  Scanned packages.
   --  @param Color  Whether colour is requested.
   --  @param All_Std  Whether every standard is printed.
   --  @param Hits  Cache hit count.
   --  @param Misses  Cache miss count.
   --  @param Evict  Cache eviction count.
   --  @return The captured report text.
   function Render_Text
     (Doc      : Adacovex.Types.Docstring_Metrics;
      Proof    : Adacovex.Types.Proof_Summary;
      Tests    : Adacovex.Types.Implementation.Test_Summary;
      DAL      : Adacovex.Types.Implementation.DAL_Assessment;
      Packages : Adacovex.Types.Implementation.Package_Vectors.Vector;
      Color    : Boolean := False;
      All_Std  : Boolean := False;
      Hits     : Natural := 0;
      Misses   : Natural := 0;
      Evict    : Natural := 0) return Unbounded_String
   is
      F    : Ada.Text_IO.File_Type;
      G    : Ada.Text_IO.File_Type;
      Line : String (1 .. 1024);
      Last : Natural;
      Res  : Unbounded_String;
   begin
      Ada.Text_IO.Create (F, Ada.Text_IO.Out_File, Capture_Path);
      Ada.Text_IO.Set_Output (F);
      Adacovex.Renderers.ANSI.Render_Summary
        (Doc_Metrics     => Doc,
         Proof           => Proof,
         Tests           => Tests,
         DAL_Assess      => DAL,
         Packages        => Packages,
         Use_Color       => Color,
         All_Standards   => All_Std,
         Cache_Hits      => Hits,
         Cache_Misses    => Misses,
         Cache_Evictions => Evict);
      Ada.Text_IO.Flush (F);
      Ada.Text_IO.Set_Output (Ada.Text_IO.Standard_Output);
      Ada.Text_IO.Close (F);

      Ada.Text_IO.Open (G, Ada.Text_IO.In_File, Capture_Path);
      while not Ada.Text_IO.End_Of_File (G) loop
         Ada.Text_IO.Get_Line (G, Line, Last);
         Append (Res, Line (1 .. Last));
         Append (Res, ASCII.LF);
      end loop;
      Ada.Text_IO.Close (G);
      Ada.Directories.Delete_File (Capture_Path);
      return Res;
   end Render_Text;

   procedure Run (R : in out Adacovex.Test_Support.Runner'Class) is
      use Adacovex.Types;
   begin
      --  Default report: plain text, no escape sequences.
      declare
         Proof : Adacovex.Types.Proof_Summary;
         Tests : Adacovex.Types.Implementation.Test_Summary;
         DAL   : Adacovex.Types.Implementation.DAL_Assessment;
         Text  : Unbounded_String;
      begin
         Proof.Total_VCs := 880;
         Proof.Proved_VCs := 880;
         Proof.Level := Adacovex.Types.Platinum;
         Tests.Total_Passed := 1404;
         DAL.Status := Adacovex.Types.Achieved;

         Text := Render_Text (Doc (100), Proof, Tests, DAL, Pkgs);

         R.Check
           (not Has_Text (Text, String'(1 => ASCII.ESC)),
            "plain output carries no escape sequence");
         R.Check
           (Has_Text (Text, "docstrings:"),
            "the report names the docstring coverage line");
         R.Check
           (Has_Text (Text, "100%"),
            "the report carries the coverage percentage");
         R.Check
           (Has_Text (Text, "GNATprove: Platinum"),
            "the report carries the proof level");
         R.Check
           (Has_Text (Text, "880 VCs"), "the report carries the VC count");
         R.Check
           (Has_Text (Text, "tests:  1404 passed, 0 failed"),
            "the report carries the test totals");
         R.Check
           (Has_Text (Text, "Achieved"),
            "the report carries the compliance verdict");
         R.Check
           (Has_Text (Text, "result cache:  0 hit(s), 0 miss(es)"),
            "the report carries the cache counters");
         R.Check
           (Has_Text (Text, "undocumented subprograms:"),
            "an undocumented subprogram is called out");
         R.Check
           (Has_Text (Text, "sample.ads  : 42: subprogram ""Add_Two"""),
            "the undocumented entry carries the file and line");
         R.Check
           (Has_Text (Text, "help: add --  @param"),
            "the undocumented entry carries the fix hint");
         R.Check
           (Has_Text (Text, "HLR traceability:"),
            "the report lists the HLR traceability block");
         R.Check
           (Has_Text (Text, "HLR-SAMPLE1"),
            "the report lists the traced HLR tag");
      end;

      --  Coloured output wraps each status in an escape sequence.
      declare
         Proof : Adacovex.Types.Proof_Summary;
         Tests : Adacovex.Types.Implementation.Test_Summary;
         DAL   : Adacovex.Types.Implementation.DAL_Assessment;
         Text  : Unbounded_String;
      begin
         Proof.Level := Adacovex.Types.Platinum;
         DAL.Status := Adacovex.Types.Achieved;
         Text :=
           Render_Text (Doc (100), Proof, Tests, DAL, Pkgs, Color => True);
         R.Check
           (Has_Text (Text, String'(1 => ASCII.ESC)),
            "coloured output carries escape sequences");
      end;

      --  A low-coverage run still reports every section it owns.
      declare
         Proof : Adacovex.Types.Proof_Summary;
         Tests : Adacovex.Types.Implementation.Test_Summary;
         DAL   : Adacovex.Types.Implementation.DAL_Assessment;
         Text  : Unbounded_String;
      begin
         Proof.Total_VCs := 10;
         Proof.Unproved := 3;
         Proof.Justified := 2;
         Proof.Units_Analyzed := 7;
         Proof.Units_Skipped := 2;
         Tests.Total_Passed := 5;
         Tests.Total_Failed := 1;
         DAL.Target_DAL := Adacovex.Types.DAL_B;
         DAL.Status := Adacovex.Types.Unmet;
         declare
            Reason : Adacovex.Types.Desc_Field := (others => ' ');
         begin
            Reason (1 .. 21) := "test evidence missing";
            DAL.Failed_Reasons.Append (Reason);
         end;

         Text := Render_Text (Doc (40), Proof, Tests, DAL, Pkgs);

         R.Check
           (Has_Text (Text, "40%"), "a low coverage percentage is reported");
         R.Check
           (Has_Text (Text, ",  3 unproved"), "unproved VCs are counted");
         R.Check
           (Has_Text (Text, ",  2 justified"), "justified VCs are counted");
         R.Check
           (Has_Text (Text, "GNATprove units:  7 analyzed,  2 skipped"),
            "the analysed/skipped unit counts are reported");
         R.Check (Has_Text (Text, "1 failed"), "test failures are reported");
         R.Check
           (Has_Text (Text, "unproved VCs:  3 total"),
            "the unproved summary block is printed");
         R.Check
           (Has_Text (Text, "justified VCs:  2 total"),
            "the justified summary block is printed");
         R.Check
           (Has_Text (Text, "failures:"),
            "the compliance failure block is printed");
         R.Check
           (Has_Text (Text, "- test evidence missing"),
            "each compliance failure reason is listed");
         R.Check (Has_Text (Text, "Unmet"), "the unmet verdict is reported");
      end;

      --  --standard=all prints one compliance line per standard.
      declare
         Proof : Adacovex.Types.Proof_Summary;
         Tests : Adacovex.Types.Implementation.Test_Summary;
         DAL   : Adacovex.Types.Implementation.DAL_Assessment;
         Text  : Unbounded_String;
      begin
         DAL.Status := Adacovex.Types.Achieved;
         Text :=
           Render_Text (Doc (100), Proof, Tests, DAL, Pkgs, All_Std => True);
         R.Check
           (Has_Text (Text, "compliance (all standards):"),
            "all-standards mode prints the combined block");
         R.Check
           (Has_Text
              (Text,
               Adacovex.Types.Standard_Level_Name
                 (DO_178C, Adacovex.Types.DAL_C)),
            "all-standards mode prints the DO-178C level");
         R.Check
           (Has_Text
              (Text,
               Adacovex.Types.Standard_Level_Name
                 (ISO_26262, Adacovex.Types.DAL_C)),
            "all-standards mode prints the ISO 26262 level");
         R.Check
           (Has_Text
              (Text,
               Adacovex.Types.Standard_Level_Name
                 (IEC_62304, Adacovex.Types.DAL_C)),
            "all-standards mode prints the IEC 62304 level");
      end;
   end Run;

end Adacovex_ANSI_Tests;
