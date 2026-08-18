with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with Adacovex.Types;
use Adacovex.Types, Adacovex.Types.Implementation;
with Adacovex.Renderers.HTML;
with Adacovex.Renderers.Markdown;

package body Adacovex_Renderer_Tests is

   function Contains (S : String; Sub : String) return Boolean is
   begin
      return Ada.Strings.Fixed.Index (S, Sub) > 0;
   end Contains;

   function Read_All (Path : String) return String is
      F    : Ada.Text_IO.File_Type;
      Buf  : String (1 .. 200_000);
      Last : Natural := 0;
   begin
      Ada.Text_IO.Open (F, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (F) loop
         declare
            Line : String (1 .. 8_192);
            L    : Natural;
         begin
            Ada.Text_IO.Get_Line (F, Line, L);
            Buf (Last + 1 .. Last + L) := Line (1 .. L);
            Last := Last + L;
            Last := Last + 1;
            Buf (Last) := ASCII.LF;
         end;
      end loop;
      Ada.Text_IO.Close (F);
      return Buf (1 .. Last);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (F) then
            Ada.Text_IO.Close (F);
         end if;
         return "";
   end Read_All;

   procedure Run (R : in out Adacovex.Test_Support.Runner'Class) is
      Doc    : Docstring_Metrics;
      Proof  : Proof_Summary;
      Tests  : Test_Summary;
      Pkgs   : Package_Vectors.Vector;
      Assess : DAL_Assessment;
   begin
      Assess.Status := Achieved;
      Assess.Target_DAL := DAL_C;

      --  HTML dashboard is standard-aware: ISO 26262 prints "ASIL B".
      Assess.Standard := ISO_26262;
      declare
         S : constant String :=
           Adacovex.Renderers.HTML.Render_Dashboard
             (Doc, Proof, Tests, Assess, Pkgs);
      begin
         R.Check
           (Contains (S, "ISO 26262 Compliance"), "dashboard ISO heading");
         R.Check (Contains (S, "ASIL B"), "dashboard ASIL B level");
         R.Check
           (Contains (S, "/badge/iso26262.svg"), "dashboard iso26262 badge");
      end;

      --  HTML dashboard all-standards mode lists every standard.
      declare
         S : constant String :=
           Adacovex.Renderers.HTML.Render_Dashboard
             (Doc, Proof, Tests, Assess, Pkgs, All_Standards => True);
      begin
         R.Check
           (Contains (S, "Compliance (all standards)"),
            "dashboard all-standards heading");
         R.Check (Contains (S, "ASIL B"), "dashboard all: ASIL B");
         R.Check (Contains (S, "DAL-C"), "dashboard all: DAL-C");
         R.Check (Contains (S, "Class A"), "dashboard all: Class A");
      end;

      --  JSON API carries the standard + level label.
      Assess.Standard := IEC_62304;
      declare
         S : constant String :=
           Adacovex.Renderers.HTML.Render_Metrics_JSON
             (Doc, Proof, Tests, Assess);
      begin
         R.Check
           (Contains (S, """standard"":""IEC 62304"""),
            "json standard IEC 62304");
         R.Check (Contains (S, """level"":""Class A"""), "json level Class A");
      end;

      --  JSON API all-standards mode emits a per-standard breakdown.
      declare
         S : constant String :=
           Adacovex.Renderers.HTML.Render_Metrics_JSON
             (Doc, Proof, Tests, Assess, All_Standards => True);
      begin
         R.Check (Contains (S, """standard"":""all"""), "json standard all");
         R.Check (Contains (S, """standards"":"), "json standards object");
         R.Check (Contains (S, "ASIL B"), "json all: ASIL B");
      end;

      --  Dashboard supports light/dark/system themes: CSS custom properties
      --  with a prefers-color-scheme dark default, a header dropdown with
      --  the three options (the selected one honored as the initial theme),
      --  and a data-theme override persisted in localStorage.
      declare
         S : constant String :=
           Adacovex.Renderers.HTML.Render_Dashboard
             (Doc, Proof, Tests, Assess, Pkgs, All_Standards => True);
      begin
         R.Check
           (Contains (S, "prefers-color-scheme"),
            "dashboard respects prefers-color-scheme");
         R.Check
           (Contains (S, "theme-select"), "dashboard has theme dropdown");
         R.Check
           (Contains (S, "<option value=""system"""),
            "dashboard dropdown offers system theme");
         R.Check
           (Contains (S, "<option value=""light"""),
            "dashboard dropdown offers light theme");
         R.Check
           (Contains (S, "<option value=""dark"""),
            "dashboard dropdown offers dark theme");
         R.Check
           (Contains (S, "data-theme"), "dashboard uses data-theme override");
         R.Check
           (Contains (S, "localStorage"), "dashboard persists theme choice");
         R.Check
           (Contains (S, "save-theme"), "dashboard has save settings button");
         R.Check
           (Contains (S, "Save settings"), "save settings button labeled");
         R.Check
           (Contains (S, "saveTheme"), "saveTheme persists on click");
         R.Check
           (Contains (S, "URLSearchParams"),
            "dashboard reads the ?theme= query param");
      end;

      --  The --theme flag's initial selection is honored: Dark_Theme renders
      --  a dark option marked selected.
      declare
         S : constant String :=
           Adacovex.Renderers.HTML.Render_Dashboard
             (Doc,
              Proof,
              Tests,
              Assess,
              Pkgs,
              All_Standards => True,
              Theme         => Dark_Theme);
      begin
         R.Check
           (Contains (S, "<option value=""dark"" selected"),
            "dashboard honors Dark_Theme initial selection");
         R.Check
           (Contains (S, "var C='dark';"),
            "dashboard emits CLI theme marker for priority");
      end;

      --  Light_Theme marks the light option selected.
      declare
         S : constant String :=
           Adacovex.Renderers.HTML.Render_Dashboard
             (Doc,
              Proof,
              Tests,
              Assess,
              Pkgs,
              All_Standards => True,
              Theme         => Light_Theme);
      begin
         R.Check
           (Contains (S, "<option value=""light"" selected"),
            "dashboard honors Light_Theme initial selection");
      end;

      --  Markdown verification report is standard-aware.
      declare
         Dir : constant String := "/tmp/adacovex_md_test";
         Md  : constant String := Dir & "/VERIFICATION.md";
      begin
         begin
            if Ada.Directories.Exists (Dir) then
               Ada.Directories.Delete_Tree (Dir);
            end if;
            Ada.Directories.Create_Path (Dir);
         end;
         Assess.Standard := ISO_26262;
         Adacovex.Renderers.Markdown.Generate_Verification_Report
           (Md, Doc, Proof, Tests, Assess, Pkgs);
         declare
            T : constant String := Read_All (Md);
         begin
            R.Check
              (Contains (T, "## ISO 26262 Compliance"), "md ISO heading");
            R.Check (Contains (T, "ASIL B"), "md ASIL B level");
         end;
         Adacovex.Renderers.Markdown.Generate_Verification_Report
           (Md, Doc, Proof, Tests, Assess, Pkgs, All_Standards => True);
         declare
            T : constant String := Read_All (Md);
         begin
            R.Check
              (Contains (T, "## Compliance (all standards)"),
               "md all-standards heading");
            R.Check (Contains (T, "ASIL B"), "md all: ASIL B");
            R.Check (Contains (T, "Class A"), "md all: Class A");
         end;
         begin
            if Ada.Directories.Exists (Dir) then
               Ada.Directories.Delete_Tree (Dir);
            end if;
         exception
            when others =>
               null;
         end;
      end;
   end Run;

end Adacovex_Renderer_Tests;
