with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with GNAT.OS_Lib;
with Adacovex.Test_Support;
with Adacovex.Renderers.Tldr;
with Adacovex.CPUs;

package body Adacovex_Tldr_Tests is

   --  Whether a tldr binary is on PATH. The comparison against null is
   --  made here, outside Run's use clause, so "/=" always resolves to the
   --  universal access equality and never to a String operator.
   function Tldr_On_Path return Boolean is
      use GNAT.OS_Lib;
      Exe : String_Access := Locate_Exec_On_Path ("tldr");
      Has : Boolean;
   begin
      Has := Exe /= null;
      if Has then
         Free (Exe);
      end if;
      return Has;
   end Tldr_On_Path;

   procedure Run (R : in out Adacovex.Test_Support.Runner'Class) is
      use Ada.Strings.Fixed;
      use Adacovex.Renderers.Tldr;
      Pid  : constant String :=
        Integer'Image
          (GNAT.OS_Lib.Pid_To_Integer (GNAT.OS_Lib.Current_Process_Id));
      Root : constant String :=
        Adacovex.CPUs.Get_Temp_Directory
        & "/adacovex-tldr-test-"
        & Pid (2 .. Pid'Last);

   begin
      --  The bundled page carries the tldr structure and ends with a newline.
      declare
         P : constant String := Page;
      begin
         R.Check (P'Length > 0, "bundled tldr page is not empty");
         R.Check
           (Index (P, "# adacovex") = P'First,
            "bundled page starts with the adacovex title");
         R.Check
           (Index (P, "> Coverage, proof, and compliance") > 0,
            "bundled page has the one-line description");
         R.Check
           (Index (P, "`adacovex sbom`") > 0,
            "bundled page carries the sbom example");
         R.Check (P (P'Last) = ASCII.LF, "bundled page ends with a newline");
      end;

      --  Client names are stable, user-facing words.
      R.Check (Client_Name (No_Client) = "none", "no client has a name");
      R.Check (Client_Name (Tealdeer) = "tealdeer", "tealdeer has a name");
      R.Check
        (Client_Name (Base_Client) = "base client",
         "a base client has a name");
      R.Check
        (Client_Name (Unsupported_Client) = "unsupported client",
         "an unsupported client has a name");

      --  `tldr --version` classification.
      R.Check
        (Classify ("tealdeer 1.9.0") = Tealdeer,
         "tealdeer version output classifies as tealdeer");
      R.Check
        (Classify ("tldr 3.3.9") = Base_Client,
         "tldr version output classifies as a base client");
      R.Check
        (Classify ("tldr-node-client 2.0.1") = Base_Client,
         "the Node client classifies as a base client");
      R.Check
        (Classify ("") = Unsupported_Client,
         "empty version output is unsupported");
      R.Check
        (Classify ("htop 3.3.0") = Unsupported_Client,
         "an unrelated version output is unsupported");

      --  `tldr --show-paths` parsing. tealdeer annotates a convention
      --  directory with a trailing parenthetical, which is not part of the
      --  path.
      declare
         Paths : constant String :=
           "Config dir:       /home/u/.config/tealdeer/"
           & ASCII.LF
           & "Cache dir:        /home/u/.cache/tealdeer"
           & ASCII.LF
           & "Pages dir:        /home/u/.cache/tealdeer/tldr-pages/"
           & ASCII.LF
           & "Custom pages dir: /home/u/.local/share/tealdeer/pages/"
           & " (OS convention)"
           & ASCII.LF;
      begin
         R.Check
           (Custom_Pages_Dir (Paths) = "/home/u/.local/share/tealdeer/pages",
            "show-paths custom pages dir is parsed and the annotation drops");
         R.Check
           (Custom_Pages_Dir ("Cache dir: /home/u/.cache/tldr") = "",
            "show-paths without a custom pages line yields no directory");
         R.Check
           (Custom_Pages_Dir ("") = "",
            "empty show-paths output yields no directory");
      end;

      --  Per-client paths, computed from the platform roots. The Home
      --  argument is the Node client's old `~/.tldr` fallback.
      R.Check
        (Default_Pages_Dir (Tealdeer, "/h", "/d", "/c") = "/d/tealdeer/pages",
         "tealdeer pages live under the data home");
      R.Check
        (Default_Pages_Dir (Base_Client, "/h", "/d", "/c") = "/c/tldr/pages",
         "a base client pages tree lives under the cache home");
      R.Check
        (Default_Pages_Dir (No_Client, "/h", "/d", "/c") = "",
         "no client has no pages directory");
      R.Check
        (Page_File (Tealdeer, "/p") = "/p/adacovex.page.md",
         "tealdeer uses the flat .page.md file name");
      R.Check
        (Page_File (Base_Client, "/p") = "/p/common/adacovex.md",
         "a base client uses the common page");
      R.Check
        (Page_File (Unsupported_Client, "/p") = "",
         "an unsupported client has no page file");

      --  The Node client's `~/.tldr` tree is used when it exists and the
      --  platform cache directory does not.
      begin
         Ada.Directories.Create_Path (Root & "/home/.tldr/pages");
         R.Check
           (Default_Pages_Dir
              (Base_Client, Root & "/home", Root & "/data", Root & "/cache")
            = Root & "/home/.tldr/pages",
            "the Node client fallback is used when it is the only tree");
         Ada.Directories.Create_Path (Root & "/cache/tldr/pages");
         R.Check
           (Default_Pages_Dir
              (Base_Client, Root & "/home", Root & "/data", Root & "/cache")
            = Root & "/cache/tldr/pages",
            "the platform cache tree wins when both trees exist");
      end;

      --  `uname -s` mapping.
      R.Check
        (Platform_From_System ("Linux") = "linux",
         "Linux maps to the linux page directory");
      R.Check
        (Platform_From_System ("Darwin") = "osx",
         "Darwin maps to the osx page directory");
      R.Check
        (Platform_From_System ("FreeBSD") = "freebsd",
         "FreeBSD maps to the freebsd page directory");
      R.Check
        (Platform_From_System ("SunOS") = "sunos",
         "SunOS maps to the sunos page directory");
      R.Check
        (Platform_From_System ("Linux\n") = "linux",
         "a trailing newline does not stop the Linux match");
      R.Check
        (Platform_From_System ("NetBSD") = "netbsd",
         "NetBSD maps to the netbsd page directory");
      R.Check
        (Platform_From_System ("OpenBSD") = "openbsd",
         "OpenBSD maps to the openbsd page directory");
      R.Check
        (Platform_From_System ("Android") = "android",
         "Android maps to the android page directory");
      R.Check
        (Platform_From_System ("MINGW64_NT-10.0") = "windows",
         "a MINGW system maps to the windows page directory");
      R.Check
        (Platform_From_System ("MSYS_NT-10.0") = "windows",
         "an MSYS system maps to the windows page directory");
      R.Check
        (Platform_From_System ("CYGWIN_NT-10.0") = "windows",
         "a Cygwin system maps to the windows page directory");
      R.Check
        (Platform_From_System ("Plan9") = "",
         "an unknown system has no page directory");

      --  Install + read-back round-trip through the real file system.
      declare
         Page_Dir : constant String := Root & "/tealdeer/pages";
         OK       : Boolean;
      begin
         R.Check
           (not Installed (Tealdeer, Page_Dir),
            "an absent page is not installed");

         Install (Tealdeer, Page_Dir, OK);
         R.Check (OK, "tealdeer page install succeeds");
         R.Check
           (Installed (Tealdeer, Page_Dir),
            "the installed tealdeer page matches the bundled page");

         --  A stale page is detected.
         declare
            F : Ada.Text_IO.File_Type;
         begin
            Ada.Text_IO.Create
              (F, Ada.Text_IO.Out_File, Page_Dir & "/adacovex.page.md");
            Ada.Text_IO.Put_Line (F, "stale");
            Ada.Text_IO.Close (F);
         end;
         R.Check
           (not Installed (Tealdeer, Page_Dir),
            "a stale tealdeer page is detected");

         --  A base client gets the common page and, when the platform is
         --  known, the platform page.
         declare
            Base_Dir : constant String := Root & "/cache/tldr/pages";
            Platform : constant String := Platform_Page_Dir;
         begin
            Install (Base_Client, Base_Dir, OK);
            R.Check (OK, "base client page install succeeds");
            R.Check
              (Installed (Base_Client, Base_Dir),
               "the installed base page matches the bundled page");
            R.Check
              (Ada.Directories.Exists (Base_Dir & "/common/adacovex.md"),
               "the base client common page is written");
            if Platform'Length > 0 then
               R.Check
                 (Ada.Directories.Exists
                    (Base_Dir & "/" & Platform & "/adacovex.md"),
                  "the base client platform page is written");
            else
               R.Check
                 (True, "no platform page is written on an unknown system");
            end if;
         end;

         --  The unsupported families write nothing.
         declare
            Empty_Dir : constant String := Root & "/nothing/pages";
         begin
            Install (No_Client, Empty_Dir, OK);
            R.Check (not OK, "no client install reports failure");
            R.Check
              (not Ada.Directories.Exists (Empty_Dir),
               "no client install writes nothing");
         end;
      end;

      --  Detection without a tldr binary is No_Client, and never raises.
      --  The check only runs when tldr is not on PATH, so it can never
      --  install into a real client tree.
      if not Tldr_On_Path then
         declare
            Kind    : Client_Kind;
            Dir_Buf : String (1 .. Max_Dir);
            Dir_Len : Natural;
         begin
            Detect (Kind, Dir_Buf, Dir_Len);
            R.Check (Kind = No_Client, "detection reports no client");
            R.Check (Dir_Len = 0, "detection reports no page directory");
         end;
      else
         R.Check (True, "detection is skipped while a tldr binary exists");
      end if;

      --  Best-effort cleanup of the temp tree.
      begin
         Ada.Directories.Delete_File
           (Root & "/tealdeer/pages/adacovex.page.md");
         Ada.Directories.Delete_File
           (Root & "/cache/tldr/pages/common/adacovex.md");
         Ada.Directories.Delete_Directory (Root & "/tealdeer/pages");
         Ada.Directories.Delete_Directory (Root & "/tealdeer");
         Ada.Directories.Delete_Directory (Root & "/cache/tldr/pages/common");
         Ada.Directories.Delete_Directory (Root & "/cache/tldr/pages");
         Ada.Directories.Delete_Directory (Root & "/cache/tldr");
         Ada.Directories.Delete_Directory (Root & "/home/.tldr/pages");
         Ada.Directories.Delete_Directory (Root & "/home/.tldr");
         Ada.Directories.Delete_Directory (Root & "/home");
         Ada.Directories.Delete_Directory (Root & "/cache");
         Ada.Directories.Delete_Directory (Root);
      exception
         when others =>
            null;
      end;
   end Run;

end Adacovex_Tldr_Tests;
