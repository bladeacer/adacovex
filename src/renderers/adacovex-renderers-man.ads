--  Man-page renderer and installer.
--  Generates a roff (man 1) page for adacovex and installs it into the
--  local man database.  `man adacovex` then works without root.  The page
--  embeds the bundled binary version (in the .TH header and a VERSION
--  section).  `adacovex man --check` can detect that a newer man page is
--  available than the one on disk.  A shell prompt hook can also detect
--  this.  The tool targets Linux and WSL.  The default install root is
--  $XDG_DATA_HOME/man or ~/.local/share/man.  The database updates with
--  `mandb` when it is present.

package Adacovex.Renderers.Man is

   --  Render the full roff man page for the given version.
   --  The page carries Version in the .TH header line and in the VERSION
   --  section.  Installed_Version can recover it from an installed file.
   --  @param Version  adacovex version (for example "1.10.0").
   --  @return Complete man-page source (roff format).
   function Render_Page (Version : String) return String;

   --  Default local man root directory (the directory that contains man1/).
   --  Uses $XDG_DATA_HOME/man when the XDG_DATA_HOME environment variable is
   --  set, otherwise $HOME/.local/share/man.  Falls back to /tmp when HOME
   --  is unset so the command still completes on a bare environment.
   --  @return Default man root directory path.
   function Default_Dir return String;

   --  Install the man page for Version under Man_Root/man1/adacovex.1.
   --  Creates the man1 directory if needed and (re)writes the page.  Running
   --  `adacovex man` after an upgrade then refreshes the local man page
   --  automatically.  Never raises.  Failures are reported via Success.
   --  @param Man_Root  Man root directory (contains man1/).
   --  @param Version  adacovex version embedded in the page.
   --  @param Success  True when the page was written. False on I/O failure.
   procedure Install
     (Man_Root : String; Version : String; Success : out Boolean);

   --  Refresh the local man database for Man_Root with `mandb`.
   --  Runs `mandb Man_Root` when mandb is on PATH (Linux/WSL).  It reports
   --  whether the refresh happened.  It returns True when mandb was found and
   --  exited 0.  It returns False when man-db is not installed or mandb
   --  failed.  Never raises.  A missing makewhatis or mandb does not fail the
   --  man command.  The page is still installed and readable via `man -l`.
   --  @param Man_Root  Man root directory to index.
   --  @return True when the man database was refreshed. False when mandb
   --          is unavailable or failed.
   function Update_Database (Man_Root : String) return Boolean;

   --  Version embedded in the installed man page, or "" when no page is
   --  installed under Man_Root/man1/adacovex.1 or its version cannot be
   --  parsed.  Used by `adacovex man --check` to detect that the machine
   --  has a newer version available than the installed page.
   --  @param Man_Root  Man root directory to inspect.
   --  @return Installed page version (for example "1.10.0") or "".
   function Installed_Version (Man_Root : String) return String;

end Adacovex.Renderers.Man;
