with Ada.Directories;
with Ada.Strings.Fixed;
with Adacovex.Paths;
with GNAT.OS_Lib;

package body Adacovex_Test_Support_Tests is

   --  A platform family that is not the host's, for the negative Skip_On
   --  case.
   --  @return The other platform family.
   function Other_OS return String is
   begin
      if Adacovex.Test_Support.Host_OS = "windows" then
         return "posix";
      end if;
      return "windows";
   end Other_OS;

   procedure Run (R : in out Adacovex.Test_Support.Runner'Class) is
      use Adacovex.Test_Support;
      use GNAT.OS_Lib;
      Tmp  : constant String := Temp_Dir ("support");
      Tmp2 : constant String := Temp_Dir ("support");
      Args : GNAT.OS_Lib.Argument_List := (1 => new String'("--version"));
      Code : Integer;
   begin
      --  Host detection.
      R.Check
        (Host_OS = "windows"
         or else Host_OS = "macos"
         or else Host_OS = "posix",
         "Host_OS names one of the three platform families");

      --  Temp_Dir creates a real, unique directory under the host temp root.
      R.Check
        (Ada.Directories.Exists (Tmp),
         "Temp_Dir creates the directory it returns");
      R.Check
        (Ada.Strings.Fixed.Index (Tmp, "support") > 0,
         "Temp_Dir carries the caller's prefix");
      R.Check (Tmp /= Tmp2, "two Temp_Dir calls return different directories");

      --  Join and To_Native agree with the production path rules.
      R.Check
        (Join ("a", "b") = "a/b",
         "Join puts exactly one separator between the parts");
      declare
         Native : constant String := To_Native ("a/b");
      begin
         if GNAT.OS_Lib.Directory_Separator = '/' then
            R.Check
              (Native = "a/b", "To_Native leaves '/' alone on a POSIX host");
         else
            R.Check
              (Ada.Strings.Fixed.Index (Native, "/") = 0,
               "To_Native replaces every '/' on Windows");
         end if;
      end;

      --  Command probing never assumes a host shell.
      R.Check
        (not Executable_On_Path ("adacovex-no-such-command-9f2c"),
         "Executable_On_Path rejects a name that is not on PATH");
      Code := Run_Command ("adacovex-no-such-command-9f2c", Args);
      R.Check
        (Code /= 0, "Run_Command reports failure when the program is missing");
      GNAT.OS_Lib.Free (Args (1));

      --  Skip accounting: a skip is neither a pass nor a failure.
      declare
         Scratch : Runner;
      begin
         R.Check (Scratch.Skipped = 0, "a fresh runner records no skips");
         Skip
           (Scratch,
            "self-test skip",
            "the accounting is under test",
            Report => False);
         R.Check
           (Scratch.Skipped = 1
            and then Scratch.Passed = 0
            and then Scratch.Failed = 0,
            "a skip counts once and is never a pass or a failure");
      end;
      declare
         Scratch : Runner;
      begin
         R.Check
           (Skip_On (Scratch, Host_OS, "self-test skip", Report => False),
            "Skip_On records a skip and returns True on the named host");
         R.Check (Scratch.Skipped = 1, "Skip_On counts the skip once");
      end;
      declare
         Scratch : Runner;
      begin
         R.Check
           (not Skip_On (Scratch, Other_OS, "self-test skip", Report => False)
            and then Scratch.Skipped = 0,
            "Skip_On leaves a different host alone and returns False");
      end;
      declare
         Scratch : Runner;
      begin
         R.Check
           (Skip_Without
              (Scratch,
               "adacovex-no-such-command-9f2c",
               "self-test skip",
               Report => False),
            "Skip_Without records a skip and returns True for a missing command");
         R.Check (Scratch.Skipped = 1, "Skip_Without counts the skip once");
      end;

      --  The Windows path shapes are parsed on every host.
      R.Check
        (Adacovex.Paths.Is_Absolute ("C:\project"),
         "a Windows drive letter makes a path absolute");
      R.Check
        (Adacovex.Paths.Is_Absolute ("\\server\share"),
         "a Windows UNC prefix makes a path absolute");
      R.Check
        (Adacovex.Paths.Is_Separator ('/')
         and then Adacovex.Paths.Is_Separator ('\'),
         "both separators are accepted");

      --  Clean up this group's scratch directories.
      Remove_Tree (Tmp);
      R.Check
        (not Ada.Directories.Exists (Tmp),
         "Remove_Tree deletes the tree it is given");
      Remove_Tree (Tmp2);
   end Run;

end Adacovex_Test_Support_Tests;
