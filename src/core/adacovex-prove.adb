with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with Ada.Environment_Variables;
with GNAT.OS_Lib;
with Adacovex;
with Adacovex.CPUs;
with Adacovex.Cache;

package body Adacovex.Prove is

   use GNAT.OS_Lib;
   use Ada.Strings.Fixed;

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

   procedure Copy_To (Dst : out String; Dst_Len : out Natural; Src : String) is
   begin
      Dst_Len := Src'Length;
      for I in Src'Range loop
         Dst (I - Src'First + 1) := Src (I);
      end loop;
   end Copy_To;

   --  Detect the number of logical CPUs on the host.  Delegates to the
   --  cross-platform Adacovex.CPUs implementation (Linux /proc/cpuinfo,
   --  macOS/FreeBSD sysctl, Windows env, fallback 1).
   function Detect_Core_Count return Natural is
   begin
      return Adacovex.CPUs.Detect_Core_Count;
   end Detect_Core_Count;

   --  Combined SHA-256 of everything that determines a gnatprove run: the
   --  root .gpr path, the resolved option string, and the content hash of
   --  every Ada source file under the target (skipping the always-excluded
   --  directories).  Two runs with identical inputs produce the same digest,
   --  so an unchanged project reuses a prior proof via the result cache.
   function Compute_Prove_Input_Hash
     (Target_Dir : String; GPR : String; Options : String) return String
   is
      use Ada.Directories;

      function Skip (Name : String) return Boolean is
      begin
         return
           Name = ".git"
           or else Name = "obj"
           or else Name = "tests"
           or else Name = "config"
           or else Name = ".adacovex";
      end Skip;

      function Walk (Dir : String) return String is
         S    : Search_Type;
         E    : Directory_Entry_Type;
         Hash : String (1 .. 64) := (others => ' ');
         Comb : String (1 .. 64) := (others => ' ');
      begin
         Comb := Adacovex.Cache.Hash_String (Dir & Options);
         if Exists (Dir) and then Kind (Dir) = Directory then
            Start_Search (S, Dir, "");
            while More_Entries (S) loop
               Get_Next_Entry (S, E);
               declare
                  N : constant String := Full_Name (E);
                  K : File_Kind;
               begin
                  K := Kind (N);
                  if K = Directory then
                     if Simple_Name (E) /= "."
                       and then Simple_Name (E) /= ".."
                       and then not Skip (Simple_Name (E))
                     then
                        declare
                           Sub : constant String := Walk (N);
                        begin
                           Comb := Adacovex.Cache.Hash_String (Comb & Sub);
                        end;
                     end if;
                  elsif K = Ordinary_File then
                     declare
                        Ext  : constant String := Simple_Name (E);
                        Last : Natural := Ext'Last;
                     begin
                        while Last >= Ext'First and then Ext (Last) /= '.' loop
                           Last := Last - 1;
                        end loop;
                        if Last >= Ext'First then
                           declare
                              E2 : constant String :=
                                Ext (Last + 1 .. Ext'Last);
                           begin
                              if E2 = "ads" or else E2 = "adb" then
                                 Hash := Adacovex.Cache.Hash_File (N);
                                 Comb :=
                                   Adacovex.Cache.Hash_String (Comb & Hash);
                              end if;
                           end;
                        end if;
                     end;
                  end if;
               end;
            end loop;
            End_Search (S);
         end if;
         return Comb;
      end Walk;

   begin
      return Walk (Target_Dir) & Adacovex.Cache.Hash_String (GPR & Options);
   end Compute_Prove_Input_Hash;

   --  Build the gnatprove option string (without the -P project pair).
   --  Always forwards -j <jobs>; the resolved job count is passed in by the
   --  caller (Opts.Jobs when >= 0, else a detected core count).  The other
   --  switches are appended only when configured, so a default invocation
   --  still parallelizes while remaining minimal.
   function Build_Option_String
     (Opts : Prove_Options; Jobs : Natural) return String
   is
      S : String (1 .. 512);
      P : Natural := 0;

      procedure App (T : String) is
      begin
         if P > 0 then
            P := P + 1;
            S (P) := ' ';
         end if;
         for I in T'Range loop
            P := P + 1;
            S (P) := T (I);
         end loop;
      end App;
   begin
      App ("-j" & Integer'Image (Jobs));
      if Opts.Level >= 0 then
         App ("--level" & Integer'Image (Opts.Level));
      end if;
      if Opts.Timeout >= 0 then
         App ("--timeout" & Integer'Image (Opts.Timeout));
      end if;
      if Opts.Steps >= 0 then
         App ("--steps" & Integer'Image (Opts.Steps));
      end if;
      if Opts.Memlimit >= 0 then
         App ("--memlimit" & Integer'Image (Opts.Memlimit));
      end if;
      if Opts.Force then
         App ("-f");
      end if;
      if Opts.No_Loop_Unrolling then
         App ("--no-loop-unrolling");
      end if;
      if Opts.No_Inlining then
         App ("--no-inlining");
      end if;
      return S (1 .. P);
   end Build_Option_String;

   --  Split a space-separated option string into individual Argument_List
   --  entries (option values never contain spaces).  Appends to Args at N.
   procedure Append_Option_Tokens
     (Args   : in out GNAT.OS_Lib.Argument_List;
      N      : in out Natural;
      Tokens : String)
   is
      Start : Natural := Tokens'First;
   begin
      while Start <= Tokens'Last loop
         while Start <= Tokens'Last and then Tokens (Start) = ' ' loop
            Start := Start + 1;
         end loop;
         exit when Start > Tokens'Last;
         declare
            Stop : Natural := Start;
         begin
            while Stop < Tokens'Last and then Tokens (Stop + 1) /= ' ' loop
               Stop := Stop + 1;
            end loop;
            N := N + 1;
            Args (N) := new String'(Tokens (Start .. Stop));
            Start := Stop + 1;
         end;
      end loop;
   end Append_Option_Tokens;

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

   --  Return the gnatprove version constraint declared in the manifest file
   --  at Path (the `gnatprove = "..."` value inside `[[depends-on]]`), or ""
   --  when the manifest does not declare gnatprove.  A simple TOML scan:
   --  section headers are `[name]` lines and dependency entries are
   --  `name = "version"` lines inside `[[depends-on]]`.  Missing files report
   --  "".  Used to fold the prover identity into the proof result cache key so
   --  a different pinned gnatprove version can never reuse a stale proof.
   function File_GNATprove_Version (Path : String) return String is
      use Ada.Text_IO;
      F          : File_Type;
      In_Depends : Boolean := False;
      Res        : String (1 .. 32);
      RLen       : Natural := 0;
      procedure Emit (S : String) is
      begin
         for I in S'Range loop
            if RLen < Res'Last then
               RLen := RLen + 1;
               Res (RLen) := S (I);
            end if;
         end loop;
      end Emit;
   begin
      if not Ada.Directories.Exists (Path) then
         return "";
      end if;
      Open (F, In_File, Path);
      while not End_Of_File (F) loop
         declare
            Line : constant String := Trim (Get_Line (F), Ada.Strings.Both);
         begin
            if Line'Length > 2
              and then Line (Line'First) = '['
              and then Line (Line'Last) = ']'
            then
               declare
                  Sec_Name : constant String :=
                    Line (Line'First + 1 .. Line'Last - 1);
               begin
                  In_Depends :=
                    Trim (Sec_Name, Ada.Strings.Both) = "depends-on";
                  if not In_Depends
                    and then Sec_Name'Length > 1
                    and then Sec_Name (Sec_Name'First) = '['
                    and then Sec_Name (Sec_Name'Last) = ']'
                  then
                     --  [[depends-on]] array-of-tables form.
                     In_Depends :=
                       Trim
                         (Sec_Name (Sec_Name'First + 1 .. Sec_Name'Last - 1),
                          Ada.Strings.Both)
                       = "depends-on";
                  end if;
               end;
            elsif In_Depends then
               declare
                  Eq : constant Natural := Index (Line, "=");
               begin
                  if Eq > Line'First then
                     declare
                        Name : constant String :=
                          Trim (Line (Line'First .. Eq - 1), Ada.Strings.Both);
                     begin
                        if Name = "gnatprove" then
                           declare
                              Q1 : constant Natural :=
                                Index (Line (Eq .. Line'Last), """");
                              Q2 : Natural := 0;
                           begin
                              if Q1 > 0 then
                                 Q2 :=
                                   Index (Line (Q1 + 1 .. Line'Last), """");
                              end if;
                              if Q1 > 0 and then Q2 > Q1 then
                                 Emit (Line (Q1 + 1 .. Q2 - 1));
                              end if;
                           end;
                           Close (F);
                           return Res (1 .. RLen);
                        end if;
                     end;
                  end if;
               end;
            end if;
         end;
      end loop;
      Close (F);
      return "";
   end File_GNATprove_Version;

   --  True when the manifest file at Path declares a gnatprove dependency in
   --  its `[[depends-on]]` section.  See File_GNATprove_Version for the scan
   --  rules.  Missing files report False.
   function File_Declares_GNATprove (Path : String) return Boolean is
   begin
      return File_GNATprove_Version (Path) /= "";
   end File_Declares_GNATprove;

   --  True when <target>/alire-dev.toml or <target>/alire.toml declares a
   --  gnatprove dependency.  The dev manifest is consulted first because it
   --  extends alire.toml with the proof toolchain for local make targets.
   function Manifest_Declares_GNATprove (Target_Dir : String) return Boolean is
   begin
      return
        File_Declares_GNATprove
          (Strip_Trailing_Slash (Target_Dir) & "/alire-dev.toml")
        or else File_Declares_GNATprove
                  (Strip_Trailing_Slash (Target_Dir) & "/alire.toml");
   end Manifest_Declares_GNATprove;

   --  Download and unpack the platform toolchain bundle into
   --  ~/.adacovex/toolchain/.  Last-resort fallback only: used when neither
   --  an alire-managed gnatprove nor a gnatprove on $PATH nor a cached
   --  toolchain is available.  Uses the ADACOVEX_TOOLCHAIN_URL environment
   --  variable if set, otherwise the default GitHub release asset
   --  adacovex-toolchain-<os>-<arch>.tar.gz from the project's releases.
   procedure Download_Toolchain (Success : out Boolean) is
      Home    : constant String := Home_Dir;
      Dst     : constant String := Home & Toolchain_Subdir;
      Tmp     : constant String := "/tmp/adacovex-toolchain.tar.gz";
      URL     : String (1 .. Types.Max_Path);
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
             new String'
               ("curl -fsSL '" & URL (1 .. URL_Len) & "' -o '" & Tmp & "'")),
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
               ("mkdir -p '"
                & Dst
                & "' && tar -xzf '"
                & Tmp
                & "' -C '"
                & Dst
                & "'")),
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

   --  Strip a version-set expression (`^15.1.0`, `~15.1.0`, `>=16.0.0`,
   --  `15.1.0`) down to the bare numeric version alr accepts on the
   --  `alr get gnatprove=<v>` command line: skip leading operators/spaces,
   --  then take digits and dots up to the first other character.  Returns ""
   --  when no version could be extracted.
   function Bare_Version (Con : String) return String is
      Start : Natural := Con'First;
      I     : Natural := Con'First;
   begin
      while Start <= Con'Last and then Con (Start) not in '0' .. '9' loop
         Start := Start + 1;
      end loop;
      if Start > Con'Last then
         return "";
      end if;
      I := Start;
      while I <= Con'Last
        and then (Con (I) in '0' .. '9' or else Con (I) = '.')
      loop
         I := I + 1;
      end loop;
      return Con (Start .. I - 1);
   end Bare_Version;

   --  Locate a gnatprove crate previously deployed under Root by `alr get`:
   --  a `gnatprove_<version>_<hash>/` directory containing bin/gnatprove.
   --  When Version is non-empty only directories with that exact version
   --  prefix match; when empty, any gnatprove_* crate qualifies (the greatest
   --  name wins -- a later version/hash).  Returns the crate directory.
   procedure Find_Deployed_GNATprove
     (Root    : String;
      Version : String;
      Dir     : out String;
      Dir_Len : out Natural;
      Found   : out Boolean)
   is
      use Ada.Directories;
      Prefix    : constant String :=
        (if Version'Length > 0
         then "gnatprove_" & Version & "_"
         else "gnatprove_");
      Srch      : Search_Type;
      Ent       : Directory_Entry_Type;
      Best_Name : String (1 .. Types.Max_Filename);
      Best_Len  : Natural := 0;
   begin
      Found := False;
      if not Exists (Root) then
         return;
      end if;
      Start_Search (Srch, Root, "gnatprove_*");
      while More_Entries (Srch) loop
         Get_Next_Entry (Srch, Ent);
         if Kind (Ent) = Directory then
            declare
               N : constant String := Simple_Name (Ent);
            begin
               if N'Length > Prefix'Length
                 and then N (N'First .. N'First + Prefix'Length - 1) = Prefix
                 and then Ada.Directories.Exists
                            (Full_Name (Ent) & "/bin/gnatprove")
               then
                  if Best_Len = 0 or else N > Best_Name (1 .. Best_Len) then
                     Best_Len := N'Length;
                     for I in 1 .. N'Length loop
                        Best_Name (I) := N (N'First + I - 1);
                     end loop;
                  end if;
               end if;
            end;
         end if;
      end loop;
      End_Search (Srch);
      if Best_Len > 0 then
         Copy_To (Dir, Dir_Len, Root & "/" & Best_Name (1 .. Best_Len));
         Found := True;
      end if;
   end Find_Deployed_GNATprove;

   --  Deploy ONLY the gnatprove binary crate (a self-contained bundle, no
   --  dependencies) into ~/.adacovex/toolchain/ via
   --  `alr -n get gnatprove=<bare-version>` when the target manifest declares
   --  gnatprove.  The deployed binary -- not the `alr` wrapper -- is what
   --  Run_Prove executes, so no dev-manifest swap and no composition of the
   --  target's whole dependency set is ever needed (the previous `alr exec`
   --  path pulled in covex/gnatdoc_bin/gnatformat_bin etc., whose flaky
   --  downloads could fail CI proof runs).  Idempotent: an existing crate for
   --  the same version is reused without re-running alr, so a restored
   --  toolchain cache never re-downloads.
   procedure Deploy_GNATprove
     (Bare          : String;
      Exe_Path      : out String;
      Exe_Len       : out Natural;
      Toolchain_Dir : out String;
      Dir_Len       : out Natural;
      Success       : out Boolean)
   is
      Home : constant String := Home_Dir;
      Dst  : constant String := Home & Toolchain_Subdir;
      Dir  : String (1 .. Types.Max_Path);
      DLen : Natural := 0;
      OK   : Boolean;
      C    : Integer;
   begin
      Find_Deployed_GNATprove (Dst, Bare, Dir, DLen, Success);
      if Success then
         Copy_To (Exe_Path, Exe_Len, Dir (1 .. DLen) & "/bin/gnatprove");
         Copy_To (Toolchain_Dir, Dir_Len, Dir (1 .. DLen) & "/bin");
         return;
      end if;

      Ada.Directories.Create_Path (Dst);
      Run_Command
        ((new String'("-c"),
          new String'
            ("cd '" & Dst & "' && alr -n get gnatprove='" & Bare & "'")),
         "/dev/null",
         OK,
         C);
      if not OK or else C /= 0 then
         Success := False;
         return;
      end if;
      Find_Deployed_GNATprove (Dst, Bare, Dir, DLen, Success);
      if Success then
         Copy_To (Exe_Path, Exe_Len, Dir (1 .. DLen) & "/bin/gnatprove");
         Copy_To (Toolchain_Dir, Dir_Len, Dir (1 .. DLen) & "/bin");
      end if;
   end Deploy_GNATprove;

   procedure Resolve_GNATprove
     (Target_Dir    : String;
      Exe_Path      : out String;
      Exe_Len       : out Natural;
      Toolchain_Dir : out String;
      Dir_Len       : out Natural;
      Identity      : out String;
      Ident_Len     : out Natural;
      Success       : out Boolean)
   is
      Home      : constant String := Home_Dir;
      Toolchain : constant String := Home & Toolchain_Subdir;
      Bin_Dir   : constant String := Toolchain & "/bin";
      Exe       : String_Access;

      --  Identity is a short fingerprint folded into the proof result-cache
      --  key so proofs from different gnatprove deployments are never mixed:
      --  for the `alr get` deployment path it is the manifest-pinned bare
      --  version; otherwise it is the resolved executable path (which embeds
      --  the version hash for downloaded/cached toolchains and the absolute
      --  path for on-PATH installs).
      procedure Set_Identity (S : String) is
         Max : constant Natural := Natural'Min (S'Length, Identity'Length);
      begin
         Ident_Len := Max;
         for I in 1 .. Max loop
            Identity (I) := S (S'First + I - 1);
         end loop;
      end Set_Identity;
   begin
      Ident_Len := 0;

      --  Priority 1: the target declares gnatprove in alire.toml /
      --  alire-dev.toml -- deploy only that binary crate and run it directly.
      if Manifest_Declares_GNATprove (Target_Dir) then
         declare
            T    : constant String := Strip_Trailing_Slash (Target_Dir);
            Ver  : constant String :=
              File_GNATprove_Version (T & "/alire-dev.toml");
            Con  : constant String :=
              (if Ver'Length > 0
               then Ver
               else File_GNATprove_Version (T & "/alire.toml"));
            Bare : constant String := Bare_Version (Con);
         begin
            if Bare'Length > 0 then
               Deploy_GNATprove
                 (Bare, Exe_Path, Exe_Len, Toolchain_Dir, Dir_Len, Success);
               if Success then
                  Set_Identity ("alr:" & Bare);
                  return;
               end if;
               --  A manifest-declared prover is authoritative: fail the run
               --  rather than silently falling back to a different gnatprove,
               --  because a prover version drift can change which VCs are
               --  discharged (e.g. CI Bronze vs local Platinum on identical
               --  sources).
               Ada.Text_IO.Put_Line
                 (Ada.Text_IO.Standard_Error,
                  "  ERROR: manifest pins gnatprove '"
                  & Bare
                  & "' but it could not be deployed via `alr -n get`;");
               Ada.Text_IO.Put_Line
                 (Ada.Text_IO.Standard_Error,
                  "  refusing to fall back to a different gnatprove.  Install"
                  & " Alire and re-run.");
               Success := False;
               return;
            end if;
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "  ERROR: manifest declares gnatprove with an unparseable"
               & " version expression '"
               & Con
               & "'; refusing to guess which prover to use.");
            Success := False;
            return;
         end;
      end if;

      --  Priority 2: a gnatprove already on $PATH.
      Exe := Locate_Exec_On_Path ("gnatprove");
      if Exe /= null then
         Copy_To (Exe_Path, Exe_Len, Exe.all);
         Free (Exe);
         Dir_Len := 0;
         Set_Identity ("path:" & Exe_Path (1 .. Exe_Len));
         Success := True;
         return;
      end if;

      --  Priority 3: the local toolchain directory -- the download layout
      --  (<toolchain>/bin) or a previously alr-get-deployed gnatprove_* crate.
      if Ada.Directories.Exists (Bin_Dir & Bin_Subdir) then
         Copy_To (Exe_Path, Exe_Len, Bin_Dir & Bin_Subdir);
         Copy_To (Toolchain_Dir, Dir_Len, Bin_Dir);
         Set_Identity ("cache:" & Bin_Dir);
         Success := True;
         return;
      end if;
      declare
         Dir  : String (1 .. Types.Max_Path);
         DLen : Natural := 0;
      begin
         Find_Deployed_GNATprove (Toolchain, "", Dir, DLen, Success);
         if Success then
            Copy_To (Exe_Path, Exe_Len, Dir (1 .. DLen) & "/bin/gnatprove");
            Copy_To (Toolchain_Dir, Dir_Len, Dir (1 .. DLen) & "/bin");
            Set_Identity ("cache:" & Toolchain_Dir (1 .. Dir_Len));
            return;
         end if;
      end;

      --  Priority 4: last resort, download the platform toolchain into
      --  ~/.adacovex/toolchain/.
      Ada.Text_IO.Put_Line
        ("  gnatprove not found via alire, PATH, or " & Toolchain);
      Ada.Text_IO.Put_Line
        ("  last resort: downloading platform toolchain...");
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
               "  Declare gnatprove in your alire.toml, install gnatprove,"
               & " or set ADACOVEX_TOOLCHAIN_URL.");
            Success := False;
            return;
         end if;
      end;

      if Ada.Directories.Exists (Bin_Dir & Bin_Subdir) then
         Copy_To (Exe_Path, Exe_Len, Bin_Dir & Bin_Subdir);
         Copy_To (Toolchain_Dir, Dir_Len, Bin_Dir);
         Set_Identity ("cache:" & Bin_Dir);
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
         Copy_To (GPR_Path, GPR_Len, Dir & "/" & First_Name (1 .. First_Len));
         Success := True;
      else
         Success := False;
      end if;
   end Find_Root_GPR;

   procedure Run_Prove
     (Target_Dir : String; Opts : Prove_Options; Success : out Boolean)
   is
      Exe     : String (1 .. Types.Max_Path);
      Exe_Len : Natural := 0;
      TDir    : String (1 .. Types.Max_Path);
      TLen    : Natural := 0;
      GPR     : String (1 .. Types.Max_Path);
      GLen    : Natural := 0;
      Ident   : String (1 .. Types.Max_Path);
      ILen    : Natural := 0;
      OK      : Boolean;
      Code    : Integer;
      Args    : GNAT.OS_Lib.Argument_List (1 .. 40);
      N       : Natural := 0;
      Jobs    : Natural := 0;
      Options : String (1 .. 512);
      OLen    : Natural := 0;

      --  Build the proof result-cache key.  It must capture everything that
      --  can change the (cached) gnatprove.out: the source tree content, the
      --  .gpr, the options, AND the prover identity.  Folding the prover
      --  identity in means a different gnatprove deployment (pinned version,
      --  on-PATH upgrade, or re-downloaded toolchain) can never reuse a stale
      --  proof from a previous toolchain.  Stale cache entries simply miss and
      --  are transparently re-proved, so no explicit cache invalidation is
      --  needed when the toolchain changes.
      function Prove_Cache_Key return String is
      begin
         return
           "prove:"
           & Adacovex.Cache.Hash_String
               (Ident (1 .. ILen)
                & ASCII.NUL
                & Compute_Prove_Input_Hash
                    (Strip_Trailing_Slash (Target_Dir),
                     GPR (1 .. GLen),
                     Options (1 .. OLen)));
      end Prove_Cache_Key;
   begin
      Resolve_GNATprove
        (Target_Dir, Exe, Exe_Len, TDir, TLen, Ident, ILen, OK);
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

      --  Resolve the parallelism.  Default (Opts.Jobs < 0) uses
      --  max(1, cores-2) on a developer machine but all cores inside CI;
      --  --jobs=0 means all cores; --jobs=N pins N processes.  The chosen
      --  basis is printed so the run is auditable ("which check is
      --  justified" by the environment).
      Jobs :=
        Adacovex.CPUs.Resolve_Jobs (Opts.Jobs, Adacovex.CPUs.Is_Running_In_CI);
      Copy_To (Options, OLen, Build_Option_String (Opts, Jobs));

      Ada.Text_IO.Put_Line ("  gnatprove: " & Exe (1 .. Exe_Len));
      Ada.Text_IO.Put_Line ("  project:   " & GPR (1 .. GLen));
      Ada.Text_IO.Put_Line ("  options:   " & Options (1 .. OLen));
      Ada.Text_IO.Put_Line
        ("  jobs:      "
         & Adacovex.CPUs.Jobs_Justification
             (Opts.Jobs,
              Adacovex.CPUs.Detect_Core_Count,
              Adacovex.CPUs.Is_Running_In_CI));

      --  Result-cache short-circuit: if the exact set of inputs (source tree
      --  content + .gpr + options) has been proved before, reuse the prior
      --  gnatprove.out instead of re-running the prover.  This is the single
      --  biggest CI speedup: an unchanged project serves the proof from disk.
      if Opts.Cache then
         declare
            In_Hash : constant String := Prove_Cache_Key;
            Dst     : String (1 .. Types.Max_Path);
            DLen    : Natural := 0;
            Hit     : Boolean := Adacovex.Cache.Exists (In_Hash);
            pragma Unreferenced (Dst, DLen);
         begin
            if Hit then
               Ada.Text_IO.Put_Line
                 ("  cache:     gnatprove inputs unchanged -- reusing prior"
                  & " proof (gnatprove.out served from cache)");
               Success := True;
               return;
            end if;
         end;
      end if;

      --  Resolve_GNATprove always returns a directly-executable gnatprove binary
      --  (the `alr get` deployment path runs the deployed binary itself, never
      --  the alr wrapper), so there is exactly one spawn shape.  Prepend the
      --  toolchain bin dir to PATH so gnatprove finds its solvers
      --  (Z3/CVC5/Alt-Ergo), which live in the deployment's bin/libexec dirs.
      if TLen > 0 then
         declare
            Old_Path : String_Access := GNAT.OS_Lib.Getenv ("PATH");
            New_Path : constant String :=
              TDir (1 .. TLen)
              & GNAT.OS_Lib.Path_Separator
              & (if Old_Path = null then "" else Old_Path.all);
         begin
            GNAT.OS_Lib.Setenv ("PATH", New_Path);
            Free (Old_Path);
         end;
      end if;

      Args (1) := new String'("-P");
      Args (2) := new String'(GPR (1 .. GLen));
      N := 2;
      Append_Option_Tokens (Args, N, Options (1 .. OLen));
      Spawn (Exe (1 .. Exe_Len), Args (1 .. N), "/dev/stdout", OK, Code);
      for I in 1 .. N loop
         GNAT.OS_Lib.Free (Args (I));
      end loop;

      if OK and then Code = 0 then
         Success := True;
         if Opts.Cache then
            declare
               In_Hash : constant String := Prove_Cache_Key;
               OK2     : Boolean;
            begin
               Adacovex.Cache.Store (In_Hash, "1", OK2);
               if OK2 then
                  Ada.Text_IO.Put_Line
                    ("  cache:     gnatprove result cached for these inputs");
               end if;
            end;
         end if;
      else
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "  ERROR: gnatprove exited with code" & Integer'Image (Code));
         Success := False;
      end if;
   end Run_Prove;

end Adacovex.Prove;
