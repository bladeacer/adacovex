with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Text_IO;
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
   --  description lines (each indented with a tab, as roff expects).
   procedure App_Option
     (Buf : in out String; Len : in out Natural; Name : String; Desc : String)
   is
   begin
      App (Buf, Len, ".TP");
      App (Buf, Len, ".B " & Name);
      App (Buf, Len, ASCII.HT & Desc);
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
      App (Buf, Len, ".B adacovex");
      App (Buf, Len, ".RI [ options ]");
      App (Buf, Len, ".br");
      App (Buf, Len, ".B adacovex sbom");
      App (Buf, Len, ".RI [ --format=FMT ] [ --out=PATH ]");
      App
        (Buf,
         Len,
         ".RI [ --standard=NAME | --dal=LEVEL | --asil=LEVEL | "
         & "--class=LEVEL ]");
      App (Buf, Len, ".br");
      App (Buf, Len, ".B adacovex prove");
      App (Buf, Len, ".RI [ --target=PATH ] [ prove options ]");
      App (Buf, Len, ".br");
      App (Buf, Len, ".B adacovex status");
      App (Buf, Len, ".RI [ --target=PATH ]");
      App (Buf, Len, ".br");
      App (Buf, Len, ".B adacovex man");
      App (Buf, Len, ".RI [ --check ] [ --dir=PATH ]");
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
      App_Option
        (Buf,
         Len,
         "--target=PATH",
         "Target project root directory (default: current " & "directory).");
      App_Option
        (Buf,
         Len,
         "--manifest=PATH",
         "Override the target project manifest file.");
      App_Option
        (Buf,
         Len,
         "--dal=LEVEL",
         "DO-178C DAL level A|B|C|D|E (default: C; also the shared "
         & "rigor tier).");
      App_Option
        (Buf,
         Len,
         "--asil=LEVEL",
         "ISO 26262 level A|B|C|D|QM (sets the standard and tier).");
      App_Option
        (Buf,
         Len,
         "--class=LEVEL",
         "IEC 62304 safety class A|B|C (sets the standard and " & "tier).");
      App_Option
        (Buf,
         Len,
         "--standard=NAME",
         "do178c | iso26262 | iec62304 | all (default: do178c).");
      App_Option
        (Buf,
         Len,
         "--serve / --port=N",
         "Start the HTTP dashboard on port N (default 8080).");
      App_Option
        (Buf,
         Len,
         "--emit-svg=PATH / --no-svg",
         "Write SVG badges to a directory (default "
         & "<target>/docs/badges) or suppress them.");
      App_Option
        (Buf,
         Len,
         "--emit-markdown=PATH",
         "Write VERIFICATION.md and TRACE.md into a directory.");
      App_Option
        (Buf,
         Len,
         "--skip-dir=NAME / --relaxed",
         "Add a directory to the relaxed-mode skip list, or disable "
         & "strict mode.");
      App_Option
        (Buf,
         Len,
         "--cache / --no-cache",
         "Enable (default) or disable the on-disk result cache.");
      App_Option
        (Buf,
         Len,
         "--cache-dir=PATH / --cache-max=N",
         "Relocate the result cache or cap its entry count.");
      App_Option
        (Buf,
         Len,
         "--compare-base=REF",
         "Differential mode: compare against a base revision "
         & "(git/hg/svn/fossil/jj) and report the VC/DAL delta.");
      App_Option
        (Buf,
         Len,
         "--coverage-delta=REF",
         "Docstring-coverage gate: exit non-zero if current "
         & "coverage is below the base revision.");
      App_Option
        (Buf,
         Len,
         "--require-spark=LVL",
         "CI gate: fail loudly if SPARK level < LVL (Stone..Platinum).");
      App_Option
        (Buf,
         Len,
         "--require-docstrings=PCT",
         "CI gate: fail loudly if docstring coverage < PCT% (0-100).");
      App_Option
        (Buf,
         Len,
         "--require-tests=N",
         "CI gate: fail loudly if passing test count < N.");
      App_Option
        (Buf,
         Len,
         "--require-proof=PCT",
         "CI gate: fail loudly if proved-VC coverage < PCT% (0-100).");
      App_Option
        (Buf, Len, "--version", "Print the bundled version and exit.");
      App_Option (Buf, Len, "--help", "Show the full usage message and exit.");
      App (Buf, Len, ".SH MODES");
      App (Buf, Len, ".TP");
      App (Buf, Len, ".B sbom");
      App
        (Buf,
         Len,
         ASCII.HT
         & "Generate a proof-aware CycloneDX 1.5 / SPDX 2.3 / "
         & "Markdown SBOM.");
      App
        (Buf,
         Len,
         ASCII.HT
         & "Standard-aware: honors --standard / --dal / --asil / --class");
      App
        (Buf,
         Len,
         ASCII.HT
         & "and defaults to all standards (DO-178C / ISO 26262 / IEC");
      App (Buf, Len, ASCII.HT & "62304 properties).");
      App (Buf, Len, ".TP");
      App (Buf, Len, ".B prove");
      App
        (Buf,
         Len,
         ASCII.HT
         & "Resolve gnatprove (manifest pin, PATH, cached "
         & "toolchain, or");
      App (Buf, Len, ASCII.HT & "download), run it, then assess the target.");
      App (Buf, Len, ".TP");
      App (Buf, Len, ".B status");
      App
        (Buf,
         Len,
         ASCII.HT
         & "Report toolchain + platform state without running an "
         & "assessment,");
      App
        (Buf,
         Len,
         ASCII.HT
         & "including which VCS tools (git, mercurial, subversion,"
         & " fossil,");
      App
        (Buf,
         Len,
         ASCII.HT
         & "jj, mandb) are available on PATH for the differential "
         & "modes and");
      App (Buf, Len, ASCII.HT & "the VCS managing the target repository.");
      App (Buf, Len, ".TP");
      App (Buf, Len, ".B man");
      App
        (Buf,
         Len,
         ASCII.HT
         & "Install this man page into the local man database "
         & "(default");
      App
        (Buf,
         Len,
         ASCII.HT
         & "~/.local/share/man, Linux/WSL) and refresh it with "
         & "mandb.");
      App
        (Buf,
         Len,
         ASCII.HT
         & "--check exits 0 when the installed page "
         & "matches this");
      App
        (Buf,
         Len,
         ASCII.HT
         & "binary's version, 1 when a newer version is "
         & "available or");
      App
        (Buf,
         Len,
         ASCII.HT
         & "none is installed.  --dir=PATH installs "
         & "under PATH/man1");
      App
        (Buf,
         Len,
         ASCII.HT
         & "instead.  The page contains the version, so "
         & "a prompt hook");
      App
        (Buf,
         Len,
         ASCII.HT
         & "can run `adacovex man --check` and install "
         & "automatically");
      App (Buf, Len, ASCII.HT & "when the machine detects a newer version.");
      App (Buf, Len, ".SH VERSION");
      App (Buf, Len, "adacovex v" & V);
      App (Buf, Len, ".SH EXIT STATUS");
      App (Buf, Len, ".TP");
      App (Buf, Len, ".B 0");
      App
        (Buf,
         Len,
         ASCII.HT
         & "Success (DAL achieved, all --require-* gates met, man "
         & "page current).");
      App (Buf, Len, ".TP");
      App (Buf, Len, ".B 1");
      App
        (Buf,
         Len,
         ASCII.HT
         & "Compliance failure, a CI threshold gate unmet, a "
         & "differential");
      App
        (Buf,
         Len,
         ASCII.HT
         & "regression, a newer man page available, or an "
         & "operational error.");
      App (Buf, Len, ".SH ENVIRONMENT");
      App (Buf, Len, ".TP");
      App (Buf, Len, ".B NO_COLOR");
      App (Buf, Len, ASCII.HT & "Suppress ANSI color in terminal output.");
      App (Buf, Len, ".TP");
      App (Buf, Len, ".B SOURCE_DATE_EPOCH");
      App
        (Buf,
         Len,
         ASCII.HT & "Deterministic SBOM timestamps (reproducible builds).");
      App (Buf, Len, ".TP");
      App (Buf, Len, ".B ADACOVEX_VERSION");
      App
        (Buf,
         Len,
         ASCII.HT & "Release-build version override (tools/gen-version.py).");
      App (Buf, Len, ".SH FILES");
      App (Buf, Len, ".TP");
      App (Buf, Len, ".I ~/.local/share/man/man1/adacovex.1");
      App
        (Buf,
         Len,
         ASCII.HT & "Installed man page (Linux/WSL default man root).");
      App (Buf, Len, ".TP");
      App (Buf, Len, ".I ~/.adacovex/cache");
      App (Buf, Len, ASCII.HT & "On-disk analysis result cache.");
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
      return "/tmp/adacovex-man";
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
