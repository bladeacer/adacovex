--  Man-page renderer and installer.
--  Generates a roff (man 1) page for adacovex and installs it into a local
--  man root, so `man adacovex` works without root. The page embeds the
--  bundled binary version (in the .TH header and a VERSION section).
--  `adacovex man --check` can detect that a newer man page is available than
--  the one on disk. A shell prompt hook can also detect this.
--
--  The installer follows the host's man reader. GNU/Linux distributions use
--  man-db (https://man-db.gitlab.io/man-db/), and macOS and the BSDs use
--  mandoc (https://mandoc.bsd.lv/); both readers also run on WSL and on
--  Cygwin, MSYS2, and Git Bash. A user-level man root is only searched when
--  it is on the reader's man path, so the installer prefers a writable
--  `MANPATH` entry, otherwise the platform data root, and reports when that
--  root is not on the man path.
--
--  The install root is `$MANPATH`'s first home-owned entry when one exists,
--  otherwise `<data home>/man`: `$XDG_DATA_HOME/man` (or
--  `~/.local/share/man`) on Linux and the BSDs, `~/Library/Application
--  Support/man` on macOS, and `%APPDATA%\man` on Windows. The man database
--  refreshes with `mandb` (man-db) and falls back to `makewhatis` (mandoc).

package Adacovex.Renderers.Man is

   --  The indexer that refreshed the man database.
   type Database_Tool is (No_Tool, Man_DB, Makewhatis);

   --  Render the full roff man page for the given version.
   --  The page carries Version in the .TH header line and in the VERSION
   --  section. Installed_Version can recover it from an installed file.
   --  @param Version  adacovex version (for example "1.10.0").
   --  @return Complete man-page source (roff format).
   function Render_Page (Version : String) return String;

   --  Default local man root directory (the directory that contains man1/).
   --  A home-owned `MANPATH` entry wins. Otherwise the root is the platform
   --  data home plus `man`: `$XDG_DATA_HOME/man` or `~/.local/share/man` on
   --  Linux and the BSDs, `~/Library/Application Support/man` on macOS, and
   --  `%APPDATA%\man` on Windows. A bare environment falls back to the temp
   --  directory, so the command still completes there.
   --  @return Default man root directory path.
   function Default_Dir return String;

   --  Install the man page for Version under Man_Root/man1/adacovex.1.
   --  Creates the man1 directory if needed and (re)writes the page. Running
   --  `adacovex man` after an upgrade then refreshes the local man page
   --  automatically. Never raises. Failures are reported via Success.
   --  @param Man_Root  Man root directory (contains man1/).
   --  @param Version  adacovex version embedded in the page.
   --  @param Success  True when the page was written. False on I/O failure.
   procedure Install
     (Man_Root : String; Version : String; Success : out Boolean);

   --  Refresh the local man database for Man_Root.
   --  Runs `mandb Man_Root` when man-db is on PATH. When mandb is absent or
   --  fails, it runs `makewhatis Man_Root` (the mandoc indexer used on the
   --  BSDs and macOS). It reports which tool ran through Tool. It returns
   --  True when one of them exited 0, and False when neither is installed or
   --  both failed. Never raises. A missing indexer does not fail the man
   --  command: the page is still installed and readable via `man -l`.
   --  @param Man_Root  Man root directory to index.
   --  @param Tool  Indexer that refreshed the database (No_Tool on failure).
   --  @return True when the man database was refreshed.
   function Update_Database
     (Man_Root : String; Tool : out Database_Tool) return Boolean;

   --  Refresh the local man database, without reporting the indexer.
   --  Kept for callers that only need the boolean outcome.
   --  @param Man_Root  Man root directory to index.
   --  @return True when the man database was refreshed.
   function Update_Database (Man_Root : String) return Boolean;

   --  Whether a path list names Man_Root.
   --  The list is split on the host path separator (`:` on POSIX, `;` on
   --  Windows) and on newlines, and trailing separators are ignored on both
   --  sides. An empty list never matches.
   --  @param Manpath_Text  A man path list (from $MANPATH or `manpath`).
   --  @param Man_Root  Man root to look for.
   --  @return True when the root is one of the entries.
   function Manpath_Contains
     (Manpath_Text : String; Man_Root : String) return Boolean;

   --  The first home-owned entry in a man path list.
   --  A home-owned entry is the first entry that lies under Home, so an
   --  installer can prefer a directory the user can write to over the
   --  system man roots.
   --  @param Manpath_Text  A man path list (from $MANPATH or `manpath`).
   --  @param Home  User home directory.
   --  @return The entry (no trailing slash), or "" when none lies under Home.
   function Manpath_User_Entry
     (Manpath_Text : String; Home : String) return String;

   --  Whether Man_Root is on the man path the reader will search.
   --  The program reads `$MANPATH`, otherwise runs `manpath` to ask the
   --  reader itself. When neither answers (for example on Windows without a
   --  man reader) it reports True, so the installer never prints advice it
   --  cannot verify.
   --  @param Man_Root  Man root to look for.
   --  @return True when the root is searched, or cannot be determined.
   function Root_On_Manpath (Man_Root : String) return Boolean;

   --  Version embedded in the installed man page, or "" when no page is
   --  installed under Man_Root/man1/adacovex.1 or its version cannot be
   --  parsed. Used by `adacovex man --check` to detect that the machine
   --  has a newer version available than the installed page.
   --  @param Man_Root  Man root directory to inspect.
   --  @return Installed page version (for example "1.10.0") or "".
   function Installed_Version (Man_Root : String) return String;

end Adacovex.Renderers.Man;
