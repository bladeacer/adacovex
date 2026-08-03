with Ada.Directories;
with Ada.Text_IO;
with Ada.Environment_Variables;
with GNAT.OS_Lib;
with Adacovex;

package body Adacovex.Prove is

   use GNAT.OS_Lib;

   Toolchain_Subdir : constant String := "/.adacovex/toolchain";
   Bin_Subdir       : constant String := "/bin/gnatprove";

   function Home_Dir return String is
   begin
      if Ada.Environment_Variables.Exists ("HOME") then
         return Ada.Environment_Variables.Value ("HOME");
      else
         return "/tmp";
      end if;
   end Home_Dir;

   --  Normalize a trailing '/' off a directory path.
   function Strip_Trailing_Slash (S : String) return String is
   begin
      if S'Length > 1 and then S (S'Last) = '/' then
         return S (S'First .. S'Last - 1);
      else
         return S;
      end if;
   end Strip_Trailing_Slash;

   procedure Copy_To
     (Dst : out String; Dst_Len : out Natural; Src : String)
   is
   begin
      Dst_Len := Src'Length;
      for I in Src'Range loop
         Dst (I - Src'First + 1) := Src (I);
      end loop;
   end Copy_To;

   procedure Run_Command
     (Args        : GNAT.OS_Lib.Argument_List;
      Output_File : String;
      Success     : out Boolean;
      Code        : out Integer)
   is
      Prog : String_Access := Locate_Exec_On_Path ("sh");
   begin
      if Prog = null then
         Success := False;
         Code := 127;
         return;
      end if;
      Spawn (Prog.all, Args, Output_File, Success, Code, Err_To_Out => True);
      Free (Prog);
   end Run_Command;

   --  Download and unpack the platform toolchain bundle into
   --  ~/.adacovex/toolchain/.  Uses the ADACOVEX_TOOLCHAIN_URL environment
   --  variable if set, otherwise the default GitHub release asset
   --  adacovex-toolchain-<os>-<arch>.tar.gz from the project's releases.
   procedure Download_Toolchain (Success : out Boolean) is
      Home : constant String := Home_Dir;
      Dst  : constant String := Home & Toolchain_Subdir;
      Tmp  : constant String := "/tmp/adacovex-toolchain.tar.gz";
      URL  : String (1 .. Types.Max_Path);
      URL_Len : Natural := 0;
   begin
      Ada.Directories.Create_Path (Dst);

      if Ada.Environment_Variables.Exists ("ADACOVEX_TOOLCHAIN_URL") then
         declare
            V : constant String :=
              Ada.Environment_Variables.Value ("ADACOVEX_TOOLCHAIN_URL");
         begin
            if V'Length <= Types.Max_Path then
               URL_Len := V'Length;
               for I in 1 .. V'Length loop
                  URL (I) := V (I);
               end loop;
            end if;
         end;
      else
         declare
            V : constant String :=
              "https://github.com/bladeacer/adacovex/releases/latest/download/"
              & "adacovex-toolchain-linux-x86_64.tar.gz";
         begin
            URL_Len := V'Length;
            for I in 1 .. V'Length loop
               URL (I) := V (I);
            end loop;
         end;
      end if;

      declare
         OK : Boolean;
         C  : Integer;
      begin
         Run_Command
           ((new String'("-c"),
             new String'("curl -fsSL '" & URL (1 .. URL_Len) & "' -o '" & Tmp & "'")),
            "/dev/null",
            OK,
            C);
         if not OK or else C /= 0 then
            Success := False;
            return;
         end if;
      end;

      declare
         OK : Boolean;
         C  : Integer;
      begin
         Run_Command
           ((new String'("-c"),
             new String'
               ("mkdir -p '" & Dst & "' && tar -xzf '" & Tmp & "' -C '" & Dst & "'")),
            "/dev/null",
            OK,
            C);
         if not OK or else C /= 0 then
            Success := False;
            return;
         end if;
      end;

      Success := True;
   end Download_Toolchain;

   procedure Resolve_GNATprove
     (Exe_Path      : out String;
      Exe_Len       : out Natural;
      Toolchain_Dir : out String;
      Dir_Len       : out Natural;
      Success       : out Boolean)
   is
      Home     : constant String := Home_Dir;
      Toolchain : constant String := Home & Toolchain_Subdir;
      Bin_Dir  : constant String := Toolchain & "/bin";
      Exe      : String_Access;
   begin
      --  Priority 1: a gnatprove already on $PATH.
      Exe := Locate_Exec_On_Path ("gnatprove");
      if Exe /= null then
         Copy_To (Exe_Path, Exe_Len, Exe.all);
         Free (Exe);
         Dir_Len := 0;
         Success := True;
         return;
      end if;

      --  Priority 2: the local toolchain directory.
      if Ada.Directories.Exists (Bin_Dir & Bin_Subdir) then
         Copy_To (Exe_Path, Exe_Len, Bin_Dir & Bin_Subdir);
         Copy_To (Toolchain_Dir, Dir_Len, Bin_Dir);
         Success := True;
         return;
      end if;

      --  Priority 3: download the platform toolchain into ~/.adacovex/toolchain.
      Ada.Text_IO.Put_Line
        ("  gnatprove not found on PATH or in " & Toolchain);
      Ada.Text_IO.Put_Line ("  downloading platform toolchain...");
      declare
         OK : Boolean;
      begin
         Download_Toolchain (OK);
         if not OK then
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "  ERROR: could not download the gnatprove toolchain.");
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "  Install gnatprove, or set ADACOVEX_TOOLCHAIN_URL.");
            Success := False;
            return;
         end if;
      end;

      if Ada.Directories.Exists (Bin_Dir & Bin_Subdir) then
         Copy_To (Exe_Path, Exe_Len, Bin_Dir & Bin_Subdir);
         Copy_To (Toolchain_Dir, Dir_Len, Bin_Dir);
         Success := True;
      else
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "  ERROR: toolchain unpacked but gnatprove missing.");
         Success := False;
      end if;
   end Resolve_GNATprove;

   procedure Find_Root_GPR
     (Target_Dir : String;
      GPR_Path   : out String;
      GPR_Len    : out Natural;
      Success    : out Boolean)
   is
      use Ada.Directories;
      Dir        : constant String := Strip_Trailing_Slash (Target_Dir);
      Found      : Boolean := False;
      First_Name : String (1 .. Types.Max_Filename);
      First_Len  : Natural := 0;
      Ct         : Natural := 0;
      Search     : Search_Type;
      Ent        : Directory_Entry_Type;
   begin
      if not Exists (Dir) or else Kind (Dir) /= Directory then
         Success := False;
         return;
      end if;

      Start_Search (Search, Dir, "*.gpr");
      while More_Entries (Search) loop
         Get_Next_Entry (Search, Ent);
         if Kind (Ent) = Ordinary_File then
            Ct := Ct + 1;
            if Ct = 1 then
               declare
                  N : constant String := Simple_Name (Ent);
               begin
                  if N'Length <= Types.Max_Filename then
                     First_Len := N'Length;
                     for I in 1 .. N'Length loop
                        First_Name (I) := N (I);
                     end loop;
                  end if;
               end;
            end if;
            exit when Ct > 1;
         end if;
      end loop;
      End_Search (Search);

      if Ct = 1 and then First_Len > 0 then
         Copy_To
           (GPR_Path,
            GPR_Len,
            Dir & "/" & First_Name (1 .. First_Len));
         Success := True;
      else
         Success := False;
      end if;
   end Find_Root_GPR;

   procedure Run_Prove (Target_Dir : String; Success : out Boolean) is
      Exe      : String (1 .. Types.Max_Path);
      Exe_Len  : Natural := 0;
      TDir     : String (1 .. Types.Max_Path);
      TLen     : Natural := 0;
      GPR      : String (1 .. Types.Max_Path);
      GLen     : Natural := 0;
      OK       : Boolean;
      Code     : Integer;
      Args     : GNAT.OS_Lib.Argument_List (1 .. 2);
   begin
      Resolve_GNATprove (Exe, Exe_Len, TDir, TLen, OK);
      if not OK then
         Success := False;
         return;
      end if;

      Find_Root_GPR (Target_Dir, GPR, GLen, OK);
      if not OK then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "  ERROR: no root .gpr project file found in " & Target_Dir);
         Success := False;
         return;
      end if;

      Ada.Text_IO.Put_Line
        ("  gnatprove: " & Exe (1 .. Exe_Len));
      Ada.Text_IO.Put_Line ("  project:   " & GPR (1 .. GLen));

      --  Prepend the toolchain bin dir to PATH so gnatprove finds its
      --  solvers (Z3/CVC5/Alt-Ergo) when running from ~/.adacovex/toolchain.
      if TLen > 0 then
         declare
            Old_Path : String_Access := GNAT.OS_Lib.Getenv ("PATH");
            New_Path : constant String :=
              TDir (1 .. TLen)
              & GNAT.OS_Lib.Path_Separator
              & (if Old_Path = null
                then ""
                else Old_Path.all);
         begin
            GNAT.OS_Lib.Setenv ("PATH", New_Path);
            Free (Old_Path);
         end;
      end if;

      Args (1) := new String'("-P");
      Args (2) := new String'(GPR (1 .. GLen));
      Spawn (Exe (1 .. Exe_Len), Args, "/dev/stdout", OK, Code);

      GNAT.OS_Lib.Free (Args (1));
      GNAT.OS_Lib.Free (Args (2));

      if OK and then Code = 0 then
         Success := True;
      else
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "  ERROR: gnatprove exited with code"
            & Integer'Image (Code));
         Success := False;
      end if;
   end Run_Prove;

end Adacovex.Prove;
