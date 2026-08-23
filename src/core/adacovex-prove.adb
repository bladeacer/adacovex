with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Ada.Environment_Variables;
with GNAT.OS_Lib;
with Adacovex;
with Adacovex.CPUs;
with Adacovex.Cache;
with Adacovex.VCS;
with Adacovex.Prove_Patch;

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
      declare
         P : constant String := Adacovex.Prove_Patch.Patches_Hash (Target_Dir);
      begin
         if P'Length > 0 then
            --  Proof patches change what gnatprove sees (the patched spec
            --  copies), so a patch edit must invalidate the cached proof.
            return
              Walk (Target_Dir)
              & Adacovex.Cache.Hash_String (GPR & Options & P);
         end if;
      end;
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
      else
         --  Default proof budget, well above gnatprove's own step limit, so
         --  solver-timeout false negatives are not reported as unproved.
         --  An explicit --steps=... always overrides this default.  Raised
         --  from 5000 to 10000 in 1.10.0 when the multi-standard type layer
         --  grew the proof surface; 5000 sat on the solver's non-determinism
         --  boundary and intermittently left a trivial string contract
         --  unproved.
         App ("--steps 10000");
      end if;
      if Opts.Memlimit >= 0 then
         App ("--memlimit" & Integer'Image (Opts.Memlimit));
      end if;
      if Opts.Force then
         App ("-f");
      end if;
      --  Loop unrolling is always disabled: GNATprove emits the purely
      --  informational "cannot unroll loop (too many loop iterations)"
      --  notice for loops it would like to unroll but cannot, which is
      --  noise in every proof run (e.g. Ada_CRDT's Find_Actor / LEB128
      --  loops and generic instantiations).  Disabling unrolling removes
      --  the notice entirely and is proof-neutral for the dogfood targets
      --  (720/720 adacovex and 589/589 Ada_CRDT VCs, 0 unproved).
      App ("--no-loop-unrolling");
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
     (Target_Dir     : String;
      Pinned_Version : String;
      Exe_Path       : out String;
      Exe_Len        : out Natural;
      Toolchain_Dir  : out String;
      Dir_Len        : out Natural;
      Identity       : out String;
      Ident_Len      : out Natural;
      Success        : out Boolean)
   is
      Home      : constant String := Home_Dir;
      Toolchain : constant String := Home & Toolchain_Subdir;
      Bin_Dir   : constant String := Toolchain & "/bin";
      Exe       : String_Access;

      --  Identity is a short fingerprint folded into the proof result-cache
      --  key so proofs from different gnatprove deployments are never mixed:
      --  for the `alr get` deployment path it is the pinned version;
      --  otherwise it is the resolved executable path (which embeds the
      --  version hash for downloaded/cached toolchains and the absolute path
      --  for on-PATH installs).
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

      --  Priority 2: a global gnatprove version pin (the
      --  ADACOVEX_GNATPROVE_VERSION environment variable or the
      --  `[prove] gnatprove-version` key in ~/.adacovex/adacovex.toml, read by
      --  Global_GNATprove_Pin): deploy ONLY that gnatprove version and run it
      --  directly.  Authoritative -- a failure to deploy the pinned version is
      --  a failure to run, because a different gnatprove can change which VCs
      --  are discharged (results must always come from the pinned prover, and
      --  reproducibility is the whole point of pinning).  The manifest pin
      --  above always wins; this applies only to projects that do not declare
      --  gnatprove themselves.
      if Pinned_Version'Length > 0 then
         declare
            Bare : constant String := Bare_Version (Pinned_Version);
         begin
            if Bare'Length = 0 then
               Ada.Text_IO.Put_Line
                 (Ada.Text_IO.Standard_Error,
                  "  ERROR: global gnatprove pin '"
                  & Pinned_Version
                  & "' is not a parseable gnatprove version.");
               Success := False;
               return;
            end if;
            Deploy_GNATprove
              (Bare, Exe_Path, Exe_Len, Toolchain_Dir, Dir_Len, Success);
            if not Success then
               Ada.Text_IO.Put_Line
                 (Ada.Text_IO.Standard_Error,
                  "  ERROR: global gnatprove pin '"
                  & Bare
                  & "' could not be deployed via `alr -n get`; refusing to "
                  & "fall back to a different gnatprove.  Install Alire and "
                  & "re-run.");
               return;
            end if;
            Set_Identity ("alr:" & Bare);
            return;
         end;
      end if;

      --  Priority 3: a gnatprove already on $PATH.
      Exe := Locate_Exec_On_Path ("gnatprove");
      if Exe /= null then
         Copy_To (Exe_Path, Exe_Len, Exe.all);
         Free (Exe);
         Dir_Len := 0;
         Set_Identity ("path:" & Exe_Path (1 .. Exe_Len));
         Success := True;
         return;
      end if;

      --  Priority 4: the local toolchain directory -- the download layout
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

      --  Priority 5: last resort, download the platform toolchain into
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

   --  Read the global gnatprove version pin -- the version Run_Prove passes to
   --  Resolve_GNATprove for projects that do not declare gnatprove in their
   --  own manifest.  Empty means "no global pin" (fall back to PATH / cache /
   --  download).  Priority: the ADACOVEX_GNATPROVE_VERSION environment
   --  variable, then the `[prove] gnatprove-version = "X.Y.Z"` key in
   --  ~/.adacovex/adacovex.toml.  The returned value is clamped to
   --  Types.Max_Id_Str like every other CLI/config string.
   function Global_GNATprove_Pin return String is
      use Ada.Text_IO;
      Buf  : String (1 .. Types.Max_Id_Str);
      BLen : Natural := 0;
   begin
      if Ada.Environment_Variables.Exists ("ADACOVEX_GNATPROVE_VERSION") then
         declare
            V : constant String :=
              Ada.Environment_Variables.Value ("ADACOVEX_GNATPROVE_VERSION");
         begin
            if V'Length > 0 then
               for I in V'Range loop
                  if BLen < Buf'Last then
                     BLen := BLen + 1;
                     Buf (BLen) := V (I);
                  end if;
               end loop;
               return Buf (1 .. BLen);
            end if;
         end;
      end if;

      declare
         F        : File_Type;
         In_Prove : Boolean := False;
      begin
         if not Ada.Directories.Exists (Home_Dir & "/.adacovex/adacovex.toml")
         then
            return "";
         end if;
         Open (F, In_File, Home_Dir & "/.adacovex/adacovex.toml");
         while not End_Of_File (F) loop
            declare
               Line : constant String := Trim (Get_Line (F), Ada.Strings.Both);
            begin
               if Line'Length > 2
                 and then Line (Line'First) = '['
                 and then Line (Line'Last) = ']'
                 and then Trim
                            (Line (Line'First + 1 .. Line'Last - 1),
                             Ada.Strings.Both)
                          = "prove"
               then
                  In_Prove := True;
               elsif Line'Length > 0 and then Line (Line'First) = '[' then
                  In_Prove := False;
               elsif In_Prove then
                  declare
                     Eq : constant Natural := Index (Line, "=");
                  begin
                     if Eq > Line'First then
                        declare
                           Name : constant String :=
                             Trim
                               (Line (Line'First .. Eq - 1), Ada.Strings.Both);
                        begin
                           if Name = "gnatprove-version" then
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
                                    Close (F);
                                    return Line (Q1 + 1 .. Q2 - 1);
                                 end if;
                              end;
                           end if;
                        end;
                     end if;
                  end;
               end if;
            end;
         end loop;
         Close (F);
         return "";
      end;
   end Global_GNATprove_Pin;

   --  Replay a captured gnatprove output file to stdout, dropping the
   --  suppressed informational-message blocks.  Sets is a comma-separated
   --  list of suppression-set names (empty = the default set,
   --  "unrolling-inlining"); a set name S suppresses every message block
   --  carrying the `[info-S]` tag (or a bare `[S]` tag) -- purely
   --  informational notices, the proof outcome is unaffected.  A block
   --  appears in two shapes:
   --
   --     info: cannot unroll loop (too many loop iterations) [info-unrolling-inlining]
   --    --> crdt-core-leb128.adb:28:51
   --
   --  and, inside generic instantiations:
   --
   --     info: in instantiation at crdt-lww_sets.adb:19
   --    --> proof_instantiations.ads:37:04
   --          + cannot unroll loop (too many loop iterations) [info-unrolling-inlining]
   --
   --  A small FIFO buffers the header lines ("info:" + "-->" location) so
   --  the whole block -- tag line, header, and any "+" sub-message -- is
   --  dropped together; every other gnatprove line (checks, summary,
   --  warnings) passes through untouched.
   procedure Replay_Suppressed (Path : String; Sets : String) is
      use Ada.Text_IO;
      use Ada.Strings.Fixed;

      Max_Line : constant Natural := 1024;
      --  Suppression-set names, parsed from the comma-separated Sets string
      --  (empty => the single default set "unrolling-inlining").
      Max_Sets : constant := 8;
      type Set_Array is array (1 .. Max_Sets) of String (1 .. 64);
      Set_Bufs : Set_Array;
      Set_Lens : array (1 .. Max_Sets) of Natural := (others => 0);
      Set_Ct   : Natural := 0;

      type Line_Array is array (1 .. 4) of String (1 .. Max_Line);
      Bufs      : Line_Array;
      Lens      : array (1 .. 4) of Natural := (others => 0);
      Ct        : Natural := 0;
      Skip_Cont : Boolean := False;
      F         : File_Type;

      --  First non-blank character of S (' ' when S is blank).
      function Head (S : String) return Character is
      begin
         for I in S'Range loop
            if S (I) not in ' ' | ASCII.HT then
               return S (I);
            end if;
         end loop;
         return ' ';
      end Head;

      --  True when S (trimmed) starts with Prefix.
      function Starts (S : String; Prefix : String) return Boolean is
         T : constant String := Trim (S, Ada.Strings.Both);
      begin
         return
           T'Length >= Prefix'Length
           and then T (T'First .. T'First + Prefix'Length - 1) = Prefix;
      end Starts;

      --  Queue S for later output, flushing the oldest line once full.
      procedure Push (S : String) is
         L : constant Natural := Natural'Min (S'Length, Max_Line);
      begin
         if Ct = 4 then
            Put_Line (Bufs (1) (1 .. Lens (1)));
            for I in 1 .. 3 loop
               Bufs (I) := Bufs (I + 1);
               Lens (I) := Lens (I + 1);
            end loop;
            Ct := 3;
         end if;
         Ct := Ct + 1;
         Lens (Ct) := L;
         for I in 1 .. L loop
            Bufs (Ct) (I) := S (S'First + I - 1);
         end loop;
      end Push;

      --  True when L carries a suppressed tag: `[info-<Set>]` or `[<Set>]`
      --  for any configured set name.
      function Is_Suppressed (L : String) return Boolean is
      begin
         for I in 1 .. Set_Ct loop
            declare
               S : constant String := Set_Bufs (I) (1 .. Set_Lens (I));
            begin
               if Index (L, "[info-" & S & "]") > 0
                 or else Index (L, "[" & S & "]") > 0
               then
                  return True;
               end if;
            end;
         end loop;
         return False;
      end Is_Suppressed;
   begin
      --  Parse the comma-separated set list; empty => default set.
      declare
         T     : constant String :=
           (if Sets'Length = 0 then "unrolling-inlining" else Sets);
         Start : Natural := T'First;
      begin
         for I in T'First .. T'Last + 1 loop
            if I > T'Last or else T (I) = ',' then
               if I > Start and then Set_Ct < Max_Sets then
                  Set_Ct := Set_Ct + 1;
                  declare
                     Len : constant Natural := I - Start;
                  begin
                     Set_Lens (Set_Ct) := Natural'Min (Len, 64);
                     for J in 1 .. Set_Lens (Set_Ct) loop
                        Set_Bufs (Set_Ct) (J) := T (Start + J - 1);
                     end loop;
                  end;
               end if;
               Start := I + 1;
            end if;
         end loop;
      end;
      if Set_Ct = 0 then
         Set_Lens (1) := 1;
         Set_Bufs (1) (1) := ' ';  --  no sets parsed: suppress nothing
         Set_Ct := 1;
      end if;

      Open (F, In_File, Path);
      while not End_Of_File (F) loop
         declare
            L : constant String := Get_Line (F);
         begin
            if Is_Suppressed (L) then
               --  Tagged line: drop it.  For a "+" sub-message (the
               --  in-instantiation shape) also drop its "info:" + "-->"
               --  header pair that is still waiting in the buffer.
               if Head (L) = '+' and then Ct >= 2 then
                  if Starts (Bufs (Ct) (1 .. Lens (Ct)), "-->")
                    and then Starts
                               (Bufs (Ct - 1) (1 .. Lens (Ct - 1)), "info:")
                  then
                     Ct := Ct - 2;
                  end if;
               end if;
               Skip_Cont := True;
            elsif Skip_Cont and then (Head (L) = '-' or else Head (L) = '+')
            then
               --  Location / sub-message continuation of a suppressed block.
               null;
            else
               Skip_Cont := False;
               Push (L);
            end if;
         end;
      end loop;
      while Ct > 0 loop
         Put_Line (Bufs (1) (1 .. Lens (1)));
         for I in 1 .. Ct - 1 loop
            Bufs (I) := Bufs (I + 1);
            Lens (I) := Lens (I + 1);
         end loop;
         Ct := Ct - 1;
      end loop;
      Close (F);
   end Replay_Suppressed;

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
      Vers    : String (1 .. Types.Max_Id_Str);
      VLen    : Natural := 0;
      OK      : Boolean;
      Code    : Integer;
      Args    : GNAT.OS_Lib.Argument_List (1 .. 40);
      N       : Natural := 0;
      Jobs    : Natural := 0;
      Options : String (1 .. 512);
      OLen    : Natural := 0;

      --  True when proof patches were applied and gnatprove ran against the
      --  patched proof tree instead of the target itself.  When set, the
      --  freshly generated gnatprove.out is copied back to the canonical
      --  <target>/obj/gnatprove/ path after a successful run so the
      --  assessment pipeline finds it.
      GPR_Patched : Boolean := False;

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
      declare
         Pin : constant String := Global_GNATprove_Pin;
      begin
         VLen := Natural'Min (Pin'Length, Vers'Length);
         for I in 1 .. VLen loop
            Vers (I) := Pin (Pin'First + I - 1);
         end loop;
      end;
      Resolve_GNATprove
        (Target_Dir,
         Vers (1 .. VLen),
         Exe,
         Exe_Len,
         TDir,
         TLen,
         Ident,
         ILen,
         OK);
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

      --  Proof patches (SPARK aspects carried by .adacovex/patches files)
      --  make the vendored specs part of the proof: build a patched copy of
      --  the target tree (with the merged specs in place) and run gnatprove
      --  against the copy's root project.  The copy lives under the
      --  target's obj/ (excluded from scanning and hashing) and preserves
      --  the original project structure exactly, so the target's own units
      --  analyze identically -- only the patched vendored specs differ.
      --  A target with no proof patches is proved against its own tree as
      --  before.
      declare
         PCount : constant Natural :=
           Adacovex.Prove_Patch.Count_Proof_Patches (Target_Dir);
      begin
         if PCount > 0 then
            declare
               CDir  : String (1 .. Types.Max_Path);
               CDLen : Natural := 0;
               CGPR  : String (1 .. Types.Max_Path);
               CGLen : Natural := 0;
            begin
               Adacovex.Prove_Patch.Build_Patched_Copy
                 (Target_Dir, GPR (1 .. GLen), CDir, CDLen, CGPR, CGLen, OK);
               if not OK then
                  Ada.Text_IO.Put_Line
                    (Ada.Text_IO.Standard_Error,
                     "  ERROR: could not build the patched proof tree for"
                     & " proof patches under .adacovex/patches/");
                  Success := False;
                  return;
               end if;
               Ada.Text_IO.Put_Line
                 ("  proof patches:"
                  & Natural'Image (PCount)
                  & " vendored source(s) patched (proof tree: "
                  & CDir (1 .. CDLen)
                  & ")");
               GLen := CGLen;
               for I in 1 .. CGLen loop
                  GPR (I) := CGPR (I);
               end loop;
               GPR_Patched := True;
            end;
         end if;
      end;

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
      if Opts.Suppress_Warnings then
         --  Capture gnatprove's combined output, replay it to stdout with
         --  the configured suppression sets (default: the
         --  [info-unrolling-inlining] blocks) filtered out, then remove the
         --  capture file.  The summary / check results always pass through
         --  -- only the benign info notices are hidden.  Output appears
         --  once the run finishes (no live tail) -- quiet is the default
         --  for local runs, never for --verbose or CI (which passes
         --  --verbose).
         declare
            Fd  : GNAT.OS_Lib.File_Descriptor;
            Tmp : GNAT.OS_Lib.String_Access;
         begin
            GNAT.OS_Lib.Create_Temp_File (Fd, Tmp);
            GNAT.OS_Lib.Close (Fd);
            Spawn
              (Exe (1 .. Exe_Len),
               Args (1 .. N),
               Tmp.all,
               OK,
               Code,
               Err_To_Out => True);
            if Ada.Directories.Exists (Tmp.all) then
               Replay_Suppressed
                 (Tmp.all,
                  Ada.Strings.Unbounded.To_String (Opts.Suppress_Sets));
               declare
                  Del_OK : Boolean;
               begin
                  GNAT.OS_Lib.Delete_File (Tmp.all, Del_OK);
               end;
            end if;
            GNAT.OS_Lib.Free (Tmp);
         end;
      else
         Spawn (Exe (1 .. Exe_Len), Args (1 .. N), "/dev/stdout", OK, Code);
      end if;
      for I in 1 .. N loop
         GNAT.OS_Lib.Free (Args (I));
      end loop;

      if OK and then Code = 0 then
         Success := True;
         --  The patched proof tree generated the .out; copy it to the
         --  canonical <target>/obj/gnatprove/ path the assessment pipeline
         --  parses (the copy itself lives under the target's obj/ and is
         --  never scanned or hashed).
         if GPR_Patched then
            declare
               C1      : Boolean;
               C2      : Integer;
               Slash   : Natural := GLen;
               Suffix  : constant String := "obj/gnatprove/gnatprove.out";
               Src_Out : String (1 .. Types.Max_Path);
               Src_Len : Natural := 0;
            begin
               --  The proof result lives in the patched tree's own object
               --  dir: <copy>/obj/gnatprove/gnatprove.out (the copy's root
               --  project path is <copy>/<basename>.gpr).
               while Slash > 1 and then GPR (Slash) /= '/' loop
                  Slash := Slash - 1;
               end loop;
               Src_Len := Slash + Suffix'Length;
               for I in 1 .. Slash - 1 loop
                  Src_Out (I) := GPR (I);
               end loop;
               Src_Out (Slash) := '/';
               for I in Suffix'Range loop
                  Src_Out (Slash + 1 + (I - Suffix'First)) := Suffix (I);
               end loop;
               Run_Command
                 ((new String'("-c"),
                   new String'
                     ("mkdir -p '"
                      & Target_Dir
                      & "/obj/gnatprove' && cp -f '"
                      & Src_Out (1 .. Src_Len)
                      & "' '"
                      & Target_Dir
                      & "/obj/gnatprove/gnatprove.out'")),
                  "/dev/null",
                  C1,
                  C2);
               if not C1 or else C2 /= 0 then
                  Ada.Text_IO.Put_Line
                    (Ada.Text_IO.Standard_Error,
                     "  ERROR: could not copy the proof result to "
                     & Target_Dir
                     & "/obj/gnatprove/gnatprove.out");
               end if;
            end;
         end if;
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

   --  Report the availability of a VCS command-line tool on PATH (used by
   --  Run_Status's vcs section): "found (/path)" or "not found".
   procedure Status_VCS_Row (Label : String; Tool : String) is
      Exe : String_Access := Locate_Exec_On_Path (Tool);
   begin
      if Exe /= null then
         Ada.Text_IO.Put_Line
           ("    "
            & Label
            & (1 .. (19 - Label'Length) => ' ')
            & "found ("
            & Exe.all
            & ")");
         Free (Exe);
      else
         Ada.Text_IO.Put_Line
           ("    " & Label & (1 .. (19 - Label'Length) => ' ') & "not found");
      end if;
   end Status_VCS_Row;

   procedure Run_Status (Target_Dir : String; Success : out Boolean) is
      T           : constant String := Strip_Trailing_Slash (Target_Dir);
      Alr         : String_Access := Locate_Exec_On_Path ("alr");
      Gnatprove   : String_Access := Locate_Exec_On_Path ("gnatprove");
      Declared    : constant Boolean := Manifest_Declares_GNATprove (T);
      Pin         : constant String := Global_GNATprove_Pin;
      Toolchain   : constant String := Home_Dir & Toolchain_Subdir;
      Cached_Dir  : String (1 .. Types.Max_Path);
      Cached_Len  : Natural := 0;
      Cached      : Boolean := False;
      Cores       : constant Natural := Adacovex.CPUs.Detect_Core_Count;
      In_CI       : constant Boolean := Adacovex.CPUs.Is_Running_In_CI;
      Needs_Alr   : constant Boolean := Declared or else Pin'Length > 0;
      Gnat_Usable : constant Boolean :=
        Gnatprove /= null
        or else Cached
        or else Declared
        or else Pin'Length > 0;
      Alr_Ok      : constant Boolean := Alr /= null or else not Needs_Alr;

      --  Print a name/value pair; Name carries the full indentation + label.
      procedure Row (Name : String; Value : String) is
      begin
         Ada.Text_IO.Put_Line (Name & Value);
      end Row;
   begin
      Find_Deployed_GNATprove (Toolchain, "", Cached_Dir, Cached_Len, Cached);

      Ada.Text_IO.Put_Line ("adacovex v" & Adacovex.Version & " status");
      Ada.Text_IO.Put_Line ("  target:             " & T);

      --  Alire: only required when the manifest or a global pin drives the
      --  `alr -n get` deployment path; otherwise gnatprove on PATH / cache
      --  suffices.
      if Alr /= null then
         Row ("  alire:              installed (", Alr.all & ")");
      else
         Row
           ("  alire:              NOT FOUND on PATH",
            (if Needs_Alr then " (required: manifest/global pin)" else ""));
      end if;

      --  gnatprove detectability across the resolution tiers, without
      --  downloading anything.
      Ada.Text_IO.Put_Line ("  gnatprove:");
      if Declared then
         declare
            Ver  : constant String :=
              File_GNATprove_Version (T & "/alire-dev.toml");
            Ver2 : constant String :=
              File_GNATprove_Version (T & "/alire.toml");
            Con  : constant String := (if Ver'Length > 0 then Ver else Ver2);
         begin
            Row
              ("    manifest pin:     ",
               (if Con'Length > 0 then Con else "declared"));
         end;
      else
         Row ("    manifest pin:     none", "");
      end if;
      Row
        ("    global pin:        ", (if Pin'Length > 0 then Pin else "none"));
      if Gnatprove /= null then
         Row ("    on PATH:           ", Gnatprove.all);
      else
         Row ("    on PATH:           not found", "");
      end if;
      if Cached then
         Row ("    toolchain cache:   ", Cached_Dir (1 .. Cached_Len));
      else
         Row ("    toolchain cache:   empty", "");
      end if;

      --  Platform support / parallelism basis.
      Ada.Text_IO.Put_Line ("  platform:");
      Row
        ("    logical CPUs:      ",
         Natural'Image (Cores) (2 .. Natural'Image (Cores)'Last));
      Row ("    CI environment:    ", (if In_CI then "yes" else "no"));
      Row
        ("    prove -j default:  ",
         Adacovex.CPUs.Jobs_Justification (-1, Cores, In_CI));

      --  VCS support: which VCS tools are available for the differential
      --  modes (--compare-base / --coverage-delta), the VCS managing the
      --  target repo, and a warning when the target's VCS tool is missing.
      Ada.Text_IO.Put_Line ("  vcs:");
      Status_VCS_Row ("git", "git");
      Status_VCS_Row ("mercurial", "hg");
      Status_VCS_Row ("subversion", "svn");
      Status_VCS_Row ("fossil", "fossil");
      Status_VCS_Row ("jj", "jj");
      Status_VCS_Row ("man page tool", "mandb");
      declare
         Mandb : String_Access := Locate_Exec_On_Path ("mandb");
      begin
         if Mandb = null then
            Ada.Text_IO.Put_Line
              ("    note: man-db (mandb) is not on PATH; `adacovex man`");
            Ada.Text_IO.Put_Line
              ("          still installs the page but cannot refresh the");
            Ada.Text_IO.Put_Line
              ("          man database (read it with `man -l`).");
         else
            Free (Mandb);
         end if;
      end;
      declare
         Kind  : constant Adacovex.VCS.VCS_Kind := Adacovex.VCS.Detect (T);
         KName : constant String := Adacovex.VCS.To_String (Kind);
         Need  : constant String := Adacovex.VCS.Tool_Name (Kind);
      begin
         Row
           ("    target repo:       ",
            (if KName'Length > 0 then KName else "none detected"));
         if KName'Length > 0 and then Need'Length > 0 then
            declare
               Exe : String_Access := Locate_Exec_On_Path (Need);
            begin
               if Exe = null then
                  Ada.Text_IO.Put_Line
                    ("    note: '" & Need & "' is not on PATH; differential");
                  Ada.Text_IO.Put_Line
                    ("          modes (--compare-base / --coverage-delta)");
                  Ada.Text_IO.Put_Line
                    ("          need it to snapshot base revisions.");
               end if;
               if Exe /= null then
                  Free (Exe);
               end if;
            end;
         end if;
      end;

      Ada.Text_IO.Put_Line
        ("  release note: CI release binary is Linux x86-64 only for now");

      Free (Alr);
      Free (Gnatprove);

      Success := Gnat_Usable and then Alr_Ok;
      if Success then
         Ada.Text_IO.Put_Line
           ("  => OK (alr + gnatprove available or dependency-managed)");
      else
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "  => FAIL: gnatprove not detectable without a download"
            & (if not Alr_Ok
               then " (and alr is required but missing)"
               else ""));
      end if;
   end Run_Status;

end Adacovex.Prove;
