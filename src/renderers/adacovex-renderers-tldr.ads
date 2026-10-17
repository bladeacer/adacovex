--  tldr page installer.
--  Installs the bundled tldr page (`docs/tldr/adacovex.md`, embedded at
--  build time by tools/gen-tldr.py) into the local tldr client, so
--  `tldr adacovex` works offline. The installer is client agnostic: it
--  detects the installed client first, then writes to that client's own
--  page location.
--
--  tealdeer reads a flat custom-pages directory (`adacovex.page.md`), which
--  sits outside its cache, so `tldr --update` cannot remove the page. A
--  client that follows CLIENT-SPECIFICATION.md reads its extracted cache
--  pages tree instead (`pages/common/adacovex.md` plus the platform
--  directory), and the page survives a cache update because the update
--  overlays the archive without deleting extra files.
--
--  `adacovex tldr` installs or refreshes the page. `adacovex tldr --check`
--  exits 0 when the installed page matches the bundled one, and 1 when it
--  is missing or stale, so a shell prompt hook can keep it fresh after a
--  `tldr --update`.
--
--  HLR-TLDR: Client-agnostic tldr page installation

package Adacovex.Renderers.Tldr is

   --  Longest page directory path the installer handles, in bytes.
   Max_Dir : constant := 1024;

   --  A detected tldr client family.
   --  Base_Client is the family that follows CLIENT-SPECIFICATION.md (the C,
   --  Node, and Python clients). Tealdeer keeps custom pages outside its
   --  cache. Unsupported_Client means a `tldr` binary answered, but its
   --  family is not known.
   type Client_Kind is (No_Client, Base_Client, Tealdeer, Unsupported_Client);

   --  The bundled tldr page text, byte for byte.
   --  The text comes from docs/tldr/adacovex.md through the generated
   --  Adacovex.Tldr_Template unit.
   --  @return The page text.
   function Page return String;

   --  A short display name for a client family.
   --  @param Kind  Client family.
   --  @return Display name (for example "tealdeer").
   function Client_Name (Kind : Client_Kind) return String;

   --  Classify the output of `tldr --version`.
   --  The result is Tealdeer when the text names tealdeer, Base_Client when
   --  it names a tldr client, and Unsupported_Client otherwise.
   --  @param Version_Output  Captured stdout of `tldr --version`.
   --  @return The detected client family.
   function Classify (Version_Output : String) return Client_Kind;

   --  The custom pages directory in `tldr --show-paths` output.
   --  tealdeer prints one `Custom pages dir: <path>` line. A client that
   --  does not support the option prints no such line.
   --  @param Show_Paths_Output  Captured stdout of `tldr --show-paths`.
   --  @return The directory (no trailing slash), or "" when absent.
   function Custom_Pages_Dir (Show_Paths_Output : String) return String;

   --  The default page directory for a client family.
   --  tealdeer reads Data_Home/tealdeer/pages. A base client reads
   --  Cache_Home/tldr/pages, or Cache_Home/tldr-node-client/pages when that
   --  tree exists.
   --  @param Kind  Client family.
   --  @param Data_Home  XDG data home (for example ~/.local/share).
   --  @param Cache_Home  XDG cache home (for example ~/.cache).
   --  @return Page directory, or "" for a family with no page directory.
   function Default_Pages_Dir
     (Kind : Client_Kind; Data_Home : String; Cache_Home : String)
      return String;

   --  The page file for a client under Pages_Dir.
   --  tealdeer uses Pages_Dir/adacovex.page.md. A base client uses
   --  Pages_Dir/common/adacovex.md.
   --  @param Kind  Client family.
   --  @param Pages_Dir  Page directory (see Default_Pages_Dir).
   --  @return Page file path, or "" for a family with no page file.
   function Page_File (Kind : Client_Kind; Pages_Dir : String) return String;

   --  The platform page directory a base client also reads.
   --  The program runs `uname -s` and maps the system name to the tldr page
   --  directory (for example linux or osx).
   --  @return Directory name, or "" when the system is not known.
   function Platform_Page_Dir return String;

   --  Map a `uname -s` system name to its tldr page directory.
   --  @param System_Name  Output of `uname -s` (for example "Linux").
   --  @return Page directory name, or "" when the system is not known.
   function Platform_From_System (System_Name : String) return String;

   --  Detect the local tldr client and its page directory.
   --  The program tries `tldr --show-paths` first, then classifies
   --  `tldr --version`. It never raises. Kind is No_Client when no tldr
   --  binary is on PATH.
   --  @param Kind  Detected client family.
   --  @param Pages_Dir  Buffer that receives the page directory.
   --  @param Pages_Len  Length of the page directory in Pages_Dir.
   procedure Detect
     (Kind : out Client_Kind; Pages_Dir : out String; Pages_Len : out Natural)
   with Pre => Pages_Dir'Length >= Max_Dir;

   --  Install (or refresh) the page for a client.
   --  A base client gets both the common page and the platform page, so the
   --  two never disagree. Every write creates the parent directory first.
   --  Never raises. Failures are reported through Success.
   --  @param Kind  Client family.
   --  @param Pages_Dir  Page directory (see Default_Pages_Dir).
   --  @param Success  True when every page file was written.
   procedure Install
     (Kind : Client_Kind; Pages_Dir : String; Success : out Boolean);

   --  Whether the installed page matches the bundled page.
   --  A missing page, an unreadable page, or a page with different content
   --  all report False.
   --  @param Kind  Client family.
   --  @param Pages_Dir  Page directory (see Default_Pages_Dir).
   --  @return True when the primary page file equals Page.
   function Installed (Kind : Client_Kind; Pages_Dir : String) return Boolean;

   --  The XDG data home used by the default page directory.
   --  It reads $XDG_DATA_HOME, then $HOME/.local/share, then the temp
   --  directory.
   --  @return Data home path.
   function Data_Home return String;

   --  The XDG cache home used by the default page directory.
   --  It reads $XDG_CACHE_HOME, then $HOME/.cache, then the temp directory.
   --  @return Cache home path.
   function Cache_Home return String;

end Adacovex.Renderers.Tldr;
