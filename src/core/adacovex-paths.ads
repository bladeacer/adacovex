--  Platform-agnostic path helpers.
--  POSIX uses '/' as the only path separator. Windows also accepts '\' and
--  marks an absolute path with a drive letter ("C:\project"), a UNC share
--  ("\\server\\share"), or a root separator. This package centralises every
--  such decision so the rest of the tree never spells a platform assumption
--  inline and a Windows build never mistakes "C:\x" for a relative path.
--
--  It also owns the platform directory conventions. A user's configuration,
--  cache, and data do not live in one place on every host: Linux and the
--  BSDs follow the XDG base directory specification ($XDG_CONFIG_HOME,
--  $XDG_CACHE_HOME, $XDG_DATA_HOME, each with a home-directory default),
--  macOS uses ~/Library/Application Support and ~/Library/Caches, and
--  Windows uses %APPDATA% and %LOCALAPPDATA%. The package answers all three
--  from one place, so no other unit hard-codes "~/.adacovex".
--
--  The helpers use only the GNAT runtime, so the crate keeps no dependency.
--
--  SPARK split: the declarations are SPARK-visible (the package spec is
--  SPARK_Mode On), so a caller may use the path predicates and the contracts
--  in proved code. The body is a default-off I/O unit, because it reads the
--  environment and probes the filesystem, and because a concatenation of two
--  unbounded strings is not provable without bounding every component. That
--  is the same allowance AGENTS.md gives an I/O-heavy body; the package
--  carries no explicit `pragma SPARK_Mode (Off)`, so `make spark-off-check`
--  stays green.

package Adacovex.Paths is
   pragma SPARK_Mode (On);

   --  The host platform family, as far as directory conventions go. Linux
   --  stands for every POSIX host that follows the XDG base directory
   --  specification (Linux, the BSDs, and other Unix systems).
   type Platform_Kind is (Platform_Linux, Platform_MacOS, Platform_Windows);

   --  Detect the host platform at run time. Windows is recognised by the
   --  directory-separator convention (the one compile-time fact that
   --  distinguishes it), macOS by the existence of
   --  /System/Library/CoreServices (a macOS-only directory), and everything
   --  else is treated as XDG.
   --  @return The host platform family.
   function Detect_Platform return Platform_Kind
   with Global => null;

   --  The adacovex configuration directory for a platform: where
   --  adacovex.toml lives. Every input is a parameter, so the tests
   --  exercise all three platform rules on any host.
   --  @param P           Platform family.
   --  @param Home        User home directory.
   --  @param Xdg_Config  $XDG_CONFIG_HOME ("" when unset).
   --  @param App_Data    %APPDATA% ("" when unset).
   --  @return The configuration directory.
   function Config_Directory
     (P          : Platform_Kind;
      Home       : String;
      Xdg_Config : String;
      App_Data   : String) return String
   with Global => null;

   --  The adacovex cache directory for a platform: the result cache, the
   --  persistent stat-stamp store, and the system-tool probe store.
   --  @param P               Platform family.
   --  @param Home            User home directory.
   --  @param Xdg_Cache       $XDG_CACHE_HOME ("" when unset).
   --  @param Local_App_Data  %LOCALAPPDATA% ("" when unset).
   --  @return The cache directory.
   function Cache_Directory
     (P              : Platform_Kind;
      Home           : String;
      Xdg_Cache      : String;
      Local_App_Data : String) return String
   with Global => null;

   --  The adacovex data directory for a platform: the toolchain cache and
   --  the machine-local registry-metadata store.
   --  @param P               Platform family.
   --  @param Home            User home directory.
   --  @param Xdg_Data        $XDG_DATA_HOME ("" when unset).
   --  @param Local_App_Data  %LOCALAPPDATA% ("" when unset).
   --  @return The data directory.
   function Data_Directory
     (P              : Platform_Kind;
      Home           : String;
      Xdg_Data       : String;
      Local_App_Data : String) return String
   with Global => null;

   --  The configuration directory for the host, read from the environment:
   --  $ADACOVEX_STATE_HOME when it is set (the documented override for tests
   --  and CI; it is distinct from the installer's ADACOVEX_HOME, which names
   --  a binary prefix), otherwise Config_Directory for the detected
   --  platform.
   --  @return The configuration directory in use.
   function Config_Root return String;

   --  The cache directory for the host, read from the environment:
   --  $ADACOVEX_STATE_HOME/cache when it is set, otherwise Cache_Directory
   --  for the detected platform.
   --  @return The cache directory in use.
   function Cache_Root return String;

   --  The data directory for the host, read from the environment:
   --  $ADACOVEX_STATE_HOME/data when it is set, otherwise Data_Directory for
   --  the detected platform.
   --  @return The data directory in use.
   function Data_Root return String;

   --  The host executable suffix, ".exe" on Windows and "" elsewhere.
   --  Ada.Directories never guesses an extension, so a unit that tests or
   --  spawns a binary by name must append this suffix itself.
   --  @return The host executable suffix.
   function Executable_Suffix return String;

   --  Name with the host executable suffix appended when it is missing
   --  ("gnatprove" becomes "gnatprove.exe" on Windows, and is unchanged on
   --  POSIX). A name that already carries the suffix is returned unchanged.
   --  @param Name  Executable name or path.
   --  @return Name with the host executable suffix.
   function Executable_Name (Name : String) return String
   with Global => null;

   --  Whether C separates path components on any supported host. Both '/'
   --  (POSIX and Windows) and '\' (Windows only) are separators.
   --  @param C  Candidate character.
   --  @return True when C is a path separator.
   --  @post Result is True exactly when C is '/' or '\'.
   function Is_Separator (C : Character) return Boolean
   with
     Post   => Is_Separator'Result = (C = '/' or else C = '\'),
     Global => null;

   --  Whether Path is absolute. True for a leading '/' or '\' (a POSIX root
   --  or a Windows root-relative path), a Windows drive-letter prefix such
   --  as "C:" or "C:\", and a Windows UNC prefix ("\\server" or
   --  "//server"). False for an empty path and for any other relative path.
   --  @param Path  Candidate path.
   --  @return True when Path is absolute.
   function Is_Absolute (Path : String) return Boolean
   with Global => null;

   --  Home directory of the current user. It reads HOME first (POSIX and
   --  most Windows shells), then USERPROFILE (the native Windows variable a
   --  bare cmd.exe sets), and falls back to the system temp directory. The
   --  runtime Ada.Environment_Variables subprograms carry no Global
   --  contracts, so gnatprove 16 emits [assumed-global-null] warnings at
   --  each call; the body scopes a Warnings pragma over exactly those
   --  calls (the Adacovex.CPUs idiom).
   --  @return The user's home directory (the temp directory as a last
   --          resort).
   function Home_Directory return String
   with SPARK_Mode => On, Global => null;

   --  Expand a leading '~' to Home_Directory. The accepted forms are "~"
   --  and "~/rest" (also "~\rest" on Windows); a "~user" form is returned
   --  unchanged, because only the shell can resolve another user's home.
   --  A tilde not in leading position is returned unchanged. Home_Directory
   --  already falls back to the temp directory, so the result is always
   --  usable instead of a literal "~".
   --  @param Path  Candidate path.
   --  @return Path with a leading '~' expanded.
   function Expand_User (Path : String) return String
   with Global => null;

   --  Join Dir and Name with exactly one separator between them. Dir's
   --  trailing separators are trimmed first, so "/a/" and "/a" both join to
   --  "/a/Name". Returns Name when Dir is empty and Dir when Name is empty.
   --  '/' is used as the joining separator, which Windows accepts as well.
   --  @param Dir   Directory part.
   --  @param Name  Entry name part.
   --  @return The joined path.
   function Join (Dir : String; Name : String) return String
   with
     Post   => (if Dir'Length = 0 then Join'Result = Name),
     Global => null;

   --  Strip every trailing path separator from Path. A lone root ("/" or
   --  "\") is kept intact, and an empty Path is returned unchanged.
   --  @param Path  Candidate path.
   --  @return Path without trailing separators.
   --  @post Result'Length <= Path'Length.
   function Strip_Trailing_Separators (Path : String) return String
   with
     Post   => Strip_Trailing_Separators'Result'Length <= Path'Length,
     Global => null;

end Adacovex.Paths;
