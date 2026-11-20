with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Unbounded;
with GNAT.OS_Lib;
with Adacovex.CPUs;

package body Adacovex.Paths is

   --  The directory name adacovex owns under every platform base directory.
   App_Dir_Name : constant String := "adacovex";

   --  Whether C separates path components. The two characters are the only
   --  separators any supported host uses, so the result is characterised
   --  directly by the comparison.
   function Is_Separator (C : Character) return Boolean is
   begin
      return C = '/' or else C = '\';
   end Is_Separator;

   --  Whether Path is absolute: a leading separator, a Windows drive-letter
   --  prefix, or a UNC root. Everything else is relative.
   function Is_Absolute (Path : String) return Boolean is
   begin
      if Path'Length = 0 then
         return False;
      end if;
      if Is_Separator (Path (Path'First)) then
         return True;
      end if;
      if Path'Length >= 2
        and then Path (Path'First) in 'A' .. 'Z' | 'a' .. 'z'
        and then Path (Path'First + 1) = ':'
      then
         return True;
      end if;
      return False;
   end Is_Absolute;

   pragma Warnings (Off, "no Global contract available");
   function Home_Directory return String is
      use Ada.Environment_Variables;
   begin
      if Exists ("HOME") and then Value ("HOME")'Length > 0 then
         return Value ("HOME");
      end if;
      if Exists ("USERPROFILE") and then Value ("USERPROFILE")'Length > 0 then
         return Value ("USERPROFILE");
      end if;
      return Adacovex.CPUs.Get_Temp_Directory;
   end Home_Directory;
   pragma Warnings (On, "no Global contract available");

   --  Resolve Path to one absolute, normalised spelling. The body is part
   --  of this default-off I/O unit (it reads the working directory), so the
   --  algorithm below is plain Ada: normalise separators, keep a root
   --  prefix, then fold '.', '..', and empty segments while rebuilding.
   --  @param Path  Path to resolve.
   --  @return The resolved path, or "" when Path is empty.
   function Resolve (Path : String) return String is
      use Ada.Strings.Unbounded;
      Fold_Case : constant Boolean := GNAT.OS_Lib.Directory_Separator = '\';
      Expanded  : constant String := Expand_User (Path);
      Full      : Unbounded_String;
      Norm      : Unbounded_String;
      Out_Buf   : Unbounded_String;
      Root      : Unbounded_String;
      Start     : Natural;
      Fin       : Natural;

      --  Working directory of this process, or "" when it cannot be read.
      function Working_Dir return String is
      begin
         return Ada.Directories.Current_Directory;
      exception
         when others =>
            return "";
      end Working_Dir;

      --  Drop the last segment from Out_Buf (the '..' case). A bare root is
      --  left intact: '/..' stays '/', because a path cannot climb above
      --  the file-system root.
      procedure Pop_Segment is
         L : Natural := Length (Out_Buf);
      begin
         while L > 0 and then Element (Out_Buf, L) /= '/' loop
            L := L - 1;
         end loop;
         if L = 0 then
            Out_Buf := Null_Unbounded_String;
         else
            Out_Buf := To_Unbounded_String (Slice (Out_Buf, 1, L - 1));
         end if;
      end Pop_Segment;
   begin
      if Path'Length = 0 then
         return "";
      end if;

      if Is_Absolute (Expanded) then
         Full := To_Unbounded_String (Expanded);
      else
         declare
            Cw : constant String := Working_Dir;
         begin
            if Cw'Length = 0 then
               Full := To_Unbounded_String (Expanded);
            elsif Is_Separator (Cw (Cw'Last)) then
               Full := To_Unbounded_String (Cw & Expanded);
            else
               Full := To_Unbounded_String (Cw & "/" & Expanded);
            end if;
         end;
      end if;

      --  One separator spelling, and the Windows case fold. The file system
      --  is case-insensitive there, so folding the key never changes which
      --  directory the resolved path names.
      for I in 1 .. Length (Full) loop
         declare
            C : Character := Element (Full, I);
         begin
            if Is_Separator (C) then
               C := '/';
            elsif Fold_Case then
               C := Ada.Characters.Handling.To_Lower (C);
            end if;
            Append (Norm, (1 => C));
         end;
      end loop;

      --  Keep the root: a Windows drive prefix ("c:"), or a leading '/'.
      Start := 1;
      if Length (Norm) >= 2 and then Element (Norm, 2) = ':' then
         Append (Root, (1 => Element (Norm, 1)));
         Append (Root, ":");
         Start := 3;
      end if;
      if Start <= Length (Norm) and then Element (Norm, Start) = '/' then
         Append (Root, "/");
         Start := Start + 1;
      end if;

      while Start <= Length (Norm) loop
         while Start <= Length (Norm) and then Element (Norm, Start) = '/' loop
            Start := Start + 1;
         end loop;
         exit when Start > Length (Norm);
         Fin := Start;
         while Fin <= Length (Norm) and then Element (Norm, Fin) /= '/' loop
            Fin := Fin + 1;
         end loop;
         declare
            Seg : constant String := Slice (Norm, Start, Fin - 1);
         begin
            if Seg = ".." then
               Pop_Segment;
            elsif Seg /= "." and then Seg'Length > 0 then
               if Length (Out_Buf) > 0 then
                  Append (Out_Buf, "/");
               end if;
               Append (Out_Buf, Seg);
            end if;
         end;
         Start := Fin;
      end loop;

      if Length (Root) = 0 then
         return To_String (Out_Buf);
      end if;
      if Length (Out_Buf) = 0 then
         return To_String (Root);
      end if;
      if Element (Root, Length (Root)) = '/' then
         return To_String (Root & Out_Buf);
      end if;
      return To_String (Root & "/" & Out_Buf);
   end Resolve;

   function Expand_User (Path : String) return String is
      Home : constant String := Home_Directory;
      --  The slice after "~" plus a separator. A null slice (Path = "~/"
      --  or "~") yields the empty string, so only the leading "~" needs a
      --  case of its own.
      Rest : constant String :=
        (if Path'Length >= 2 and then Is_Separator (Path (Path'First + 1))
         then Path (Path'First + 2 .. Path'Last)
         else "");
   begin
      if Path'Length = 0 then
         return Path;
      end if;
      if Path (Path'First) /= '~' then
         return Path;
      end if;
      if Path'Length >= 2 and then Path (Path'First + 1) not in '/' | '\' | ' '
      then
         --  "~name": another user's home, which only the shell resolves.
         return Path;
      end if;
      if Rest = "" then
         return Home;
      end if;
      if Home'Length > 0 and then Is_Separator (Home (Home'Last)) then
         return Home & Rest;
      end if;
      return Home & "/" & Rest;
   end Expand_User;

   --  Ada.Directories.Exists carries no Global contract, so gnatprove 16
   --  emits [assumed-global-null] at the call; the pragma scopes the
   --  suppression over exactly that one (the Adacovex.CPUs idiom).
   pragma Warnings (Off, "no Global contract available");
   function Detect_Platform return Platform_Kind is
   begin
      if GNAT.OS_Lib.Directory_Separator = '\' then
         return Platform_Windows;
      end if;
      if Ada.Directories.Exists ("/System/Library/CoreServices") then
         return Platform_MacOS;
      end if;
      return Platform_Linux;
   end Detect_Platform;
   pragma Warnings (On, "no Global contract available");

   --  A platform base directory with the adacovex directory appended. An
   --  empty base falls back to the home directory, so the result is always
   --  a usable path.
   function Under_ADir (Base : String; Home : String) return String is
      B : constant String := (if Base'Length > 0 then Base else Home);
   begin
      if B'Length = 0 then
         return "/.adacovex";
      end if;
      if Is_Separator (B (B'Last)) then
         return B & App_Dir_Name;
      end if;
      return B & "/" & App_Dir_Name;
   end Under_ADir;

   --  The Windows fallback when %APPDATA% or %LOCALAPPDATA% is unset: the
   --  classic per-user dot directory under the home directory. It keeps the
   --  pre-1.60 layout usable on a stripped environment, and the documented
   --  ADACOVEX_HOME override gives an explicit answer when even the home
   --  directory is unknown.
   function Dot_Fallback (Home : String) return String is
   begin
      if Home'Length = 0 then
         return "/.adacovex";
      end if;
      if Is_Separator (Home (Home'Last)) then
         return Home & ".adacovex";
      end if;
      return Home & "/.adacovex";
   end Dot_Fallback;

   function Config_Directory
     (P : Platform_Kind; Home : String; Xdg_Config : String; App_Data : String)
      return String is
   begin
      case P is
         when Platform_Linux   =>
            return Under_ADir (Xdg_Config, Home & "/.config");

         when Platform_MacOS   =>
            return Under_ADir (Home & "/Library/Application Support", "");

         when Platform_Windows =>
            if App_Data'Length > 0 then
               return Under_ADir (App_Data, "");
            end if;
            return Dot_Fallback (Home);
      end case;
   end Config_Directory;

   function Cache_Directory
     (P              : Platform_Kind;
      Home           : String;
      Xdg_Cache      : String;
      Local_App_Data : String) return String is
   begin
      case P is
         when Platform_Linux   =>
            return Under_ADir (Xdg_Cache, Home & "/.cache");

         when Platform_MacOS   =>
            return Under_ADir (Home & "/Library/Caches", "");

         when Platform_Windows =>
            if Local_App_Data'Length > 0 then
               return Under_ADir (Local_App_Data, "") & "/cache";
            end if;
            return Dot_Fallback (Home) & "/cache";
      end case;
   end Cache_Directory;

   function Data_Directory
     (P              : Platform_Kind;
      Home           : String;
      Xdg_Data       : String;
      Local_App_Data : String) return String is
   begin
      case P is
         when Platform_Linux   =>
            return Under_ADir (Xdg_Data, Home & "/.local/share");

         when Platform_MacOS   =>
            return Under_ADir (Home & "/Library/Application Support", "");

         when Platform_Windows =>
            if Local_App_Data'Length > 0 then
               return Under_ADir (Local_App_Data, "") & "/data";
            end if;
            return Dot_Fallback (Home) & "/data";
      end case;
   end Data_Directory;

   function Data_Base
     (P              : Platform_Kind;
      Home           : String;
      Xdg_Data       : String;
      App_Data       : String;
      Local_App_Data : String) return String is
   begin
      case P is
         when Platform_Linux   =>
            if Xdg_Data'Length > 0 then
               return Strip_Trailing_Separators (Xdg_Data);
            end if;
            return Strip_Trailing_Separators (Home & "/.local/share");

         when Platform_MacOS   =>
            return
              Strip_Trailing_Separators
                (Home & "/Library/Application Support");

         when Platform_Windows =>
            if App_Data'Length > 0 then
               return Strip_Trailing_Separators (App_Data);
            elsif Local_App_Data'Length > 0 then
               return Strip_Trailing_Separators (Local_App_Data);
            end if;
            return Strip_Trailing_Separators (Home & "/.local/share");
      end case;
   end Data_Base;

   function Cache_Base
     (P              : Platform_Kind;
      Home           : String;
      Xdg_Cache      : String;
      Local_App_Data : String) return String is
   begin
      case P is
         when Platform_Linux   =>
            if Xdg_Cache'Length > 0 then
               return Strip_Trailing_Separators (Xdg_Cache);
            end if;
            return Strip_Trailing_Separators (Home & "/.cache");

         when Platform_MacOS   =>
            return Strip_Trailing_Separators (Home & "/Library/Caches");

         when Platform_Windows =>
            if Local_App_Data'Length > 0 then
               return Strip_Trailing_Separators (Local_App_Data);
            end if;
            return Strip_Trailing_Separators (Home & "/.cache");
      end case;
   end Cache_Base;

   --  Value of an environment variable, "" when it is unset or empty. The
   --  runtime Ada.Environment_Variables subprograms carry no Global
   --  contracts, so gnatprove 16 emits [assumed-global-null] warnings at
   --  each call; the pragma below scopes the suppression over exactly those
   --  calls (the Adacovex.CPUs idiom).
   pragma Warnings (Off, "no Global contract available");
   function Env (Name : String) return String is
      use Ada.Environment_Variables;
   begin
      if Exists (Name) then
         return Value (Name);
      end if;
      return "";
   end Env;

   --  $ADACOVEX_STATE_HOME, the documented override for every platform
   --  convention. The test suite and CI use it to pin the state directories
   --  to one place. It is distinct from the installer's ADACOVEX_HOME, which
   --  names a binary prefix, so relocating the binary never moves the state.
   --  @return The override root, or "" when it is not set.
   function Home_Override return String is
   begin
      return Strip_Trailing_Separators (Env ("ADACOVEX_STATE_HOME"));
   end Home_Override;

   function Data_Home return String is
   begin
      return
        Data_Base
          (Detect_Platform,
           Home_Directory,
           Env ("XDG_DATA_HOME"),
           Env ("APPDATA"),
           Env ("LOCALAPPDATA"));
   end Data_Home;

   function Cache_Home return String is
   begin
      return
        Cache_Base
          (Detect_Platform,
           Home_Directory,
           Env ("XDG_CACHE_HOME"),
           Env ("LOCALAPPDATA"));
   end Cache_Home;

   function Config_Root return String is
      Override : constant String := Home_Override;
   begin
      if Override'Length > 0 then
         return Override;
      end if;
      return
        Config_Directory
          (Detect_Platform,
           Home_Directory,
           Env ("XDG_CONFIG_HOME"),
           Env ("APPDATA"));
   end Config_Root;

   function Cache_Root return String is
      Override : constant String := Home_Override;
   begin
      if Override'Length > 0 then
         return Override & "/cache";
      end if;
      return
        Cache_Directory
          (Detect_Platform,
           Home_Directory,
           Env ("XDG_CACHE_HOME"),
           Env ("LOCALAPPDATA"));
   end Cache_Root;

   function Data_Root return String is
      Override : constant String := Home_Override;
   begin
      if Override'Length > 0 then
         return Override & "/data";
      end if;
      return
        Data_Directory
          (Detect_Platform,
           Home_Directory,
           Env ("XDG_DATA_HOME"),
           Env ("LOCALAPPDATA"));
   end Data_Root;
   pragma Warnings (On, "no Global contract available");

   function Executable_Suffix return String is
   begin
      if GNAT.OS_Lib.Directory_Separator = '\' then
         return ".exe";
      end if;
      return "";
   end Executable_Suffix;

   function Executable_Name (Name : String) return String is
      Suffix : constant String := Executable_Suffix;
   begin
      if Suffix'Length = 0 or else Name'Length = 0 then
         return Name;
      end if;
      if Name'Length >= Suffix'Length
        and then Name (Name'Last - Suffix'Length + 1 .. Name'Last) = Suffix
      then
         return Name;
      end if;
      return Name & Suffix;
   end Executable_Name;

   function Join (Dir : String; Name : String) return String is
      Trimmed : constant String := Strip_Trailing_Separators (Dir);
   begin
      if Trimmed'Length = 0 then
         return Name;
      end if;
      if Name'Length = 0 then
         return Trimmed;
      end if;
      if Is_Separator (Trimmed (Trimmed'Last)) then
         return Trimmed & Name;
      end if;
      return Trimmed & "/" & Name;
   end Join;

   function Strip_Trailing_Separators (Path : String) return String is
      Last : Natural := Path'Last;
   begin
      if Path'Length = 0 then
         return Path;
      end if;
      while Last > Path'First and then Is_Separator (Path (Last)) loop
         pragma Loop_Invariant (Last in Path'First .. Path'Last);
         pragma Loop_Variant (Decreases => Last - Path'First);
         Last := Last - 1;
      end loop;
      return Path (Path'First .. Last);
   end Strip_Trailing_Separators;

   function Display (Path : String) return String is
      --  The working copy is bounded by the parameter, so the loop below
      --  rewrites each element in place and the length post holds for both
      --  return paths (the untouched parameter and the rewritten copy).
      Result : String (Path'First .. Path'Last) := Path;
   begin
      if GNAT.OS_Lib.Directory_Separator /= '\' then
         return Path;
      end if;
      for I in Result'Range loop
         if Result (I) = '\' then
            Result (I) := '/';
         end if;
      end loop;
      return Result;
   end Display;

end Adacovex.Paths;
