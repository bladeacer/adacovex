with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with GNAT.OS_Lib;
with Adacovex.Test_Support;
with Adacovex.VCS;
with Adacovex.CPUs;

package body Adacovex_VCS_Tests is

   procedure Run (R : in out Adacovex.Test_Support.Runner'Class) is
      use Ada.Directories;
      use Adacovex.VCS;
      Pid  : constant String :=
        Integer'Image
          (GNAT.OS_Lib.Pid_To_Integer (GNAT.OS_Lib.Current_Process_Id));
      Base : constant String :=
        Adacovex.CPUs.Get_Temp_Directory
        & "/adacovex-vcs-test-"
        & Pid (2 .. Pid'Last);

      procedure Cleanup (Sub : String) is
      begin
         begin
            Ada.Directories.Delete_File (Base & "/" & Sub);
         exception
            when others =>
               null;
         end;
         begin
            Ada.Directories.Delete_Directory (Base & "/" & Sub);
         exception
            when others =>
               null;
         end;
      end Cleanup;
   begin
      --  Display names.
      R.Check (To_String (Git) = "git", "git display name");
      R.Check (To_String (Mercurial) = "mercurial", "mercurial display name");
      R.Check
        (To_String (Subversion) = "subversion", "subversion display name");
      R.Check (To_String (Fossil) = "fossil", "fossil display name");
      R.Check (To_String (Jujutsu) = "jj", "jj display name");
      R.Check (To_String (Unknown) = "", "unknown display name is empty");

      --  Command-line tool binaries.
      R.Check (Tool_Name (Git) = "git", "git tool binary");
      R.Check (Tool_Name (Mercurial) = "hg", "mercurial tool binary");
      R.Check (Tool_Name (Subversion) = "svn", "subversion tool binary");
      R.Check (Tool_Name (Fossil) = "fossil", "fossil tool binary");
      R.Check (Tool_Name (Jujutsu) = "jj", "jj tool binary");
      R.Check (Tool_Name (Unknown) = "", "unknown tool binary is empty");

      --  UX guidance: git/mercurial/jj are fully supported (no note);
      --  subversion and fossil recommend converting to git.
      R.Check (UX_Note (Git) = "", "git needs no UX note");
      R.Check (UX_Note (Mercurial) = "", "mercurial needs no UX note");
      R.Check (UX_Note (Jujutsu) = "", "jj needs no UX note");
      R.Check
        (UX_Note (Subversion)'Length > 0,
         "subversion carries a UX recommendation");
      R.Check
        (Ada.Strings.Fixed.Index (UX_Note (Subversion), "convert") > 0,
         "subversion note recommends converting the repo");
      R.Check
        (UX_Note (Fossil)'Length > 0, "fossil carries a UX recommendation");

      --  Marker-file detection. Each candidate gets its own scratch
      --  directory so detection is unambiguous (git wins over colocated jj).
      begin
         Create_Path (Base & "/git/.git");
         Create_Path (Base & "/jj/.jj");
         Create_Path (Base & "/hg/.hg");
         Create_Path (Base & "/svn/.svn");
         Create_Path (Base & "/fossil");
         Create_Path (Base & "/fossil2");
         Create_Path (Base & "/none");
      exception
         when others =>
            null;
      end;
      declare
         F : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Create
           (F, Ada.Text_IO.Out_File, Base & "/fossil/.fslckout");
         Ada.Text_IO.Close (F);
         Ada.Text_IO.Create
           (F, Ada.Text_IO.Out_File, Base & "/fossil2/_FOSSIL_");
         Ada.Text_IO.Close (F);
      exception
         when others =>
            null;
      end;

      R.Check (Detect (Base & "/git") = Git, ".git marker detects git");
      R.Check (Detect (Base & "/jj") = Jujutsu, ".jj marker detects jj");
      R.Check (Detect (Base & "/hg") = Mercurial, ".hg marker detects hg");
      R.Check (Detect (Base & "/svn") = Subversion, ".svn marker detects svn");
      R.Check
        (Detect (Base & "/fossil") = Fossil,
         ".fslckout marker detects fossil");
      R.Check
        (Detect (Base & "/fossil2") = Fossil,
         "_FOSSIL_ marker detects fossil");
      R.Check (Detect (Base & "/none") = Unknown, "empty dir detects unknown");
      R.Check
        (Detect (Base & "/missing") = Unknown, "missing dir detects unknown");

      --  The two command shells the differential modes drive. Both families
      --  are exercised on every host, so the Windows shape is pinned even
      --  on a POSIX machine and the POSIX shape even on Windows.
      R.Check
        (Quote_Path (POSIX_Shell, "/a b") = "'/a b'",
         "the POSIX shell quotes a path with single quotes");
      R.Check
        (Quote_Path (CMD_Shell, "C:\a b") = """C:\a b""",
         "cmd.exe quotes a path with double quotes");
      R.Check
        (Change_Dir_Prefix (POSIX_Shell, "/a b") = "cd '/a b' && ",
         "the POSIX shell changes directory with cd");
      R.Check
        (Change_Dir_Prefix (CMD_Shell, "C:\a b") = "cd /d ""C:\a b"" && ",
         "cmd.exe changes directory with cd /d");
      R.Check
        (Null_Device (POSIX_Shell) = "/dev/null",
         "the POSIX shell discards output to /dev/null");
      R.Check
        (Null_Device (CMD_Shell) = "NUL", "cmd.exe discards output to NUL");
      R.Check
        (Host_Shell = POSIX_Shell or else Host_Shell = CMD_Shell,
         "the host shell is one of the two families");
      R.Check
        (Null_Device (Host_Shell)'Length > 0
         and then Change_Dir_Prefix (Host_Shell, Base)'Length > 3,
         "the host shell helpers answer for this host");

      R.Check (Is_Managed (Base & "/git"), "git dir is managed");
      R.Check (Is_Managed (Base & "/hg"), "hg dir is managed");
      R.Check (not Is_Managed (Base & "/none"), "empty dir is not managed");

      Cleanup ("git/.git");
      Cleanup ("git");
      Cleanup ("jj/.jj");
      Cleanup ("jj");
      Cleanup ("hg/.hg");
      Cleanup ("hg");
      Cleanup ("svn/.svn");
      Cleanup ("svn");
      Cleanup ("fossil/.fslckout");
      Cleanup ("fossil");
      Cleanup ("fossil2/_FOSSIL_");
      Cleanup ("fossil2");
      Cleanup ("none");
      Cleanup ("");
   end Run;

end Adacovex_VCS_Tests;
