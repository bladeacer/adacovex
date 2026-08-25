with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings;
with Ada.Text_IO;
with Ada.Environment_Variables;
with GNAT.OS_Lib;

package body Adacovex.CPUs is

   use Ada.Strings.Fixed;
   use GNAT.OS_Lib;

   --  Parse a non-negative integer from the leading digits of S, ignoring
   --  trailing whitespace/garbage.  Returns -1 when no digit is found.
   function Parse_Natural (S : String) return Integer is
      Start : Natural := S'First;
      Stop  : Natural := S'First;
      Val   : Integer := 0;
      Found : Boolean := False;
   begin
      while Start <= S'Last loop
         exit when S (Start) in '0' .. '9';
         Start := Start + 1;
      end loop;
      if Start > S'Last then
         return -1;
      end if;
      Stop := Start;
      while Stop <= S'Last and then S (Stop) in '0' .. '9' loop
         Val := Val * 10 + (Character'Pos (S (Stop)) - Character'Pos ('0'));
         Found := True;
         Stop := Stop + 1;
      end loop;
      if not Found then
         return -1;
      end if;
      return Val;
   end Parse_Natural;

   procedure Run_Capture
     (Cmd      : String;
      Out_Line : out String;
      Out_Len  : out Natural;
      Ok       : out Boolean)
   is
      Tmp  : constant String := Get_Temp_Directory & "/adacovex-sysctl.tmp";
      Args : Argument_List :=
        (new String'("-c"), new String'(Cmd & " > '" & Tmp & "' 2>/dev/null"));
      Code : Integer;
      Succ : Boolean;
      F    : Ada.Text_IO.File_Type;
   begin
      Out_Len := 0;
      Ok := False;
      Spawn
        (Get_Shell_Command, Args, "/dev/null", Succ, Code, Err_To_Out => True);
      Free (Args (1));
      Free (Args (2));
      if not Succ or else Code /= 0 then
         return;
      end if;
      begin
         Ada.Text_IO.Open (F, Ada.Text_IO.In_File, Tmp);
         if not Ada.Text_IO.End_Of_File (F) then
            declare
               L : constant String :=
                 Trim (Ada.Text_IO.Get_Line (F), Ada.Strings.Both);
            begin
               if L'Length <= Out_Line'Length then
                  Out_Len := L'Length;
                  Out_Line (Out_Line'First .. Out_Line'First + Out_Len - 1) :=
                    L;
                  Ok := True;
               end if;
            end;
         end if;
         Ada.Text_IO.Close (F);
      exception
         when others =>
            if Ada.Text_IO.Is_Open (F) then
               Ada.Text_IO.Close (F);
            end if;
      end;
      begin
         if Ada.Directories.Exists (Tmp) then
            Ada.Directories.Delete_File (Tmp);
         end if;
      exception
         when others =>
            null;
      end;
   end Run_Capture;

   function Detect_Core_Count return Natural is
      use Ada.Text_IO;
      F        : File_Type;
      Count    : Natural := 0;
      Line     : String (1 .. 256);
      LLen     : Natural;
      Captured : String (1 .. 32);
      CLen     : Natural;
      Ok       : Boolean;
      N        : Integer;
   begin
      --  Linux: count "processor" entries in /proc/cpuinfo.
      begin
         Open (F, In_File, "/proc/cpuinfo");
         while not End_Of_File (F) loop
            Get_Line (F, Line, LLen);
            if LLen >= 9
              and then Line (Line'First .. Line'First + 8) = "processor"
            then
               Count := Count + 1;
            end if;
         end loop;
         Close (F);
         if Count > 0 then
            return Count;
         end if;
      exception
         when others =>
            if Is_Open (F) then
               Close (F);
            end if;
      end;

      --  macOS / FreeBSD: sysctl -n hw.ncpu
      Run_Capture ("sysctl -n hw.ncpu", Captured, CLen, Ok);
      if Ok then
         N := Parse_Natural (Captured (1 .. CLen));
         if N > 0 then
            return Natural (N);
         end if;
      end if;

      --  Linux fallback: nproc
      Run_Capture ("nproc", Captured, CLen, Ok);
      if Ok then
         N := Parse_Natural (Captured (1 .. CLen));
         if N > 0 then
            return Natural (N);
         end if;
      end if;

      --  Windows: NUMBER_OF_PROCESSORS env var.
      if Ada.Environment_Variables.Exists ("NUMBER_OF_PROCESSORS") then
         declare
            V : constant String :=
              Ada.Environment_Variables.Value ("NUMBER_OF_PROCESSORS");
         begin
            N := Parse_Natural (V);
            if N > 0 then
               return Natural (N);
            end if;
         end;
      end if;

      --  Windows fallback: PowerShell CIM query.
      Run_Capture
        ("powershell -NoProfile -Command "
         & """(Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors""",
         Captured,
         CLen,
         Ok);
      if Ok then
         N := Parse_Natural (Captured (1 .. CLen));
         if N > 0 then
            return Natural (N);
         end if;
      end if;

      return 1;
   end Detect_Core_Count;

   function Is_Running_In_CI return Boolean is
      function Has (Name : String) return Boolean is
      begin
         return Ada.Environment_Variables.Exists (Name);
      end Has;
   begin
      return
        Has ("CI")
        or else Has ("GITHUB_ACTIONS")
        or else Has ("GITLAB_CI")
        or else Has ("TF_BUILD")
        or else Has ("BUILDKITE")
        or else Has ("CIRCLECI")
        or else Has ("TRAVIS")
        or else Has ("APPVEYOR")
        or else Has ("JENKINS_URL");
   end Is_Running_In_CI;

   function Default_Prove_Jobs
     (Cores : Natural; In_CI : Boolean) return Natural
   with SPARK_Mode => On
   is
   begin
      if In_CI then
         return Cores;
      else
         return Natural'Max (1, Cores - 2);
      end if;
   end Default_Prove_Jobs;

   function Resolve_Jobs (Configured : Integer; In_CI : Boolean) return Natural
   is
   begin
      if Configured = 0 then
         --  -j0 means "all cores" to gnatprove; report the real count.
         return Detect_Core_Count;
      elsif Configured > 0 then
         return Natural (Configured);
      else
         return Default_Prove_Jobs (Detect_Core_Count, In_CI);
      end if;
   end Resolve_Jobs;

   function Jobs_Justification
     (Configured : Integer; Cores : Natural; In_CI : Boolean) return String
   with SPARK_Mode => On
   is
   begin
      if Configured = 0 then
         return "auto default (all cores): -j0";
      elsif Configured > 0 then
         return "explicit --jobs=" & Integer'Image (Configured);
      elsif In_CI then
         return
           "auto default (CI): using all" & Natural'Image (Cores) & " cores";
      else
         return
           "auto default:"
           & Natural'Image (Cores)
           & " - 2 ="
           & Natural'Image (Natural'Max (1, Cores - 2))
           & " jobs (reserved 2 cores for system)";
      end if;
   end Jobs_Justification;

   --  Portable system temp directory.  Checks TMPDIR, TEMP, TMP (in that
   --  order) and falls back to "/tmp".  SPARK_Mode On.  The runtime
   --  Ada.Environment_Variables subprograms carry no Global contracts, so
   --  gnatprove 16 would emit [assumed-global-null] warnings at each call
   --  ("no Global contract available"); the pragma below silences exactly
   --  those messages and is scoped back on immediately after the function.
   pragma Warnings (Off, "no Global contract available");
   function Get_Temp_Directory return String with SPARK_Mode => On is
      use Ada.Environment_Variables;
   begin
      if Exists ("TMPDIR") then
         return Value ("TMPDIR");
      elsif Exists ("TEMP") then
         return Value ("TEMP");
      elsif Exists ("TMP") then
         return Value ("TMP");
      else
         return "/tmp";
      end if;
   end Get_Temp_Directory;
   pragma Warnings (On, "no Global contract available");

   --  Default shell executable for spawned commands.  Pure constant
   --  (SPARK_Mode On per the spec): returns "sh" with no global state.
   function Get_Shell_Command return String with SPARK_Mode => On is
   begin
      return "sh";
   end Get_Shell_Command;

end Adacovex.CPUs;
