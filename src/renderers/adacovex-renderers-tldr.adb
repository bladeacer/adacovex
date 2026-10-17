with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with GNAT.OS_Lib;
with Adacovex.CPUs;
with Adacovex.Tldr_Template;

package body Adacovex.Renderers.Tldr is

   use Ada.Strings.Fixed;

   --  Longest captured client output the detection reads. `tldr
   --  --show-paths` prints five short lines, so this is generous.
   Max_Capture : constant := 4096;

   --  Longest page the read-back comparison handles. The bundled page is a
   --  short cheat sheet; a longer file is a foreign page and never matches.
   Max_Page_File : constant := 8192;

   --  Strip a trailing '/' off a directory path so concatenations stay
   --  clean. A bare root ("/") is kept.
   function Strip_Trailing_Slash (S : String) return String is
   begin
      if S'Length > 1 and then S (S'Last) = '/' then
         return S (S'First .. S'Last - 1);
      else
         return S;
      end if;
   end Strip_Trailing_Slash;

   --  Lowercase one character for a case-insensitive match.
   function Lower (C : Character) return Character is
   begin
      if C in 'A' .. 'Z' then
         return Character'Val (Character'Pos (C) + 32);
      else
         return C;
      end if;
   end Lower;

   --  True when Needle appears in Haystack, ignoring case.
   function Contains_CI (Haystack : String; Needle : String) return Boolean is
   begin
      if Needle'Length = 0 or else Haystack'Length < Needle'Length then
         return False;
      end if;
      for I in Haystack'First .. Haystack'Last - Needle'Length + 1 loop
         declare
            Match : Boolean := True;
         begin
            for J in Needle'Range loop
               if Lower (Haystack (I + J - Needle'First)) /= Lower (Needle (J))
               then
                  Match := False;
                  exit;
               end if;
            end loop;
            if Match then
               return True;
            end if;
         end;
      end loop;
      return False;
   end Contains_CI;

   --  Drop a trailing " (annotation)" that tealdeer adds after a path, for
   --  example " (OS convention)", " (from config)", or " (default)".
   function Strip_Annotation (S : String) return String is
      Cut : Natural := 0;
   begin
      if S'Length > 2 and then S (S'Last) = ')' then
         for I in S'First .. S'Last - 1 loop
            if S (I) = ' ' and then S (I + 1) = '(' then
               Cut := I;
            end if;
         end loop;
      end if;
      if Cut >= S'First then
         return Trim (S (S'First .. Cut - 1), Ada.Strings.Both);
      end if;
      return S;
   end Strip_Annotation;

   --  The value after `Key` on the first line that starts with it. Leading
   --  spaces are ignored, the value is trimmed, and a trailing '/' is
   --  removed. A trailing annotation is dropped first. Returns "" when no
   --  line names the key.
   function Value_After_Key (Text : String; Key : String) return String is
      --  Position of the first non-blank character of Line, or 0.
      function First_Non_Blank (Line : String) return Natural is
      begin
         for I in Line'Range loop
            if Line (I) /= ' ' and then Line (I) /= ASCII.HT then
               return I;
            end if;
         end loop;
         return 0;
      end First_Non_Blank;

      I : Natural := Text'First;
   begin
      while I <= Text'Last loop
         declare
            Line_End : Natural := I;
         begin
            while Line_End <= Text'Last and then Text (Line_End) /= ASCII.LF
            loop
               Line_End := Line_End + 1;
            end loop;
            declare
               Line  : constant String := Text (I .. Line_End - 1);
               First : constant Natural := First_Non_Blank (Line);
            begin
               if First > 0
                 and then Line_End - First >= Key'Length
                 and then Contains_CI
                            (Line (First .. First + Key'Length - 1), Key)
               then
                  declare
                     Rest : constant String :=
                       Trim
                         (Line (First + Key'Length .. Line'Last),
                          Ada.Strings.Both);
                  begin
                     return Strip_Trailing_Slash (Strip_Annotation (Rest));
                  end;
               end if;
            end;
            I := Line_End + 1;
         end;
      end loop;
      return "";
   end Value_After_Key;

   --  Read a whole text file into Buf. Ok is False when the file is
   --  missing, unreadable, or longer than Buf.
   procedure Read_File
     (Path : String; Buf : out String; Len : out Natural; Ok : out Boolean)
   is
      F : Ada.Text_IO.File_Type;
   begin
      Len := 0;
      Ok := False;
      begin
         Ada.Text_IO.Open (F, Ada.Text_IO.In_File, Path);
      exception
         when others =>
            return;
      end;
      begin
         while not Ada.Text_IO.End_Of_File (F) loop
            declare
               Line : constant String := Ada.Text_IO.Get_Line (F);
            begin
               for I in Line'Range loop
                  if Len >= Buf'Last then
                     Ada.Text_IO.Close (F);
                     return;
                  end if;
                  Len := Len + 1;
                  Buf (Len) := Line (I);
               end loop;
               if Len >= Buf'Last then
                  Ada.Text_IO.Close (F);
                  return;
               end if;
               Len := Len + 1;
               Buf (Len) := ASCII.LF;
            end;
         end loop;
         Ada.Text_IO.Close (F);
      exception
         when others =>
            if Ada.Text_IO.Is_Open (F) then
               Ada.Text_IO.Close (F);
            end if;
            Len := 0;
            return;
      end;
      Ok := True;
   end Read_File;

   --  Run Exe with one argument and capture its combined output. Ok is
   --  False when the binary cannot run, the run exits non-zero, or the
   --  output does not fit Buf.
   procedure Run_Capture
     (Exe : String;
      Arg : String;
      Buf : out String;
      Len : out Natural;
      Ok  : out Boolean)
   is
      Pid     : constant Integer :=
        GNAT.OS_Lib.Pid_To_Integer (GNAT.OS_Lib.Current_Process_Id);
      Pid_Img : constant String := Integer'Image (Pid);
      Tmp     : constant String :=
        Adacovex.CPUs.Get_Temp_Directory
        & "/adacovex-tldr-"
        & Pid_Img (2 .. Pid_Img'Last)
        & ".out";
      Spawned : Boolean;
      Code    : Integer;
   begin
      Len := 0;
      Ok := False;
      GNAT.OS_Lib.Spawn
        (Exe, (1 => new String'(Arg)), Tmp, Spawned, Code, Err_To_Out => True);
      Read_File (Tmp, Buf, Len, Ok);
      begin
         Ada.Directories.Delete_File (Tmp);
      exception
         when others =>
            null;
      end;
      if not Spawned or else Code /= 0 then
         Ok := False;
      end if;
   end Run_Capture;

   function Page return String is
   begin
      return Adacovex.Tldr_Template.Page;
   end Page;

   function Client_Name (Kind : Client_Kind) return String is
   begin
      case Kind is
         when No_Client          =>
            return "none";

         when Base_Client        =>
            return "base client";

         when Tealdeer           =>
            return "tealdeer";

         when Unsupported_Client =>
            return "unsupported client";
      end case;
   end Client_Name;

   function Classify (Version_Output : String) return Client_Kind is
   begin
      if Contains_CI (Version_Output, "tealdeer") then
         return Tealdeer;
      elsif Contains_CI (Version_Output, "tldr") then
         return Base_Client;
      else
         return Unsupported_Client;
      end if;
   end Classify;

   function Custom_Pages_Dir (Show_Paths_Output : String) return String is
   begin
      return Value_After_Key (Show_Paths_Output, "Custom pages dir:");
   end Custom_Pages_Dir;

   function Data_Home return String is
   begin
      if Ada.Environment_Variables.Exists ("XDG_DATA_HOME") then
         declare
            X : constant String :=
              Ada.Environment_Variables.Value ("XDG_DATA_HOME");
         begin
            if X'Length > 0 then
               return Strip_Trailing_Slash (X);
            end if;
         end;
      end if;
      if Ada.Environment_Variables.Exists ("HOME") then
         declare
            H : constant String := Ada.Environment_Variables.Value ("HOME");
         begin
            if H'Length > 0 then
               return Strip_Trailing_Slash (H) & "/.local/share";
            end if;
         end;
      end if;
      return Adacovex.CPUs.Get_Temp_Directory & "/adacovex-tldr-data";
   end Data_Home;

   function Cache_Home return String is
   begin
      if Ada.Environment_Variables.Exists ("XDG_CACHE_HOME") then
         declare
            X : constant String :=
              Ada.Environment_Variables.Value ("XDG_CACHE_HOME");
         begin
            if X'Length > 0 then
               return Strip_Trailing_Slash (X);
            end if;
         end;
      end if;
      if Ada.Environment_Variables.Exists ("HOME") then
         declare
            H : constant String := Ada.Environment_Variables.Value ("HOME");
         begin
            if H'Length > 0 then
               return Strip_Trailing_Slash (H) & "/.cache";
            end if;
         end;
      end if;
      return Adacovex.CPUs.Get_Temp_Directory & "/adacovex-tldr-cache";
   end Cache_Home;

   function Default_Pages_Dir
     (Kind : Client_Kind; Data_Home : String; Cache_Home : String)
      return String
   is
      Cache      : constant String := Strip_Trailing_Slash (Cache_Home);
      Cache_Root : constant String :=
        (if Ada.Directories.Exists (Cache & "/tldr-node-client/pages")
           and then not Ada.Directories.Exists (Cache & "/tldr/pages")
         then Cache & "/tldr-node-client"
         else Cache & "/tldr");
   begin
      case Kind is
         when Tealdeer    =>
            return Strip_Trailing_Slash (Data_Home) & "/tealdeer/pages";

         when Base_Client =>
            return Cache_Root & "/pages";

         when others      =>
            return "";
      end case;
   end Default_Pages_Dir;

   function Page_File (Kind : Client_Kind; Pages_Dir : String) return String is
      Dir : constant String := Strip_Trailing_Slash (Pages_Dir);
   begin
      case Kind is
         when Tealdeer    =>
            return Dir & "/adacovex.page.md";

         when Base_Client =>
            return Dir & "/common/adacovex.md";

         when others      =>
            return "";
      end case;
   end Page_File;

   function Platform_From_System (System_Name : String) return String is
      Name : constant String := Trim (System_Name, Ada.Strings.Both);
      Tail : Natural := Name'First;
   begin
      --  `uname -s` prints a single word on every supported system; cut at
      --  the first space so an unusual suffix never blocks the match.
      while Tail <= Name'Last and then Name (Tail) /= ' ' loop
         Tail := Tail + 1;
      end loop;
      declare
         First_Word : constant String := Name (Name'First .. Tail - 1);
      begin
         if First_Word'Length = 0 then
            return "";
         elsif Contains_CI (First_Word, "linux") then
            return "linux";
         elsif Contains_CI (First_Word, "darwin") then
            return "osx";
         elsif Contains_CI (First_Word, "freebsd") then
            return "freebsd";
         elsif Contains_CI (First_Word, "netbsd") then
            return "netbsd";
         elsif Contains_CI (First_Word, "openbsd") then
            return "openbsd";
         elsif Contains_CI (First_Word, "sunos") then
            return "sunos";
         elsif Contains_CI (First_Word, "android") then
            return "android";
         elsif Contains_CI (First_Word, "mingw")
           or else Contains_CI (First_Word, "msys")
           or else Contains_CI (First_Word, "cygwin")
           or else Contains_CI (First_Word, "windows")
         then
            return "windows";
         else
            return "";
         end if;
      end;
   end Platform_From_System;

   function Platform_Page_Dir return String is
      use GNAT.OS_Lib;
      Buf : String (1 .. Max_Capture) := (others => ' ');
      Len : Natural := 0;
      Ok  : Boolean := False;
      Exe : GNAT.OS_Lib.String_Access :=
        GNAT.OS_Lib.Locate_Exec_On_Path ("uname");
   begin
      if Exe = null then
         return "";
      end if;
      Run_Capture (Exe.all, "-s", Buf, Len, Ok);
      Free (Exe);
      if not Ok then
         return "";
      end if;
      return Platform_From_System (Buf (1 .. Len));
   end Platform_Page_Dir;

   procedure Detect
     (Kind : out Client_Kind; Pages_Dir : out String; Pages_Len : out Natural)
   is
      use GNAT.OS_Lib;
      Buf : String (1 .. Max_Capture) := (others => ' ');
      Len : Natural := 0;
      Ok  : Boolean := False;
      Exe : GNAT.OS_Lib.String_Access :=
        GNAT.OS_Lib.Locate_Exec_On_Path ("tldr");

      --  Copy Dir into the caller's buffer, or report a path the
      --  installer cannot use as unsupported.
      procedure Set_Dir (Dir : String) is
      begin
         if Dir'Length = 0 or else Dir'Length > Pages_Dir'Length then
            Kind := Unsupported_Client;
            Pages_Len := 0;
            return;
         end if;
         Pages_Len := Dir'Length;
         Pages_Dir (Pages_Dir'First .. Pages_Dir'First + Dir'Length - 1) :=
           Dir;
      end Set_Dir;
   begin
      Kind := No_Client;
      Pages_Len := 0;
      if Exe = null then
         return;
      end if;

      --  tealdeer answers --show-paths with its real directories, which is
      --  authoritative. A base client does not support the option; its
      --  non-zero exit leaves Ok False and falls through to --version.
      Run_Capture (Exe.all, "--show-paths", Buf, Len, Ok);
      if Ok then
         declare
            Dir : constant String := Custom_Pages_Dir (Buf (1 .. Len));
         begin
            if Dir'Length > 0 then
               Kind := Tealdeer;
               Set_Dir (Dir);
               Free (Exe);
               return;
            end if;
         end;
      end if;

      Run_Capture (Exe.all, "--version", Buf, Len, Ok);
      Free (Exe);
      if not Ok then
         Kind := Unsupported_Client;
         return;
      end if;
      Kind := Classify (Buf (1 .. Len));
      case Kind is
         when Tealdeer    =>
            Set_Dir (Default_Pages_Dir (Tealdeer, Data_Home, Cache_Home));

         when Base_Client =>
            Set_Dir (Default_Pages_Dir (Base_Client, Data_Home, Cache_Home));

         when others      =>
            null;
      end case;
   end Detect;

   --  Write the bundled page to Path. Parent directories are created. The
   --  write uses a stream, not Ada.Text_IO: text output completes the last
   --  line at close, which would add a byte to a page that already ends
   --  with a newline and make the installed page differ from the bundled
   --  one.
   procedure Write_Page (Path : String; Success : out Boolean) is
      use Ada.Streams.Stream_IO;
      F   : File_Type;
      --  Length of the parent directory prefix (0 when there is none).
      Cut : Natural := Path'First - 1;
   begin
      Success := False;
      for I in Path'Range loop
         if Path (I) = '/' then
            Cut := I;
         end if;
      end loop;
      if Cut >= Path'First then
         begin
            Ada.Directories.Create_Path (Path (Path'First .. Cut - 1));
         exception
            when others =>
               return;
         end;
      end if;
      begin
         Create (F, Out_File, Path);
         String'Write (Stream (F), Page);
         Close (F);
      exception
         when others =>
            if Is_Open (F) then
               Close (F);
            end if;
            return;
      end;
      Success := True;
   end Write_Page;

   procedure Install
     (Kind : Client_Kind; Pages_Dir : String; Success : out Boolean)
   is
      Primary : constant String := Page_File (Kind, Pages_Dir);
   begin
      Success := False;
      if Primary'Length = 0 then
         return;
      end if;
      Write_Page (Primary, Success);
      if not Success then
         return;
      end if;
      --  A base client also reads the platform directory. Keep both copies
      --  identical so a platform page never shadows a stale common one.
      if Kind = Base_Client then
         declare
            Platform : constant String := Platform_Page_Dir;
         begin
            if Platform'Length > 0 then
               Write_Page
                 (Strip_Trailing_Slash (Pages_Dir)
                  & "/"
                  & Platform
                  & "/adacovex.md",
                  Success);
            end if;
         end;
      end if;
   end Install;

   function Installed (Kind : Client_Kind; Pages_Dir : String) return Boolean
   is
      Path : constant String := Page_File (Kind, Pages_Dir);
      Want : constant String := Page;
      F    : Ada.Streams.Stream_IO.File_Type;
   begin
      if Path'Length = 0
        or else Want'Length = 0
        or else Want'Length > Max_Page_File
      then
         return False;
      end if;
      begin
         Ada.Streams.Stream_IO.Open (F, Ada.Streams.Stream_IO.In_File, Path);
      exception
         when others =>
            return False;
      end;
      --  Compare the exact byte count first, so a foreign page is rejected
      --  before any buffer is allocated for it.
      if Natural (Ada.Streams.Stream_IO.Size (F)) /= Want'Length then
         Ada.Streams.Stream_IO.Close (F);
         return False;
      end if;
      declare
         Data :
           Ada.Streams.Stream_Element_Array
             (1 .. Ada.Streams.Stream_Element_Offset (Want'Length));
         Last : Ada.Streams.Stream_Element_Offset;
         Same : Boolean := True;
      begin
         Ada.Streams.Stream_IO.Read (F, Data, Last);
         Ada.Streams.Stream_IO.Close (F);
         if Natural (Last) /= Want'Length then
            return False;
         end if;
         for I in Data'Range loop
            if Character'Val (Data (I)) /= Want (Want'First + Natural (I) - 1)
            then
               Same := False;
               exit;
            end if;
         end loop;
         return Same;
      end;
   end Installed;

end Adacovex.Renderers.Tldr;
