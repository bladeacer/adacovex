with Ada.Directories;
with Ada.Strings.Fixed;
with GNAT.OS_Lib;
with Adacovex.Test_Support;
with Adacovex.Renderers.Man;

package body Adacovex_Man_Tests is

   procedure Run (R : in out Adacovex.Test_Support.Runner'Class) is
      use Ada.Strings.Fixed;
      Page : constant String := Adacovex.Renderers.Man.Render_Page ("1.10.0");
      Pid  : constant String :=
        Integer'Image
          (GNAT.OS_Lib.Pid_To_Integer (GNAT.OS_Lib.Current_Process_Id));
      Dir  : constant String :=
        "/tmp/adacovex-man-test-" & Pid (2 .. Pid'Last);
   begin
      --  The generated page carries the roff structure and the version.
      R.Check
        (Index (Page, ".TH ADACOVEX 1") > 0, "man page has a .TH header");
      R.Check
        (Index (Page, ".SH SYNOPSIS") > 0, "man page has a SYNOPSIS section");
      R.Check
        (Index (Page, ".SH OPTIONS") > 0, "man page has an OPTIONS section");
      R.Check
        (Index (Page, ".SH VERSION") > 0, "man page has a VERSION section");
      R.Check
        (Index (Page, ".SH EXIT STATUS") > 0,
         "man page has an EXIT STATUS section");
      R.Check
        (Index (Page, "adacovex v1.10.0") > 0, "man page embeds the version");
      R.Check
        (Index (Page, "--compare-base") > 0,
         "man page documents --compare-base");
      R.Check (Index (Page, "--version") > 0, "man page documents --version");
      R.Check (Index (Page, "mercurial") > 0, "man page mentions VCS support");

      --  SYNOPSIS rendering regression: the old .RI multi-argument macro
      --  concatenated tokens without spaces ([--format=FMT][--out=PATH]) and
      --  .br-interleaved lines made groff pad the paragraph with tab stops
      --  ("adacovex<gap>sbom").  Every SYNOPSIS line must now be a single
      --  quoted .B argument that preserves spaces, and no .RI may remain.
      R.Check
        (Index (Page, ".RI") = 0, "SYNOPSIS no longer uses .RI concatenation");
      R.Check
        (Index (Page, ".B ""adacovex [options]""") > 0,
         "SYNOPSIS adacovex line is a single quoted .B argument");
      R.Check
        (Index (Page, "--format=FMT] [--out=PATH]") > 0,
         "SYNOPSIS keeps spaces between bracket groups");

      --  Installed_Version on a directory with no page returns "".
      R.Check
        (Adacovex.Renderers.Man.Installed_Version (Dir) = "",
         "no installed version when the man page is missing");

      --  Install + read-back round-trip through the real file system.
      declare
         OK : Boolean;
      begin
         Adacovex.Renderers.Man.Install (Dir, "1.10.0", OK);
         R.Check (OK, "man page install succeeds");
         R.Check
           (Adacovex.Renderers.Man.Installed_Version (Dir) = "1.10.0",
            "installed version round-trips from the man page");
         R.Check
           (Ada.Directories.Exists (Dir & "/man1/adacovex.1"),
            "man page file exists at man1/adacovex.1");
      end;

      --  An empty (dev) version still renders a valid page.
      R.Check
        (Index (Adacovex.Renderers.Man.Render_Page (""), ".SH NAME") > 0,
         "empty version renders a valid page");

      --  Update_Database reports whether the man database was refreshed and
      --  must never report True when man-db (mandb) is absent from PATH --
      --  that is the contract `adacovex man` warns about.  The value when
      --  mandb IS present depends on the exit code, so only the missing-tool
      --  direction is asserted (deterministic in any environment).
      declare
         use GNAT.OS_Lib;
         Mandb     : String_Access := Locate_Exec_On_Path ("mandb");
         Has_Mandb : constant Boolean := Mandb /= null;
         Updated   : constant Boolean :=
           Adacovex.Renderers.Man.Update_Database ("/nonexistent/man-root");
      begin
         if Mandb /= null then
            Free (Mandb);
         end if;
         R.Check
           ((not Updated) or Has_Mandb,
            "Update_Database never reports True without mandb on PATH");
      end;

      --  Best-effort cleanup of the temp man root.
      begin
         Ada.Directories.Delete_File (Dir & "/man1/adacovex.1");
         Ada.Directories.Delete_Directory (Dir & "/man1");
         Ada.Directories.Delete_Directory (Dir);
      exception
         when others =>
            null;
      end;
   end Run;

end Adacovex_Man_Tests;
