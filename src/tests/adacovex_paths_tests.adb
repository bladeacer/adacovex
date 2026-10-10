with GNAT.OS_Lib;
with Adacovex.Paths;

package body Adacovex_Paths_Tests is

   procedure Run (R : in out Adacovex.Test_Support.Runner'Class) is
      Home : constant String := Adacovex.Paths.Home_Directory;
   begin
      --  Separator recognition: both DOS and Unix separators, and nothing
      --  else.
      R.Check (Adacovex.Paths.Is_Separator ('/'), "slash is a separator");
      R.Check
        (Adacovex.Paths.Is_Separator ('\'), "backslash is a separator");
      R.Check
        (not Adacovex.Paths.Is_Separator (':'),
         "colon is not a path separator");

      --  Absolute detection across POSIX roots, Windows roots, and the
      --  relative forms that must never be treated as absolute.
      R.Check (Adacovex.Paths.Is_Absolute ("/x"), "/x is absolute");
      R.Check (Adacovex.Paths.Is_Absolute ("\x"), "\x is absolute");
      R.Check (Adacovex.Paths.Is_Absolute ("C:\x"), "C:\x is absolute");
      R.Check (Adacovex.Paths.Is_Absolute ("c:/x"), "c:/x is absolute");
      R.Check
        (not Adacovex.Paths.Is_Absolute ("x/y"), "x/y is relative");
      R.Check
        (not Adacovex.Paths.Is_Absolute (""), "the empty path is relative");
      R.Check (not Adacovex.Paths.Is_Absolute ("~"), "~ is relative");

      --  Join inserts exactly one '/' and trims the directory's trailing
      --  separators first.
      R.Check
        (Adacovex.Paths.Join ("/a", "b") = "/a/b", "join /a + b is /a/b");
      R.Check
        (Adacovex.Paths.Join ("/a/", "b") = "/a/b", "join trims one /");
      R.Check
        (Adacovex.Paths.Join ("", "b") = "b", "join of an empty dir is name");
      R.Check
        (Adacovex.Paths.Join ("/a", "") = "/a", "join of an empty name is dir");
      R.Check
        (Adacovex.Paths.Join ("C:\x", "y") = "C:\x/y",
         "join of a drive path adds a /");
      R.Check
        (Adacovex.Paths.Join ("/a//", "b") = "/a/b",
         "join trims every trailing separator");

      --  Trailing-separator stripping, including the lone-root case.
      R.Check
        (Adacovex.Paths.Strip_Trailing_Separators ("/a/") = "/a",
         "strip removes one trailing slash");
      R.Check
        (Adacovex.Paths.Strip_Trailing_Separators ("/a//") = "/a",
         "strip removes every trailing slash");
      R.Check
        (Adacovex.Paths.Strip_Trailing_Separators ("/") = "/",
         "strip keeps a lone root");
      R.Check
        (Adacovex.Paths.Strip_Trailing_Separators ("") = "",
         "strip keeps the empty path");

      --  Tilde expansion against the live home directory.
      R.Check
        (Adacovex.Paths.Expand_User ("~") = Home,
         "~ expands to the home directory");
      R.Check
        (Adacovex.Paths.Expand_User ("~/x") = Home & "/x",
         "~/x expands under the home directory");
      R.Check
        (Adacovex.Paths.Expand_User ("~other/x") = "~other/x",
         "~other is left untouched");
      R.Check
        (Adacovex.Paths.Expand_User ("/abs") = "/abs",
         "a non-tilde path is unchanged");
      R.Check
        (Adacovex.Paths.Expand_User ("~\x") = Home & "/x",
         "the Windows ~\x form expands too");
      --  Platform directory conventions. Every rule is a pure function of
      --  its arguments, so all three platforms are checked on any host.
      declare
         use Adacovex.Paths;
      begin
         --  Linux and the BSDs follow the XDG base directory
         --  specification, with the home-directory default per variable.
         R.Check
           (Config_Directory
              (Platform_Linux, "/home/u", "/xdg/cfg", "/app/data")
            = "/xdg/cfg/adacovex",
            "config: XDG_CONFIG_HOME wins on Linux");
         R.Check
           (Config_Directory (Platform_Linux, "/home/u", "", "")
            = "/home/u/.config/adacovex",
            "config: ~/.config is the Linux default");
         R.Check
           (Cache_Directory (Platform_Linux, "/home/u", "", "")
            = "/home/u/.cache/adacovex",
            "cache: ~/.cache is the Linux default");
         R.Check
           (Data_Directory (Platform_Linux, "/home/u", "", "")
            = "/home/u/.local/share/adacovex",
            "data: ~/.local/share is the Linux default");

         --  macOS uses ~/Library: Application Support for configuration and
         --  data, Caches for the cache.
         R.Check
           (Config_Directory (Platform_MacOS, "/Users/u", "", "")
            = "/Users/u/Library/Application Support/adacovex",
            "config: macOS uses Application Support");
         R.Check
           (Cache_Directory (Platform_MacOS, "/Users/u", "", "")
            = "/Users/u/Library/Caches/adacovex",
            "cache: macOS uses ~/Library/Caches");
         R.Check
           (Data_Directory (Platform_MacOS, "/Users/u", "", "")
            = "/Users/u/Library/Application Support/adacovex",
            "data: macOS shares Application Support");

         --  Windows uses the roaming profile for configuration and the
         --  local profile for cache and data, each with its own subfolder.
         R.Check
           (Config_Directory
              (Platform_Windows, "C:\\Users\\u", "",
               "C:\\Users\\u\\AppData\\Roaming")
            = "C:\\Users\\u\\AppData\\Roaming/adacovex",
            "config: Windows uses %APPDATA%");
         R.Check
           (Cache_Directory
              (Platform_Windows, "C:\\Users\\u", "",
               "C:\\Users\\u\\AppData\\Local")
            = "C:\\Users\\u\\AppData\\Local/adacovex/cache",
            "cache: Windows uses the local profile");
         R.Check
           (Data_Directory
              (Platform_Windows, "C:\\Users\\u", "",
               "C:\\Users\\u\\AppData\\Local")
            = "C:\\Users\\u\\AppData\\Local/adacovex/data",
            "data: Windows uses the local profile");
         --  A stripped Windows environment (no %APPDATA%) falls back to
         --  the per-user dot directory instead of failing.
         R.Check
           (Config_Directory (Platform_Windows, "C:\\Users\\u", "", "")
            = "C:\\Users\\u/.adacovex",
            "config: Windows falls back to ~/.adacovex without %APPDATA%");
         R.Check
           (Cache_Directory (Platform_Windows, "C:\\Users\\u", "", "")
            = "C:\\Users\\u/.adacovex/cache",
            "cache: Windows falls back to ~/.adacovex/cache");

         --  Display is presentation only: the empty path and a plain
         --  path come back unchanged, on every host.
         R.Check (Display ("") = "", "display keeps the empty path");
         R.Check (Display ("a/b") = "a/b", "display keeps a plain path");

         --  The detected platform matches the host separator convention.
         if GNAT.OS_Lib.Directory_Separator = '\' then
            R.Check
              (Detect_Platform = Platform_Windows,
               "detect: a backslash separator host is Windows");
            R.Check
              (Executable_Suffix = ".exe",
               "executable suffix is .exe on Windows");
            R.Check
              (Executable_Name ("gnatprove") = "gnatprove.exe",
               "executable name gains the .exe suffix");
            R.Check
              (Executable_Name ("gnatprove.exe") = "gnatprove.exe",
               "executable name keeps an existing suffix");
            R.Check
              (Display ("C:\a\b") = "C:/a/b",
               "display converts backslashes on Windows");
         else
            R.Check
              (Detect_Platform /= Platform_Windows,
               "detect: a slash separator host is not Windows");
            R.Check
              (Executable_Suffix = "",
               "executable suffix is empty on POSIX");
            R.Check
              (Executable_Name ("gnatprove") = "gnatprove",
               "executable name is unchanged on POSIX");
            R.Check
              (Display ("C:\a\b") = "C:\a\b",
               "display keeps backslashes on POSIX");
         end if;
      end;
   end Run;

end Adacovex_Paths_Tests;
