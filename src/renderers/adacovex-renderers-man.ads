--  Man-page renderer and installer.
--  Generates a roff (man 1) page for adacovex and installs it into the
--  local man database so `man adacovex` works without root.  The page
--  embeds the bundled binary version (in the .TH header and a VERSION
--  section) so `adacovex man --check` -- and a shell prompt hook -- can
--  detect that a newer man page is available than the one on disk.
--  Targets Linux and WSL: the default install root is
--  $XDG_DATA_HOME/man or ~/.local/share/man, and the database is updated
--  with `mandb` when it is present.

package Adacovex.Renderers.Man is

   --  Render the full roff man page for the given version.
   --  The page carries Version in the .TH header line and in the VERSION
   --  section, so Installed_Version can recover it from an installed file.
   --  @param Version  adacovex version (e.g. "1.10.0").
   --  @return Complete man-page source (roff format).
   function Render_Page (Version : String) return String;

   --  Default local man root directory (the directory that contains man1/).
   --  Uses $XDG_DATA_HOME/man when the XDG_DATA_HOME environment variable is
   --  set, otherwise $HOME/.local/share/man.  Falls back to /tmp when HOME
   --  is unset so the command still completes on a bare environment.
   --  @return Default man root directory path.
   function Default_Dir return String;

   --  Install the man page for Version under Man_Root/man1/adacovex.1.
   --  Creates the man1 directory if needed and (re)writes the page, so
   --  running `adacovex man` after an upgrade refreshes the local man page
   --  automatically.  Never raises: failures are reported via Success.
   --  @param Man_Root  Man root directory (contains man1/).
   --  @param Version  adacovex version embedded in the page.
   --  @param Success  True when the page was written; False on I/O failure.
   procedure Install
     (Man_Root : String; Version : String; Success : out Boolean);

   --  Refresh the local man database for Man_Root with `mandb`.
   --  Runs `mandb Man_Root` when mandb is on PATH (Linux/WSL) and reports
   --  whether the refresh actually happened: True when mandb was found and
   --  exited 0, False when man-db is not installed or mandb failed.  Never
   --  raises, so a missing makewhatis/mandb never fails the man command --
   --  the page is still installed and readable via `man -l`.
   --  @param Man_Root  Man root directory to index.
   --  @return True when the man database was refreshed; False when mandb
   --          is unavailable or failed.
   function Update_Database (Man_Root : String) return Boolean;

   --  Version embedded in the installed man page, or "" when no page is
   --  installed under Man_Root/man1/adacovex.1 or its version cannot be
   --  parsed.  Used by `adacovex man --check` to detect that the machine
   --  has a newer version available than the installed page.
   --  @param Man_Root  Man root directory to inspect.
   --  @return Installed page version (e.g. "1.10.0") or "".
   function Installed_Version (Man_Root : String) return String;

end Adacovex.Renderers.Man;
