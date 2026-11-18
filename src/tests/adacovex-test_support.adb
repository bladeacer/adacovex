with Ada.Directories;
with Ada.Text_IO; use Ada.Text_IO;
with Adacovex.CPUs;
with Adacovex.Paths;

package body Adacovex.Test_Support is

   --  Monotonic part of a temp directory name. The process id keeps two runs
   --  apart; the counter keeps two calls in one run apart.
   Next_Id : Natural := 0;

   procedure Check (R : in out Runner; Cond : Boolean; Msg : String) is
   begin
      if Cond then
         R.Pass_Count := R.Pass_Count + 1;
         Put_Line ("  PASS: " & Msg);
      else
         R.Fail_Count := R.Fail_Count + 1;
         Put_Line ("  FAIL: " & Msg);
      end if;
   end Check;

   procedure Skip
     (R      : in out Runner;
      Msg    : String;
      Reason : String;
      Report : Boolean := True) is
   begin
      R.Skip_Count := R.Skip_Count + 1;
      if Report then
         Put_Line ("  SKIP: " & Msg & ": " & Reason);
      end if;
   end Skip;

   function Passed (R : Runner) return Natural is
   begin
      return R.Pass_Count;
   end Passed;

   function Failed (R : Runner) return Natural is
   begin
      return R.Fail_Count;
   end Failed;

   function Skipped (R : Runner) return Natural is
   begin
      return R.Skip_Count;
   end Skipped;

   function Host_OS return String is
   begin
      if GNAT.OS_Lib.Directory_Separator = '\' then
         return "windows";
      elsif Ada.Directories.Exists ("/System/Library/CoreServices") then
         return "macos";
      end if;
      return "posix";
   end Host_OS;

   function Skip_On
     (R : in out Runner; OS : String; Msg : String; Report : Boolean := True)
      return Boolean is
   begin
      if Host_OS = OS then
         Skip (R, Msg, "requires " & OS & "; this host is " & Host_OS, Report);
         return True;
      end if;
      return False;
   end Skip_On;

   function Skip_Without
     (R       : in out Runner;
      Command : String;
      Msg     : String;
      Report  : Boolean := True) return Boolean is
   begin
      if not Executable_On_Path (Command) then
         Skip (R, Msg, Command & " is not on PATH", Report);
         return True;
      end if;
      return False;
   end Skip_Without;

   function Temp_Dir (Prefix : String) return String is
      Pid  : constant Integer :=
        GNAT.OS_Lib.Pid_To_Integer (GNAT.OS_Lib.Current_Process_Id);
      Img  : constant String := Integer'Image (Pid);
      Num  : constant String := Natural'Image (Next_Id);
      Name : constant String :=
        Prefix & "-" & Img (2 .. Img'Last) & "-" & Num (2 .. Num'Last);
      Dir  : constant String :=
        To_Native
          (Join (Adacovex.CPUs.Get_Temp_Directory, "adacovex-tests-" & Name));
   begin
      Next_Id := Next_Id + 1;
      if Ada.Directories.Exists (Dir) then
         Ada.Directories.Delete_Tree (Dir);
      end if;
      Ada.Directories.Create_Path (Dir);
      return Dir;
   end Temp_Dir;

   procedure Remove_Tree (Path : String) is
   begin
      if Ada.Directories.Exists (Path) then
         Ada.Directories.Delete_Tree (Path);
      end if;
   exception
      when others =>
         null;
   end Remove_Tree;

   function Join (Dir : String; Name : String) return String is
   begin
      return Adacovex.Paths.Join (Dir, Name);
   end Join;

   function To_Native (Path : String) return String is
      Result : String (Path'Range) := Path;
   begin
      if GNAT.OS_Lib.Directory_Separator = '/' then
         return Result;
      end if;
      for I in Result'Range loop
         if Result (I) = '/' then
            Result (I) := GNAT.OS_Lib.Directory_Separator;
         end if;
      end loop;
      return Result;
   end To_Native;

   function Run_Command
     (Program : String; Args : GNAT.OS_Lib.Argument_List) return Integer
   is
      Success : Boolean := False;
      Code    : Integer := -1;
   begin
      GNAT.OS_Lib.Spawn
        (Program,
         Args,
         Adacovex.CPUs.Get_Null_Device,
         Success,
         Code,
         Err_To_Out => True);
      if not Success then
         return -1;
      end if;
      return Code;
   end Run_Command;

   function Executable_On_Path (Command : String) return Boolean is
      use GNAT.OS_Lib;
      Found : String_Access := Locate_Exec_On_Path (Command);
      Ok    : constant Boolean := Found /= null;
   begin
      Free (Found);
      return Ok;
   end Executable_On_Path;

end Adacovex.Test_Support;
