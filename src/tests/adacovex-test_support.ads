with GNAT.OS_Lib;

package Adacovex.Test_Support is

   type Runner is tagged limited private;

   --  Record a test result.
   --  If Cond is True, the procedure increments the pass count. Otherwise
   --  it increments the fail count.
   --  @param Cond  Test condition (True = pass, False = fail)
   --  @param Msg   Human-readable test description.
   procedure Check (R : in out Runner; Cond : Boolean; Msg : String);

   --  Record a test that cannot run on this host. A skip is never a pass and
   --  never a failure; it carries the reason the run summary prints.
   --  @param Msg  Human-readable test description.
   --  @param Reason  Why the test cannot run on this host.
   --  @param Report  False records the skip without printing it (the support
   --    unit's own accounting tests use this).
   procedure Skip
     (R      : in out Runner;
      Msg    : String;
      Reason : String;
      Report : Boolean := True);

   --  Return the number of passed checks.
   --  @return Pass count.
   function Passed (R : Runner) return Natural;

   --  Return the number of failed checks.
   --  @return Fail count.
   function Failed (R : Runner) return Natural;

   --  Return the number of skipped checks.
   --  @return Skip count.
   function Skipped (R : Runner) return Natural;

   --  The host platform family: "windows", "macos", or "posix".
   --  @return The host platform family.
   function Host_OS return String;

   --  Skip a test when the host is the named platform. The reason names the
   --  platform the test needs and the host it is running on.
   --  @param OS  Platform family the test needs ("windows", "macos", "posix").
   --  @param Msg  Human-readable test description.
   --  @param Report  False records the skip without printing it.
   --  @return True when a skip was recorded; the caller returns at once.
   function Skip_On
     (R : in out Runner; OS : String; Msg : String; Report : Boolean := True)
      return Boolean;

   --  Skip a test when Command is not on PATH. The reason names the missing
   --  command.
   --  @param Command  Executable name to probe.
   --  @param Msg  Human-readable test description.
   --  @param Report  False records the skip without printing it.
   --  @return True when a skip was recorded; the caller returns at once.
   function Skip_Without
     (R       : in out Runner;
      Command : String;
      Msg     : String;
      Report  : Boolean := True) return Boolean;

   --  Create a fresh directory under the host temp directory. The name
   --  carries Prefix and the process id, so repeated runs never collide.
   --  @param Prefix  Short name describing the test group.
   --  @return The created directory, in native separator style.
   function Temp_Dir (Prefix : String) return String;

   --  Remove a directory tree. A missing path is not an error.
   --  @param Path  Directory to remove.
   procedure Remove_Tree (Path : String);

   --  Join two path components with one separator (the production rule).
   --  @param Dir  Directory part.
   --  @param Name  Entry name part.
   --  @return The joined path.
   function Join (Dir : String; Name : String) return String;

   --  Present a path in the host's native separator style. A '/' becomes the
   --  host separator on Windows and is unchanged on POSIX.
   --  @param Path  Path to convert.
   --  @return The path with native separators.
   function To_Native (Path : String) return String;

   --  Run a command from an argument vector, never a shell string. The
   --  child's output is discarded, so a deliberately missing command does
   --  not print an error into the suite log.
   --  @param Program  Program name or path.
   --  @param Args  Arguments (the program name is not repeated).
   --  @return The child's exit status, or -1 when it could not be started.
   function Run_Command
     (Program : String; Args : GNAT.OS_Lib.Argument_List) return Integer;

   --  Whether Command resolves on PATH.
   --  @param Command  Executable name to probe.
   --  @return True when the host can execute it.
   function Executable_On_Path (Command : String) return Boolean;

private

   type Runner is tagged limited record
      Pass_Count : Natural := 0;
      Fail_Count : Natural := 0;
      Skip_Count : Natural := 0;
   end record;

end Adacovex.Test_Support;
