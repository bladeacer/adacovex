--  Platform-agnostic path helpers.
--  POSIX uses '/' as the only path separator. Windows also accepts '\' and
--  marks an absolute path with a drive letter ("C:\project"), a UNC share
--  ("\\server\share"), or a root separator. This package centralises every
--  such decision so the rest of the tree never spells a platform assumption
--  inline and a Windows build never mistakes "C:\x" for a relative path.
--  The helpers use only the GNAT runtime, so the crate keeps no dependency.

package Adacovex.Paths is
   pragma SPARK_Mode (On);

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
