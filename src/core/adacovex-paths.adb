with Ada.Directories;
with Ada.Environment_Variables;
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
      if Path'Length >= 2
        and then Path (Path'First + 1) not in '/' | '\' | ' '
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
     (P          : Platform_Kind;
      Home       : String;
      Xdg_Config : String;
      App_Data   : String) return String
   is
   begin
      case P is
         when Platform_Linux =>
            return Under_ADir (Xdg_Config, Home & "/.config");
         when Platform_MacOS =>
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
      Local_App_Data : String) return String
   is
   begin
      case P is
         when Platform_Linux =>
            return Under_ADir (Xdg_Cache, Home & "/.cache");
         when Platform_MacOS =>
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
      Local_App_Data : String) return String
   is
   begin
      case P is
         when Platform_Linux =>
            return Under_ADir (Xdg_Data, Home & "/.local/share");
         when Platform_MacOS =>
            return Under_ADir (Home & "/Library/Application Support", "");
         when Platform_Windows =>
            if Local_App_Data'Length > 0 then
               return Under_ADir (Local_App_Data, "") & "/data";
            end if;
            return Dot_Fallback (Home) & "/data";
      end case;
   end Data_Directory;

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

   function Config_Root return String is
      Override : constant String := Home_Override;
   begin
      if Override'Length > 0 then
         return Override;
      end if;
      return Config_Directory
               (Detect_Platform, Home_Directory, Env ("XDG_CONFIG_HOME"),
                Env ("APPDATA"));
   end Config_Root;

   function Cache_Root return String is
      Override : constant String := Home_Override;
   begin
      if Override'Length > 0 then
         return Override & "/cache";
      end if;
      return Cache_Directory
               (Detect_Platform, Home_Directory, Env ("XDG_CACHE_HOME"),
                Env ("LOCALAPPDATA"));
   end Cache_Root;

   function Data_Root return String is
      Override : constant String := Home_Override;
   begin
      if Override'Length > 0 then
         return Override & "/data";
      end if;
      return Data_Directory
               (Detect_Platform, Home_Directory, Env ("XDG_DATA_HOME"),
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

end Adacovex.Paths;
