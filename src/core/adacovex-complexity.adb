with Ada.Containers.Vectors;
with Ada.Directories;
with Ada.Text_IO;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Characters.Handling;
with Adacovex.Ansi;
with Adacovex.Parsers;
with Adacovex.Types;

package body Adacovex.Complexity is

   use Ada.Strings.Fixed;
   use Ada.Strings.Unbounded;
   use Ada.Characters.Handling;
   use type Ada.Containers.Count_Type;

   --  Strip Ada line comments (--) while preserving string literals so
   --  decision-point counting sees the raw source, not the comment text.
   function Strip_Comments (Line : String) return String is
      Out_Buf : Unbounded_String;
      In_Str  : Boolean := False;
   begin
      for I in Line'Range loop
         declare
            C : constant Character := Line (I);
         begin
            if In_Str then
               Append (Out_Buf, C);
               if C = '"' then
                  In_Str := False;
               end if;
            elsif C = '"' then
               In_Str := True;
               Append (Out_Buf, C);
            elsif I < Line'Last and then C = '-' and then Line (I + 1) = '-'
            then
               exit;
            else
               Append (Out_Buf, C);
            end if;
         end;
      end loop;
      return To_String (Out_Buf);
   end Strip_Comments;

   --  Case-insensitive prefix check: True when S starts with Prefix
   --  (ignoring case for the overlapping portion).
   function CI_Starts_With (S : String; Prefix : String) return Boolean is
   begin
      if Prefix'Length > S'Length then
         return False;
      end if;
      for I in Prefix'Range loop
         declare
            C1 : constant Character :=
              To_Lower (S (S'First + (I - Prefix'First)));
            C2 : constant Character := To_Lower (Prefix (I));
         begin
            if C1 /= C2 then
               return False;
            end if;
         end;
      end loop;
      return True;
   end CI_Starts_With;

   --  Trim leading and trailing blanks, tabs, CR, and LF from S.
   function Trim (S : String) return String is
      F, L : Natural := S'First;
   begin
      while F <= S'Last loop
         exit when
           S (F) /= ' '
           and then S (F) /= ASCII.HT
           and then S (F) /= ASCII.CR
           and then S (F) /= ASCII.LF;
         F := F + 1;
      end loop;
      L := S'Last;
      while L >= F loop
         exit when
           S (L) /= ' '
           and then S (L) /= ASCII.HT
           and then S (L) /= ASCII.CR
           and then S (L) /= ASCII.LF;
         L := L - 1;
      end loop;
      if F > L then
         return "";
      end if;
      return S (F .. L);
   end Trim;

   --  Count Ada decision points (if, elsif, case, while, for, exit, when,
   --  and/or short-circuit after then/else) in a single line of source.
   function Count_Decisions (Line : String) return Natural is
      S    : constant String := Strip_Comments (Line);
      N    : Natural := 0;
      I    : Natural := S'First;
      Prev : String (1 .. 16) := (others => ' ');
      PLen : Natural := 0;
      T    : String (1 .. 64);
      TL   : Natural := 0;
   begin
      while I <= S'Last loop
         while I <= S'Last loop
            exit when
              S (I) in 'a' .. 'z'
              or else S (I) in 'A' .. 'Z'
              or else S (I) in '0' .. '9'
              or else S (I) = '_';
            I := I + 1;
         end loop;
         if I > S'Last then
            exit;
         end if;
         TL := 0;
         while I <= S'Last loop
            exit when
              not (S (I) in 'a' .. 'z'
                   or else S (I) in 'A' .. 'Z'
                   or else S (I) in '0' .. '9'
                   or else S (I) = '_');
            if TL < T'Last then
               TL := TL + 1;
               T (TL) := To_Lower (S (I));
            end if;
            I := I + 1;
         end loop;
         if TL = 2 and then T (1 .. 2) = "if" then
            N := N + 1;
         elsif TL = 5 and then T (1 .. 5) = "elsif" then
            N := N + 1;
         elsif TL = 4 and then T (1 .. 4) = "case" then
            N := N + 1;
         elsif TL = 5 and then T (1 .. 5) = "while" then
            N := N + 1;
         elsif TL = 3 and then T (1 .. 3) = "for" then
            N := N + 1;
         elsif TL = 4 and then T (1 .. 4) = "exit" then
            N := N + 1;
         elsif TL = 4 and then T (1 .. 4) = "when" then
            N := N + 1;
         elsif TL = 3
           and then T (1 .. 3) = "and"
           and then PLen = 4
           and then Prev (1 .. 4) = "then"
         then
            N := N + 1;
         elsif TL = 2
           and then T (1 .. 2) = "or"
           and then PLen = 4
           and then Prev (1 .. 4) = "else"
         then
            N := N + 1;
         end if;
         if TL <= Prev'Last then
            Prev (1 .. TL) := T (1 .. TL);
            PLen := TL;
         else
            Prev := (others => ' ');
            PLen := 0;
         end if;
      end loop;
      return N;
   end Count_Decisions;

   --  True when the first keyword of S is a block opener that cannot end a
   --  decision point (if, loop, case, select, return, declare, block).
   function Forbidden_End (S : String) return Boolean is
      L : String (1 .. 7) := (others => ' ');
      N : Natural := 0;
   begin
      for I in S'Range loop
         exit when N = 7;
         N := N + 1;
         L (N) := To_Lower (S (I));
      end loop;
      return
        (N >= 2 and then L (1 .. 2) = "if")
        or else (N >= 4 and then L (1 .. 4) = "loop")
        or else (N >= 4 and then L (1 .. 4) = "case")
        or else (N >= 6 and then L (1 .. 6) = "select")
        or else (N >= 6 and then L (1 .. 6) = "return")
        or else (N >= 7 and then L (1 .. 7) = "declare")
        or else (N >= 5 and then L (1 .. 5) = "block");
   end Forbidden_End;

   --  Detect a package or package-body declaration and return its name.
   procedure Detect_Package
     (S : String; Pkg : out Boolean; Name : out String; Name_Len : out Natural)
   is
      I : Natural := S'First;
   begin
      Pkg := False;
      Name_Len := 0;
      Name := (others => ' ');
      if not CI_Starts_With (S, "package") then
         return;
      end if;
      I := I + 7;
      while I <= S'Last and then S (I) = ' ' loop
         I := I + 1;
      end loop;
      if I > S'Last then
         return;
      end if;
      if CI_Starts_With (S (I .. S'Last), "body") then
         I := I + 4;
         while I <= S'Last and then S (I) = ' ' loop
            I := I + 1;
         end loop;
      end if;
      if I > S'Last then
         return;
      end if;
      declare
         Start : Natural := I;
      begin
         while I <= S'Last loop
            exit when
              not (S (I) in 'a' .. 'z'
                   or else S (I) in 'A' .. 'Z'
                   or else S (I) in '0' .. '9'
                   or else S (I) = '.'
                   or else S (I) = '_');
            I := I + 1;
         end loop;
         if I > Start then
            Name_Len := I - Start;
            Name (1 .. Name_Len) := S (Start .. I - 1);
         else
            return;
         end if;
      end;
      while I <= S'Last and then S (I) = ' ' loop
         I := I + 1;
      end loop;
      if CI_Starts_With (S (I .. S'Last), "is") then
         Pkg := True;
      end if;
   end Detect_Package;

   --  Detect a procedure or function header line and return its name.
   procedure Detect_Header
     (S : String; Hdr : out Boolean; Name : out String; Name_Len : out Natural)
   is
      I : Natural := S'First;
   begin
      Hdr := False;
      Name_Len := 0;
      Name := (others => ' ');
      if S'Length < 5 then
         return;
      end if;
      if S (S'First) /= ' '
        or else S (S'First + 1) /= ' '
        or else S (S'First + 2) /= ' '
      then
         return;
      end if;
      if S (S'First + 3) = ' ' then
         return;
      end if;
      I := S'First + 3;
      if CI_Starts_With (S (I .. S'Last), "overriding") then
         I := I + 10;
         while I <= S'Last and then S (I) = ' ' loop
            I := I + 1;
         end loop;
      end if;
      if I > S'Last then
         return;
      end if;
      declare
         Is_Proc : constant Boolean :=
           CI_Starts_With (S (I .. S'Last), "procedure");
         Is_Func : constant Boolean :=
           CI_Starts_With (S (I .. S'Last), "function");
      begin
         if not (Is_Proc or Is_Func) then
            return;
         end if;
         if Is_Proc then
            I := I + 9;
         else
            I := I + 8;
         end if;
         while I <= S'Last and then S (I) = ' ' loop
            I := I + 1;
         end loop;
         if I > S'Last then
            return;
         end if;
         declare
            Start : Natural := I;
         begin
            while I <= S'Last loop
               exit when
                 not (S (I) in 'a' .. 'z'
                      or else S (I) in 'A' .. 'Z'
                      or else S (I) in '0' .. '9'
                      or else S (I) = '_');
               I := I + 1;
            end loop;
            if I > Start then
               Name_Len := I - Start;
               Name (1 .. Name_Len) := S (Start .. I - 1);
               Hdr := True;
            end if;
         end;
      end;
   end Detect_Header;

   --  Detect an end (or end name;) line and return whether it is a bare end.
   procedure Detect_End
     (S               : String;
      Is_End, Is_Bare : out Boolean;
      Name            : out String;
      Name_Len        : out Natural)
   is
      I : Natural := S'First;
   begin
      Is_End := False;
      Is_Bare := False;
      Name_Len := 0;
      Name := (others => ' ');
      if S'Length < 3 or else not CI_Starts_With (S, "end") then
         return;
      end if;
      I := I + 3;
      while I <= S'Last and then S (I) = ' ' loop
         I := I + 1;
      end loop;
      if I > S'Last then
         Is_End := True;
         Is_Bare := True;
         return;
      end if;
      if Forbidden_End (S (I .. S'Last)) then
         return;
      end if;
      declare
         Start : Natural := I;
      begin
         while I <= S'Last loop
            exit when
              not (S (I) in 'a' .. 'z'
                   or else S (I) in 'A' .. 'Z'
                   or else S (I) in '0' .. '9'
                   or else S (I) = '.'
                   or else S (I) = '_');
            I := I + 1;
         end loop;
         if I > Start then
            Name_Len := I - Start;
            Name (1 .. Name_Len) := S (Start .. I - 1);
            while I <= S'Last and then S (I) = ' ' loop
               I := I + 1;
            end loop;
            if I > S'Last then
               Is_End := True;
               return;
            end if;
            if S (I) = ';' then
               I := I + 1;
               while I <= S'Last and then S (I) = ' ' loop
                  I := I + 1;
               end loop;
               if I > S'Last then
                  Is_End := True;
                  return;
               end if;
            end if;
            return;
         elsif S (I) = ';' then
            I := I + 1;
            while I <= S'Last and then S (I) = ' ' loop
               I := I + 1;
            end loop;
            if I > S'Last then
               Is_End := True;
               Is_Bare := True;
               return;
            end if;
         end if;
      end;
   end Detect_End;

   --  Lowercased filename extension without the dot, up to 8 chars; "" when
   --  the name has no extension or starts with a dot (hidden file).
   function Lower_Ext (Name : String) return String is
      Dot : Integer := 0;
      Buf : String (1 .. 8);
      Len : Natural := 0;
   begin
      if Name'Length < 2 or else Name (Name'First) = '.' then
         return "";
      end if;
      for I in reverse Name'Range loop
         if Name (I) = '.' then
            Dot := I;
            exit;
         end if;
      end loop;
      if Dot <= Name'First then
         return "";
      end if;
      for I in Dot + 1 .. Name'Last loop
         exit when Len = 8;
         Len := Len + 1;
         Buf (Len) := To_Lower (Name (I));
      end loop;
      if Len = 0 then
         return "";
      end if;
      return Buf (1 .. Len);
   end Lower_Ext;

   --  True when Ext (lowercased, no dot) is one of the scanned extensions:
   --  Ada, C/C++, C#, Go, Java, JS/TS, Python, Ruby, PHP, Rust, Shell,
   --  Kotlin, YAML/JSON/TOML/XML, Markdown, or reStructuredText.
   function Scanned_Ext (Ext : String) return Boolean is
      List : constant array (1 .. 32) of String (1 .. 4) :=
        ("ads ",
         "adb ",
         "ada ",
         "gpr ",
         "c   ",
         "h   ",
         "cpp ",
         "hpp ",
         "cxx ",
         "cc  ",
         "cs  ",
         "go  ",
         "java",
         "js  ",
         "mjs ",
         "cjs ",
         "ts  ",
         "jsx ",
         "tsx ",
         "py  ",
         "rb  ",
         "php ",
         "rs  ",
         "sh  ",
         "kt  ",
         "yaml",
         "yml ",
         "json",
         "toml",
         "xml ",
         "md  ",
         "rst ");
      Lens : constant array (1 .. 32) of Natural :=
        (3,
         3,
         3,
         3,
         1,
         1,
         3,
         3,
         3,
         2,
         2,
         2,
         4,
         2,
         3,
         3,
         2,
         3,
         3,
         2,
         2,
         3,
         2,
         2,
         2,
         4,
         3,
         4,
         4,
         3,
         2,
         3);
   begin
      for I in List'Range loop
         if Ext'Length = Lens (I) and then Ext = List (I) (1 .. Lens (I)) then
            return True;
         end if;
      end loop;
      return False;
   end Scanned_Ext;

   --  Display language name for a scanned extension (tokei-style).
   function Lang_Name (Ext : String) return String is
   begin
      if Ext = "ads"
        or else Ext = "adb"
        or else Ext = "ada"
        or else Ext = "gpr"
      then
         return "Ada";
      elsif Ext = "c" or else Ext = "h" then
         return "C";
      elsif Ext = "cpp"
        or else Ext = "cxx"
        or else Ext = "cc"
        or else Ext = "hpp"
      then
         return "C++";
      elsif Ext = "cs" then
         return "C#";
      elsif Ext = "go" then
         return "Go";
      elsif Ext = "java" then
         return "Java";
      elsif Ext = "js"
        or else Ext = "mjs"
        or else Ext = "cjs"
        or else Ext = "jsx"
      then
         return "JavaScript";
      elsif Ext = "ts" or else Ext = "tsx" then
         return "TypeScript";
      elsif Ext = "py" then
         return "Python";
      elsif Ext = "rb" then
         return "Ruby";
      elsif Ext = "php" then
         return "PHP";
      elsif Ext = "rs" then
         return "Rust";
      elsif Ext = "sh" then
         return "Shell";
      elsif Ext = "kt" then
         return "Kotlin";
      elsif Ext = "yaml" or else Ext = "yml" then
         return "YAML";
      elsif Ext = "json" then
         return "JSON";
      elsif Ext = "toml" then
         return "TOML";
      elsif Ext = "xml" then
         return "XML";
      elsif Ext = "md" then
         return "Markdown";
      elsif Ext = "rst" then
         return "reStructuredText";
      else
         return "Unknown";
      end if;
   end Lang_Name;

   --  True when Ext (lowercased, no dot) is listed in the comma-separated
   --  Excludes list (no leading dots; matched case-insensitively).
   function Is_Excluded (Ext : String; Excludes : String) return Boolean is
      Start : Natural := Excludes'First;
   begin
      if Excludes'Length = 0 then
         return False;
      end if;
      while Start <= Excludes'Last loop
         declare
            Fin : Natural := Start;
         begin
            while Fin <= Excludes'Last
              and then Excludes (Fin) /= ','
              and then Excludes (Fin) /= ' '
            loop
               Fin := Fin + 1;
            end loop;
            declare
               Len : constant Natural := Fin - Start;
            begin
               if Len = Ext'Length then
                  declare
                     Match : Boolean := True;
                  begin
                     for I in 1 .. Len loop
                        if Ext (Ext'First + I - 1)
                          /= To_Lower (Excludes (Start + I - 1))
                        then
                           Match := False;
                           exit;
                        end if;
                     end loop;
                     if Match then
                        return True;
                     end if;
                  end;
               end if;
            end;
            exit when Fin > Excludes'Last;
            Start := Fin + 1;
         end;
      end loop;
      return False;
   end Is_Excluded;

   --  True when a directory name should be skipped during the walk: version
   --  control metadata, generated/dependency trees, unit-test suites, and
   --  vendored assets that are not part of the assessed source.
   function Skip_Dir (N : String) return Boolean is
   begin
      return
        N = ".git"
        or else N = ".alire"
        or else N = ".jj"
        or else N = ".hg"
        or else N = ".svn"
        or else N = "_darcs"
        or else N = "obj"
        or else N = "bin"
        or else N = "dist"
        or else N = "build"
        or else N = "node_modules"
        or else N = "test-results"
        or else N = "playwright-report"
        or else N = "tests"
        or else N = "media"
        or else N = "index"
        or else N = "alire"
        or else N = "skills";
   end Skip_Dir;

   --  Walk Target_Dir and collect every supported source file except the
   --  generated version/dashboard units and any extension listed in Excludes.
   --  Dependency/generated directories (see Skip_Dir) are never descended.
   function Scan_Source_Files
     (Target_Dir : String; Excludes : String) return File_Vectors.Vector
   is
      use Ada.Directories;
      Result : File_Vectors.Vector;

      Abs_Target : constant String :=
        (if Exists (Target_Dir) then Full_Name (Target_Dir) else Target_Dir);

      procedure Walk (Dir : String) is
         Search : Search_Type;
         Ent    : Directory_Entry_Type;
      begin
         Start_Search (Search, Dir, "");
         while More_Entries (Search) loop
            Get_Next_Entry (Search, Ent);
            declare
               N : constant String := Simple_Name (Ent);
            begin
               if N = "." or else N = ".." then
                  null;
               elsif Kind (Ent) = Directory then
                  if not Skip_Dir (N) then
                     Walk (Full_Name (Ent));
                  end if;
               elsif Kind (Ent) = Ordinary_File then
                  declare
                     Ext  : constant String := Lower_Ext (N);
                     Lang : constant String := Lang_Name (Ext);
                  begin
                     if Ext'Length > 0
                       and then Scanned_Ext (Ext)
                       and then not Is_Excluded (Ext, Excludes)
                       and then N /= "adacovex_version_info.ads"
                       and then N /= "adacovex-dashboard_template.ads"
                     then
                        declare
                           Item : File_Metrics;
                           Full : constant String := Full_Name (Ent);
                        begin
                           Item.Path_Len := Full'Length;
                           Item.Path (1 .. Item.Path_Len) := Full;
                           Item.Language_Len := Lang'Length;
                           if Lang'Length > 0 then
                              Item.Language (1 .. Lang'Length) := Lang;
                           end if;
                           Result.Append (Item);
                        end;
                     end if;
                  end;
               end if;
            end;
         end loop;
         End_Search (Search);
      exception
         when others =>
            End_Search (Search);
      end Walk;

   begin
      --  Walk the whole target (not just src/) so non-Ada source files are
      --  included; Skip_Dir keeps dependency/generated trees out.
      if Exists (Abs_Target) then
         Walk (Abs_Target);
      end if;
      return Result;
   end Scan_Source_Files;

   --  Compute per-file and per-subprogram complexity for a single Ada source.
   function Analyze_File (Path : String) return File_Metrics is
      use Ada.Text_IO;

      Line    : String (1 .. Types.Max_Line);
      Last    : Natural;
      Line_No : Natural := 0;
      LOC     : Natural := 0;
      F       : File_Type;

      type Block_Kind is (Pkg_Block, Sub_Block);
      type Stack_Entry is record
         Kind     : Block_Kind;
         Name     : String (1 .. 128);
         Name_Len : Natural := 0;
      end record;
      Stack : array (1 .. 64) of Stack_Entry;
      Depth : Natural := 0;

      Cur    : Subprogram_Info;
      Cur_On : Boolean := False;

      procedure Flush (Subs : in out Subprogram_Vectors.Vector) is
      begin
         if Cur_On then
            Cur.Name_Len := Cur.Name_Len;
            Subs.Append (Cur);
            Cur_On := False;
         end if;
      end Flush;

      procedure Push_Block (K : Block_Kind; N : String; L : Natural) is
      begin
         if Depth < Stack'Last then
            Depth := Depth + 1;
            Stack (Depth).Kind := K;
            Stack (Depth).Name (1 .. L) := N (1 .. L);
            Stack (Depth).Name_Len := L;
         end if;
      end Push_Block;

      procedure Pop_Block is
      begin
         if Depth > 0 then
            Depth := Depth - 1;
         end if;
      end Pop_Block;

      Result : File_Metrics;

   begin
      Result.Path_Len := Path'Length;
      Result.Path (1 .. Result.Path_Len) := Path;

      --  Language is derived from the file extension (tokei-style).
      declare
         Ext  : constant String := Lower_Ext (Path);
         Lang : constant String := Lang_Name (Ext);
      begin
         if Lang'Length > 0 then
            Result.Language_Len := Lang'Length;
            Result.Language (1 .. Lang'Length) := Lang;
         end if;
      end;

      begin
         Open (F, In_File, Path);
      exception
         when others =>
            return Result;
      end;

      while not End_Of_File (F) loop
         declare
            Raw       : String (1 .. Types.Max_Line);
            Last_Raw  : Natural;
            Ovl       : Boolean;
            Raw_S     : String (1 .. Types.Max_Line);
            RL        : Natural := 0;
            Decisions : Natural;
            Pkg_Found : Boolean;
            Hdr_Found : Boolean;
            End_Found : Boolean;
            Bare_End  : Boolean;
            Pkg_Name  : String (1 .. 128);
            Pkg_Len   : Natural := 0;
            Hdr_Name  : String (1 .. 128);
            Hdr_Len   : Natural := 0;
            End_Name  : String (1 .. 128);
            End_Len   : Natural := 0;
            Clean     : String (1 .. Types.Max_Line);
            CLen      : Natural := 0;
         begin
            Line_No := Line_No + 1;
            Adacovex.Parsers.Read_Line (F, Path, Line_No, Raw, Last_Raw, Ovl);
            Result.Total_Lines := Result.Total_Lines + 1;
            if Ovl then
               --  An over-long line is still one physical line.  Classify it
               --  by content: a comment-only line counts as a comment; a
               --  blank or source line counts as code (its length alone
               --  proves it carries source).
               declare
                  T : constant String := Trim (Raw (1 .. Last_Raw));
               begin
                  if T'Length >= 2
                    and then T (T'First) = '-'
                    and then T (T'First + 1) = '-'
                  then
                     Result.Comment_Lines := Result.Comment_Lines + 1;
                  else
                     Result.Code_Lines := Result.Code_Lines + 1;
                  end if;
               end;
               goto Next_Line;
            end if;
            RL := Last_Raw;
            Raw_S (1 .. RL) := Raw (1 .. Last_Raw);
            declare
               procedure Do_Strip is
                  Tmp  : String (1 .. Types.Max_Line);
                  TLen : Natural := 0;
               begin
                  for I in 1 .. RL loop
                     if TLen < Tmp'Last then
                        TLen := TLen + 1;
                        Tmp (TLen) := Raw_S (I);
                     end if;
                  end loop;
                  declare
                     S : constant String :=
                       Trim (Strip_Comments (Tmp (1 .. TLen)));
                  begin
                     CLen := S'Length;
                     Clean (1 .. CLen) := S;
                  end;
               end Do_Strip;
            begin
               Do_Strip;
            end;
            declare
               Raw_T : constant String := Trim (Raw_S (1 .. RL));
            begin
               if Raw_T'Length = 0 then
                  --  Whitespace-only line: a blank line.
                  Result.Blank_Lines := Result.Blank_Lines + 1;
               elsif Raw_T'Length >= 2
                 and then Raw_T (Raw_T'First) = '-'
                 and then Raw_T (Raw_T'First + 1) = '-'
               then
                  --  A line whose only content is a comment.
                  Result.Comment_Lines := Result.Comment_Lines + 1;
               else
                  LOC := LOC + 1;
                  Result.Code_Lines := Result.Code_Lines + 1;
               end if;
            end;
            if CLen = 0 then
               goto Next_Line;
            end if;
            Decisions := Count_Decisions (Raw_S (1 .. RL));
            Detect_Package
              (Clean (Clean'First .. Clean'First + CLen - 1),
               Pkg_Found,
               Pkg_Name,
               Pkg_Len);
            Detect_Header (Raw_S (1 .. RL), Hdr_Found, Hdr_Name, Hdr_Len);
            Detect_End
              (Clean (Clean'First .. Clean'First + CLen - 1),
               End_Found,
               Bare_End,
               End_Name,
               End_Len);
            if Pkg_Found then
               Push_Block (Pkg_Block, Pkg_Name (1 .. Pkg_Len), Pkg_Len);
            elsif Hdr_Found then
               if Cur_On then
                  Flush (Result.Subs);
               end if;
               declare
                  Nm : constant String := Hdr_Name (1 .. Hdr_Len);
               begin
                  Cur.Name (1 .. Nm'Length) := Nm;
                  Cur.Name_Len := Nm'Length;
                  Cur.Line := Line_No;
                  Cur.Complexity := Decisions;
                  Cur.LOC := 1;
                  Cur_On := True;
                  Push_Block (Sub_Block, Nm, Nm'Length);
               end;
            elsif End_Found then
               if Depth = 0 then
                  if Cur_On then
                     Flush (Result.Subs);
                  end if;
               else
                  declare
                     Top_Name : constant String :=
                       Stack (Depth).Name (1 .. Stack (Depth).Name_Len);
                     Top_Kind : constant Block_Kind := Stack (Depth).Kind;
                  begin
                     if End_Len > 0
                       and then End_Len = Top_Name'Length
                       and then End_Name (1 .. End_Len) = Top_Name
                     then
                        Pop_Block;
                        if Top_Kind = Sub_Block then
                           Flush (Result.Subs);
                        end if;
                     elsif End_Len = 0
                       and then Top_Kind = Sub_Block
                       and then Depth = 1
                     then
                        Pop_Block;
                        Flush (Result.Subs);
                     end if;
                  end;
               end if;
            else
               if Cur_On
                 and then Depth > 0
                 and then Stack (Depth).Kind = Sub_Block
               then
                  Cur.Complexity := Cur.Complexity + Decisions;
                  Cur.LOC := Cur.LOC + 1;
               end if;
            end if;
            <<Next_Line>>
            null;
         end;
      end loop;

      if Cur_On then
         Flush (Result.Subs);
      end if;

      Close (F);

      Result.LOC := LOC;
      for S of Result.Subs loop
         Result.Complexity := Result.Complexity + S.Complexity;
      end loop;

      return Result;
   exception
      when others =>
         if Is_Open (F) then
            Close (F);
         end if;
         return Result;
   end;

   --  Scan Target_Dir and return aggregate complexity metrics across all
   --  discovered source files (skipping any extension listed in Excludes).
   function Analyze_Project
     (Target_Dir : String; Excludes : String := "") return Complexity_Result
   is
      Files : constant File_Vectors.Vector :=
        Scan_Source_Files (Target_Dir, Excludes);
      Res   : Complexity_Result;
   begin
      for I in 1 .. Integer (Files.Length) loop
         declare
            FM : constant File_Metrics :=
              Analyze_File (Files (I).Path (1 .. Files (I).Path_Len));
         begin
            Res.Files.Append (FM);
            Res.Total_LOC := Res.Total_LOC + FM.LOC;
         end;
      end loop;
      return Res;
   end Analyze_Project;

   --  Evaluate Result against the supplied thresholds and return the list of
   --  violations (empty when every gate passes).
   function Check_Gates
     (Result              : Complexity_Result;
      Max_File_LOC        : Natural;
      Max_File_Pct        : Natural;
      Max_Fn_Complexity   : Natural;
      Max_File_Complexity : Natural) return Violation_Vectors.Vector
   is
      V : Violation_Vectors.Vector;
   begin
      for I in 1 .. Integer (Result.Files.Length) loop
         declare
            FM  : File_Metrics renames Result.Files (I);
            Pct : Natural := 0;
         begin
            if Result.Total_LOC > 0 then
               Pct := (FM.LOC * 100) / Result.Total_LOC;
            end if;
            for S of FM.Subs loop
               if S.Complexity > Max_Fn_Complexity then
                  declare
                     Suffix : constant String :=
                       " '"
                       & S.Name (1 .. S.Name_Len)
                       & "' cyclomatic "
                       & Trim (Natural'Image (S.Complexity))
                       & " > "
                       & Trim (Natural'Image (Max_Fn_Complexity));
                     M      : Violation;
                  begin
                     M.File_Len := FM.Path_Len;
                     M.File_Path (1 .. M.File_Len) :=
                       FM.Path (1 .. FM.Path_Len);
                     M.Message (1 .. Suffix'Length) := Suffix;
                     M.Msg_Len := Suffix'Length;
                     V.Append (M);
                  end;
               end if;
            end loop;
            if FM.LOC > Max_File_LOC then
               declare
                  Suffix : constant String :=
                    " LOC "
                    & Trim (Natural'Image (FM.LOC))
                    & " > "
                    & Trim (Natural'Image (Max_File_LOC));
                  M      : Violation;
               begin
                  M.File_Len := FM.Path_Len;
                  M.File_Path (1 .. M.File_Len) := FM.Path (1 .. FM.Path_Len);
                  M.Message (1 .. Suffix'Length) := Suffix;
                  M.Msg_Len := Suffix'Length;
                  V.Append (M);
               end;
            end if;
            if Pct > Max_File_Pct then
               declare
                  Suffix : constant String :=
                    " "
                    & Trim (Natural'Image (Pct))
                    & "% of codebase > "
                    & Trim (Natural'Image (Max_File_Pct))
                    & "%";
                  M      : Violation;
               begin
                  M.File_Len := FM.Path_Len;
                  M.File_Path (1 .. M.File_Len) := FM.Path (1 .. FM.Path_Len);
                  M.Message (1 .. Suffix'Length) := Suffix;
                  M.Msg_Len := Suffix'Length;
                  V.Append (M);
               end;
            end if;
            if FM.Complexity > Max_File_Complexity then
               declare
                  Suffix : constant String :=
                    " total cyclomatic "
                    & Trim (Natural'Image (FM.Complexity))
                    & " > "
                    & Trim (Natural'Image (Max_File_Complexity));
                  M      : Violation;
               begin
                  M.File_Len := FM.Path_Len;
                  M.File_Path (1 .. M.File_Len) := FM.Path (1 .. FM.Path_Len);
                  M.Message (1 .. Suffix'Length) := Suffix;
                  M.Msg_Len := Suffix'Length;
                  V.Append (M);
               end;
            end if;
         end;
      end loop;
      return V;
   end Check_Gates;

   --  Emit a human-readable report to stdout.  When Check_Mode is True the
   --  output is gated on Violations being non-empty; otherwise every file
   --  and subprogram is always printed.
   procedure Print_Report
     (Result              : Complexity_Result;
      Check_Mode          : Boolean;
      Violations          : Violation_Vectors.Vector;
      Max_File_LOC        : Natural;
      Max_File_Pct        : Natural;
      Max_Fn_Complexity   : Natural;
      Max_File_Complexity : Natural)
   is
      Marker : String (1 .. 40) := (others => ' ');
      MLen   : Natural := 0;

      --  Per-language aggregates for the tokei-style summary block.
      type Lang_Agg is record
         Name     : String (1 .. 16);
         NLen     : Natural := 0;
         Files    : Natural := 0;
         Lines    : Natural := 0;
         Code     : Natural := 0;
         Comments : Natural := 0;
         Blanks   : Natural := 0;
      end record;
      package Lang_Vecs is new Ada.Containers.Vectors (Positive, Lang_Agg);
      Langs : Lang_Vecs.Vector;

      function Img (N : Natural) return String
      is (Trim (Natural'Image (N)));

      procedure Add_Lang (Lang : String; L, C, Comm, B : Natural) is
      begin
         for I in 1 .. Integer (Langs.Length) loop
            if Langs (I).NLen = Lang'Length
              and then Langs (I).Name (1 .. Lang'Length) = Lang
            then
               Langs (I).Files := Langs (I).Files + 1;
               Langs (I).Lines := Langs (I).Lines + L;
               Langs (I).Code := Langs (I).Code + C;
               Langs (I).Comments := Langs (I).Comments + Comm;
               Langs (I).Blanks := Langs (I).Blanks + B;
               return;
            end if;
         end loop;
         declare
            A : Lang_Agg;
         begin
            A.NLen := Lang'Length;
            A.Name (1 .. Lang'Length) := Lang;
            A.Files := 1;
            A.Lines := L;
            A.Code := C;
            A.Comments := Comm;
            A.Blanks := B;
            Langs.Append (A);
         end;
      end Add_Lang;
   begin
      --  Aggregate the tokei-style metrics per programming language.
      for I in 1 .. Integer (Result.Files.Length) loop
         declare
            FM : File_Metrics renames Result.Files (I);
            L  : constant String :=
              (if FM.Language_Len > 0
               then FM.Language (1 .. FM.Language_Len)
               else "Unknown");
         begin
            Add_Lang
              (L,
               FM.Total_Lines,
               FM.Code_Lines,
               FM.Comment_Lines,
               FM.Blank_Lines);
         end;
      end loop;

      --  Tokei-style summary: one row per language.
      Ada.Text_IO.Put_Line
        ("Language              Files      Lines       Code   Comments      Blanks");
      for I in 1 .. Integer (Langs.Length) loop
         declare
            A  : Lang_Agg renames Langs (I);
            Nm : constant String := A.Name (1 .. A.NLen);
         begin
            Ada.Text_IO.Put (Nm);
            for J in A.NLen + 1 .. 22 loop
               Ada.Text_IO.Put (' ');
            end loop;
            Ada.Text_IO.Put_Line
              (Img (A.Files)
               & "   "
               & Img (A.Lines)
               & "   "
               & Img (A.Code)
               & "   "
               & Img (A.Comments)
               & "   "
               & Img (A.Blanks));
         end;
      end loop;
      Ada.Text_IO.New_Line;

      --  Per-file tokei-style detail: language, total/code/comment/blank
      --  line counts, then the complexity gate columns.
      Ada.Text_IO.Put_Line
        ("Per-file (Lines / Code / Comments / Blanks / loc % / cx):");
      for I in 1 .. Integer (Result.Files.Length) loop
         declare
            FM    : File_Metrics renames Result.Files (I);
            Pct   : Natural := 0;
            Start : Natural := 1;
            Lang  : constant String :=
              (if FM.Language_Len > 0
               then FM.Language (1 .. FM.Language_Len)
               else "Unknown");
         begin
            if Result.Total_LOC > 0 then
               Pct := (FM.LOC * 100) / Result.Total_LOC;
            end if;
            MLen := 0;
            for S of FM.Subs loop
               if S.Complexity > Max_Fn_Complexity then
                  Marker (1 .. 26) := "  <-- function too complex";
                  MLen := 26;
                  exit;
               end if;
            end loop;
            if FM.LOC > Max_File_LOC then
               Marker (1 .. 14) := "  <-- too long";
               MLen := 14;
            end if;
            if Pct > Max_File_Pct then
               Marker (1 .. 14) := "  <-- dominant";
               MLen := 14;
            end if;
            if FM.Complexity > Max_File_Complexity then
               Marker (1 .. 16) := "  <-- god object";
               MLen := 16;
            end if;
            if FM.Path_Len > 60 then
               Start := FM.Path_Len - 59;
            end if;
            Ada.Text_IO.Put (FM.Path (Start .. FM.Path_Len));
            Ada.Text_IO.Put ("  [");
            Ada.Text_IO.Put (Lang);
            Ada.Text_IO.Put ("]  Lines=");
            Ada.Text_IO.Put (Img (FM.Total_Lines));
            Ada.Text_IO.Put ("  Code=");
            Ada.Text_IO.Put (Img (FM.Code_Lines));
            Ada.Text_IO.Put ("  Comments=");
            Ada.Text_IO.Put (Img (FM.Comment_Lines));
            Ada.Text_IO.Put ("  Blanks=");
            Ada.Text_IO.Put (Img (FM.Blank_Lines));
            Ada.Text_IO.Put ("  loc=");
            Ada.Text_IO.Put (Img (FM.LOC));
            Ada.Text_IO.Put (" (");
            Ada.Text_IO.Put (Img (Pct));
            Ada.Text_IO.Put ("%) cx=");
            Ada.Text_IO.Put (Img (FM.Complexity));
            if MLen > 0 then
               Ada.Text_IO.Put (Marker (1 .. MLen));
            end if;
            Ada.Text_IO.New_Line;
         end;
      end loop;
      Ada.Text_IO.New_Line;
      Ada.Text_IO.Put_Line
        ("total LOC (src): " & Trim (Natural'Image (Result.Total_LOC)));
      Ada.Text_IO.Put_Line
        ("files analyzed: "
         & Trim (Natural'Image (Integer (Result.Files.Length))));
      Ada.Text_IO.New_Line;
      if Check_Mode then
         if Integer (Violations.Length) > 0 then
            Ada.Text_IO.Put_Line
              (Adacovex.Ansi.Red
                 ("  Complexity/LOC gate FAILED ("
                  & Trim (Natural'Image (Integer (Violations.Length)))
                  & " violation(s))"));
            for I in 1 .. Integer (Violations.Length) loop
               Ada.Text_IO.Put_Line
                 ("  - "
                  & Violations (I).File_Path (1 .. Violations (I).File_Len)
                  & Violations (I).Message (1 .. Violations (I).Msg_Len));
            end loop;
         else
            Ada.Text_IO.Put_Line
              (Adacovex.Ansi.Green ("  Complexity/LOC gate passed."));
         end if;
      end if;
   end Print_Report;

end Adacovex.Complexity;
