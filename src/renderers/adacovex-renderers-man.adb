with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with Adacovex.Config;
with Adacovex.CPUs;
with GNAT.OS_Lib;

package body Adacovex.Renderers.Man is

   use Ada.Strings.Fixed;

   Max_Page : constant := 16_384;

   --  Strip a trailing '/' off a directory path so concatenations stay clean.
   function Strip_Trailing_Slash (S : String) return String is
   begin
      if S'Length > 1 and then S (S'Last) = '/' then
         return S (S'First .. S'Last - 1);
      else
         return S;
      end if;
   end Strip_Trailing_Slash;

   --  Append a line (plus newline) to the page buffer.  The generated page
   --  is fixed, curated content well under Max_Page, so App truncates
   --  silently only as a last-resort overflow guard.
   procedure App (Buf : in out String; Len : in out Natural; Line : String) is
   begin
      for I in Line'Range loop
         exit when Len >= Buf'Last;
         Len := Len + 1;
         Buf (Len) := Line (I);
      end loop;
      if Len < Buf'Last then
         Len := Len + 1;
         Buf (Len) := ASCII.LF;
      end if;
   end App;

   --  Render one .TP option entry: the option name line followed by the
   --  description.  The description must NOT be indented with a literal tab:
   --  groff's .TP macro computes the hanging indent itself, and a leading tab
   --  pushes the first line to a tab stop while wrapped lines go back to the
   --  .TP indent -- the "random extra spaces" bug.  A plain following line
   --  renders first and wrapped lines at the same indent.
   procedure App_Option
     (Buf : in out String; Len : in out Natural; Name : String; Desc : String)
   is
   begin
      App (Buf, Len, ".TP");
      App (Buf, Len, ".B " & Name);
      App (Buf, Len, Desc);
   end App_Option;

   function Render_Page (Version : String) return String is
      Buf : String (1 .. Max_Page) := (others => ' ');
      Len : Natural := 0;
      V   : constant String := (if Version'Length > 0 then Version else "dev");
      Q   : constant Character := '"';
   begin
      App
        (Buf,
         Len,
         ".TH ADACOVEX 1 "
         & Q
         & "August 2026"
         & Q
         & " "
         & Q
         & "adacovex v"
         & V
         & Q
         & " "
         & Q
         & "User Commands"
         & Q);
      App (Buf, Len, ".SH NAME");
      App
        (Buf,
         Len,
         "adacovex \- Ada/SPARK coverage, proof, and multi-standard "
         & "compliance tool");
      App (Buf, Len, ".SH SYNOPSIS");
      App (Buf, Len, ".B " & Q & "adacovex [options]" & Q);
      App (Buf, Len, ".br");
      App
        (Buf,
         Len,
         ".B "
         & Q
         & "adacovex sbom [--format=FMT] [--out=PATH] [--standard=NAME "
         & "| --dal=LEVEL | --asil=LEVEL | --class=LEVEL]"
         & Q);
      App (Buf, Len, ".br");
      App
        (Buf,
         Len,
         ".B " & Q & "adacovex prove [--target=PATH] [prove options]" & Q);
      App (Buf, Len, ".br");
      App (Buf, Len, ".B " & Q & "adacovex status [--target=PATH]" & Q);
      App (Buf, Len, ".br");
      App
        (Buf,
         Len,
         ".B " & Q & "adacovex man [--check] [--dir=PATH] [--force]" & Q);
      App (Buf, Len, ".SH DESCRIPTION");
      App
        (Buf,
         Len,
         "adacovex is a zero-dependency Ada/SPARK command-line tool for "
         & "coverage");
      App
        (Buf,
         Len,
         "analysis, proof verification, test-result parsing, and "
         & "safety-compliance");
      App
        (Buf,
         Len,
         "assessment against DO-178C (DAL A-E), ISO 26262 (ASIL A-D/QM), "
         & "and IEC");
      App
        (Buf,
         Len,
         "62304 (safety classes A-C).  It scans Ada sources for "
         & "subprograms and");
      App
        (Buf,
         Len,
         "docstrings, parses GNATprove output and test summaries, assesses "
         & "the");
      App
        (Buf,
         Len,
         "target against the selected standard, and renders ANSI, SVG, "
         & "Markdown,");
      App
        (Buf,
         Len,
         "SBOM, and HTML dashboard outputs.  Differential modes compare "
         & "the current");
      App
        (Buf,
         Len,
         "tree against a base revision in git, mercurial, subversion, "
         & "fossil, or jj");
      App (Buf, Len, "repositories.");
      App (Buf, Len, ".SH OPTIONS");
      --  Single source of truth: derive the option list from
      --  Config.Flag_List (the same Known_Flags that drives
      --  --help and shell completion), so the man page never drifts
      --  from the binary.  Descriptions are mapped centrally here;
      --  adding a flag to Known_Flags automatically adds a .TP entry
      --  (with a fallback generic line) even before a bespoke
      --  description is added.
      declare
         Flags : constant String := Adacovex.Config.Flag_List;
         Start : Positive := Flags'First;
         Fin   : Natural;

         function Desc_For (Flag : String) return String is
         begin
            if Flag = "target" then
               return
                 "Target project root directory (default: current directory).";
            elsif Flag = "manifest" then
               return "Override the target project manifest file.";
            elsif Flag = "dal" then
               return
                 "DO-178C DAL level A|B|C|D|E (default: C; also the shared rigor tier).";
            elsif Flag = "asil" then
               return
                 "ISO 26262 level A|B|C|D|QM (sets the standard and tier).";
            elsif Flag = "class" then
               return
                 "IEC 62304 safety class A|B|C (sets the standard and tier).";
            elsif Flag = "standard" then
               return "do178c | iso26262 | iec62304 | all (default: do178c).";
            elsif Flag = "serve" then
               return
                 "Switch: run the pipeline, then spawn the HTTP dashboard "
                 & "server on the port (default 8080) and block.  Omit it to "
                 & "render and exit without a server.  Standard-aware: "
                 & "defaults to all standards.  Also see "
                 & "--port/--theme/--serve-workers.";
            elsif Flag = "serve-workers" then
               return
                 "HTTP server task-pool worker count for --serve "
                 & "(default 4, valid Positive, capped at 256).  Related "
                 & "flag of --serve.";
            elsif Flag = "theme" then
               return
                 "Dashboard theme: light | dark | system (default: system; only with --serve).";
            elsif Flag = "port" then
               return "HTTP server port for --serve (default: 8080).";
            elsif Flag = "emit-svg" then
               return
                 "Write SVG badges to a directory (default <target>/docs/badges).";
            elsif Flag = "no-svg" then
               return "Suppress SVG badge output (overrides --emit-svg).";
            elsif Flag = "emit-markdown" then
               return "Write VERIFICATION.md and TRACE.md into a directory.";
            elsif Flag = "emit-metrics" then
               return
                 "Write a JSON metrics + dependency graph export to a file.";
            elsif Flag = "skip-dir" then
               return
                 "Add a directory to the relaxed-mode skip list (repeatable).";
            elsif Flag = "relaxed" then
               return "Disable strict mode (skip dirs, no patches).";
            elsif Flag = "cache" then
               return "Enable the on-disk result cache (default: on).";
            elsif Flag = "no-cache" then
               return "Disable the on-disk result cache (always re-scan).";
            elsif Flag = "cache-dir" then
               return "Relocate the result cache directory.";
            elsif Flag = "cache-max" then
               return "Cap the result cache entry count (default: 4096).";
            elsif Flag = "compare-base" then
               return
                 "Differential mode: compare against a base "
                 & "revision (git/hg/svn/fossil/jj) and report the "
                 & "VC/DAL delta.";
            elsif Flag = "coverage-delta" then
               return
                 "Docstring-coverage gate: exit non-zero if current coverage is below the base revision.";
            elsif Flag = "verbose" then
               return "Verbose diagnostics on stderr.";
            elsif Flag = "no-sbom" then
               return
                 "Skip the automatic SBOM generated at the end of every assessment.";
            elsif Flag = "sbom-format" or Flag = "format" then
               return
                 "SBOM format for the automatic SBOM: cyclonedx-json | spdx-json | md (default: cyclonedx-json).";
            elsif Flag = "out" then
               return
                 "SBOM output path for the sbom subcommand (default: <target>/sbom.json).";
            elsif Flag = "jobs" then
               return "GNATprove parallelism -j N (default: auto).";
            elsif Flag = "level" then
               return "GNATprove proof effort 0-4.";
            elsif Flag = "timeout" then
               return "Per-check prover timeout in seconds.";
            elsif Flag = "steps" then
               return "Max proof steps (default: 10000).";
            elsif Flag = "memlimit" then
               return "Prover memory limit in MB.";
            elsif Flag = "force" then
               return
                 "Force full gnatprove reanalysis and man page reinstall.";
            elsif Flag = "no-loop-unrolling" then
               return
                 "Disable automatic loop unrolling (always on for prove; kept for compat).";
            elsif Flag = "no-inlining" then
               return "Disable contextual analysis inlining.";
            elsif Flag = "suppress-warnings" then
               return
                 "Suppress GNATprove benign info messages (--suppress-warnings[=SETS]).";
            elsif Flag = "quiet" then
               return "Alias for --suppress-warnings (the default set).";
            elsif Flag = "require-spark" then
               return
                 "CI gate: fail loudly if SPARK level < LVL (Stone..Platinum).";
            elsif Flag = "require-docstrings" then
               return
                 "CI gate: fail loudly if docstring coverage < PCT% (0-100).";
            elsif Flag = "require-tests" then
               return "CI gate: fail loudly if passing test count < N.";
            elsif Flag = "require-proof" then
               return
                 "CI gate: fail loudly if proved-VC coverage < PCT% (0-100).";
            elsif Flag = "help" then
               return "Show help and exit (also 'adacovex help <topic>').";
            elsif Flag = "version" then
               return "Print the bundled version and exit.";
            elsif Flag = "sbom" then
               return
                 "Subcommand: generate a proof-aware SBOM (see also --sbom-format/--format/--out).";
            elsif Flag = "prove" then
               return
                 "Subcommand: run GNATprove then assess (see --jobs/--level/...).";
            elsif Flag = "status" then
               return "Subcommand: report toolchain + platform status.";
            elsif Flag = "export" then
               return
                 "With status: write the report as JSON to PATH "
                 & "(or stdout when no path is given).";
            elsif Flag = "metrics" then
               return
                 "With status: print compact key=value metrics "
                 & "lines for shell scripts.";
            elsif Flag = "completion" then
               return
                 "Subcommand: print shell completion script (bash/fish/zsh/pwsh).";
            elsif Flag = "man" then
               return
                 "Subcommand: install the man page into the local man database.";
            elsif Flag = "check" then
               return
                 "Man subcommand flag: --check exits 0 when installed page matches binary.";
            elsif Flag = "dir" then
               return
                 "Man subcommand flag: --dir=PATH installs under PATH/man1.";
            else
               return "See --help for details.";
            end if;
         end Desc_For;

      begin
         while Start <= Flags'Last loop
            Fin := Start;
            while Fin <= Flags'Last and then Flags (Fin) /= ' ' loop
               Fin := Fin + 1;
            end loop;
            declare
               Flag : constant String := Flags (Start .. Fin - 1);
            begin
               App_Option (Buf, Len, "--" & Flag, Desc_For (Flag));
            end;
            exit when Fin > Flags'Last;
            Start := Fin + 1;
         end loop;
      end;
      App (Buf, Len, ".SH MODES");
      App_Option
        (Buf,
         Len,
         "sbom",
         "Generate a proof-aware CycloneDX 1.5 / SPDX 2.3 / Markdown "
         & "SBOM.  Standard-aware: honors --standard / --dal / --asil / "
         & "--class and defaults to all standards (DO-178C / ISO 26262 / "
         & "IEC 62304 properties).");
      App_Option
        (Buf,
         Len,
         "prove",
         "Resolve gnatprove (manifest pin, PATH, cached toolchain, or "
         & "download), run it, then assess the target.");
      App_Option
        (Buf,
         Len,
         "status",
         "Report toolchain + platform state without running an "
         & "assessment, including which VCS tools (git, mercurial, "
         & "subversion, fossil, jj, mandb) are available on PATH for the "
         & "differential modes and the VCS managing the target "
         & "repository.");
      App_Option
        (Buf,
         Len,
         "man",
         "Install this man page into the local man database (default "
         & "~/.local/share/man, Linux/WSL) and refresh it with mandb.  "
         & "--check exits 0 when the installed page matches this binary's "
         & "version, 1 when a newer version is available or none is "
         & "installed.  --dir=PATH installs under PATH/man1 instead.  "
         & "--force always (re)writes the installed page even when it "
         & "already matches this binary (repair a hand-edited or corrupt "
         & "page).  The page contains the version, so a prompt hook can "
         & "run `adacovex man --check` and install automatically when the "
         & "machine detects a newer version.");
      App_Option
        (Buf,
         Len,
         "help",
         "Contextual help: `adacovex help serve`, `adacovex help "
         & "--serve`, or `adacovex --serve help` print "
         & "flag/subcommand-specific text.  `adacovex help` (or --help) "
         & "shows the full usage message.  The topic is case-insensitive "
         & "with an optional leading --.");
      App (Buf, Len, ".SH VERSION");
      App (Buf, Len, "adacovex v" & V);
      App (Buf, Len, ".SH EXIT STATUS");
      App_Option
        (Buf,
         Len,
         "0",
         "Success (DAL achieved, all --require-* gates met, man page "
         & "current).");
      App_Option
        (Buf,
         Len,
         "1",
         "Compliance failure, a CI threshold gate unmet, a differential "
         & "regression, a newer man page available, or an operational "
         & "error.");
      App (Buf, Len, ".SH ENVIRONMENT");
      App (Buf, Len, ".TP");
      App (Buf, Len, ".B NO_COLOR");
      App (Buf, Len, "Suppress ANSI color in terminal output.");
      App (Buf, Len, ".TP");
      App (Buf, Len, ".B SOURCE_DATE_EPOCH");
      App (Buf, Len, "Deterministic SBOM timestamps (reproducible builds).");
      App (Buf, Len, ".TP");
      App (Buf, Len, ".B ADACOVEX_VERSION");
      App (Buf, Len, "Release-build version override (tools/gen-version.py).");
      App (Buf, Len, ".SH FILES");
      App (Buf, Len, ".TP");
      App (Buf, Len, ".I ~/.local/share/man/man1/adacovex.1");
      App (Buf, Len, "Installed man page (Linux/WSL default man root).");
      App (Buf, Len, ".TP");
      App (Buf, Len, ".I ~/.adacovex/cache");
      App (Buf, Len, "On-disk analysis result cache.");
      App (Buf, Len, ".SH SEE ALSO");
      App
        (Buf,
         Len,
         "alr(1), gnatprove(1), git(1), hg(1), svn(1), fossil(1), " & "jj(1)");
      App (Buf, Len, "");
      App (Buf, Len, "Project: https://github.com/bladeacer/adacovex");
      return Buf (1 .. Len);
   end Render_Page;

   function Default_Dir return String is
   begin
      if Ada.Environment_Variables.Exists ("XDG_DATA_HOME") then
         declare
            X : constant String :=
              Ada.Environment_Variables.Value ("XDG_DATA_HOME");
         begin
            if X'Length > 0 then
               return X & "/man";
            end if;
         end;
      end if;
      if Ada.Environment_Variables.Exists ("HOME") then
         return Ada.Environment_Variables.Value ("HOME") & "/.local/share/man";
      end if;
      return Adacovex.CPUs.Get_Temp_Directory & "/adacovex-man";
   end Default_Dir;

   procedure Install
     (Man_Root : String; Version : String; Success : out Boolean)
   is
      Root : constant String := Strip_Trailing_Slash (Man_Root);
      Dir  : constant String := Root & "/man1";
      Path : constant String := Dir & "/adacovex.1";
   begin
      Success := False;
      begin
         Ada.Directories.Create_Path (Dir);
      exception
         when others =>
            return;
      end;
      begin
         declare
            F : Ada.Text_IO.File_Type;
         begin
            Ada.Text_IO.Create (F, Ada.Text_IO.Out_File, Path);
            Ada.Text_IO.Put (F, Render_Page (Version));
            Ada.Text_IO.Close (F);
         end;
      exception
         when others =>
            return;
      end;
      Success := True;
   end Install;

   function Update_Database (Man_Root : String) return Boolean is
      use GNAT.OS_Lib;
      Root : constant String := Strip_Trailing_Slash (Man_Root);
      Prog : String_Access := Locate_Exec_On_Path ("mandb");
      OK   : Boolean := False;
      Code : Integer := 0;
   begin
      if Prog = null then
         --  man-db (mandb) is not installed: the page is still written by
         --  Install, but the man database cannot be refreshed.
         return False;
      end if;
      Spawn
        (Prog.all,
         (1 => new String'(Root)),
         "/dev/null",
         OK,
         Code,
         Err_To_Out => True);
      Free (Prog);
      return OK and then Code = 0;
   end Update_Database;

   --  Extract the version token following "adacovex v" in S ("1.10.0").
   function Extract_Version (S : String) return String is
      Needle : constant String := "adacovex v";
      Idx    : Natural := 0;
   begin
      if S'Length >= Needle'Length then
         for I in S'First .. S'Last - Needle'Length + 1 loop
            if S (I .. I + Needle'Length - 1) = Needle then
               Idx := I + Needle'Length;
               exit;
            end if;
         end loop;
      end if;
      if Idx = 0 then
         return "";
      end if;
      declare
         Start : constant Natural := Idx;
      begin
         while Idx <= S'Last
           and then (S (Idx) in '0' .. '9' or else S (Idx) = '.')
         loop
            Idx := Idx + 1;
         end loop;
         if Idx > Start then
            return S (Start .. Idx - 1);
         end if;
      end;
      return "";
   end Extract_Version;

   function Installed_Version (Man_Root : String) return String is
      use Ada.Text_IO;
      Root : constant String := Strip_Trailing_Slash (Man_Root);
      Path : constant String := Root & "/man1/adacovex.1";
      F    : File_Type;
   begin
      if not Ada.Directories.Exists (Path) then
         return "";
      end if;
      begin
         Open (F, In_File, Path);
      exception
         when others =>
            return "";
      end;
      while not End_Of_File (F) loop
         declare
            Line : constant String := Get_Line (F);
            Ver  : constant String := Extract_Version (Line);
         begin
            if Ver'Length > 0 then
               Close (F);
               return Ver;
            end if;
         end;
      end loop;
      Close (F);
      return "";
   end Installed_Version;

end Adacovex.Renderers.Man;
