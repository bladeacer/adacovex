with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Ada.Environment_Variables;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with GNAT.OS_Lib;
with Adacovex;
with Adacovex.Ansi;
with Adacovex.CPUs;
with Adacovex.Timezones;
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

   --  Normalise a trailing '/' off a directory path.
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

      --  Always-excluded directories for the proof-input walk.  The walk
      --  hashes every .ads/.adb under the target on every prove run (cold
      --  or warm), so its skip set must cover every directory that cannot
      --  hold project proof units: VCS metadata, build/proof outputs,
      --  installer and doc trees, vendored dependency stores, and Python
      --  virtual environments (a .venv mirrors the requirements*.txt
      --  declared packages in thousands of installed files that are never
      --  part of the proof surface).
      function Skip (Name : String) return Boolean is
      begin
         return
           Name = ".git"
           or else Name = ".jj"
           or else Name = ".hg"
           or else Name = ".svn"
           or else Name = ".fslckout"
           or else Name = "_FOSSIL_"
           or else Name = "obj"
           or else Name = "bin"
           or else Name = "tests"
           or else Name = "config"
           or else Name = ".adacovex"
           or else Name = "alire"
           or else Name = "gnatprove"
           or else Name = "__pycache__"
           or else Name = "node_modules"
           or else Name = ".venv"
           or else Name = ".headroom"
           or else Name = ".lccst"
           or else Name = "_build"
           or else Name = "dist"
           or else Name = "index"
           or else Name = "resources"
           or else Name = "docs";
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
                  --  Kind (E) reuses the dirent data readdir already
                  --  fetched; Kind (N) would stat the path again.
                  K : constant File_Kind := Kind (E);
               begin
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
      Prog : String_Access :=
        Locate_Exec_On_Path (Adacovex.CPUs.Get_Shell_Command);
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
      Tmp     : constant String :=
        Adacovex.CPUs.Get_Temp_Directory & "/adacovex-toolchain.tar.gz";
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

      --  First deployment of this gnatprove version: alr downloads a
      --  ~130 MB toolchain bundle and unpacks it, which can take a minute
      --  on a slow link.  Say so up front -- a silent minute of nothing
      --  looks like a hang.  The deployment is one-time per version: every
      --  later run reuses the deployed crate above without any download.
      Ada.Text_IO.Put_Line
        ("  deploy:    gnatprove "
         & Bare
         & " not in ~/.adacovex/toolchain -- downloading via alr"
         & " (one-time, may take a minute)...");
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

      --  Namespace the cached gnatprove.out *content* under the input hash.
      --  Two blobs are stored per proved input: the "1" marker under the
      --  bare input hash (a cheap hit probe) and the summary text under this
      --  derived key.  A warm hit restores the summary the assessment
      --  pipeline parses even when obj/gnatprove/ was wiped.
      function Proof_Output_Key (Input_Hash : String) return String is
      begin
         return "proveout:" & Input_Hash;
      end Proof_Output_Key;

      --  Write the cached gnatprove.out content back to the canonical path
      --  the assessment pipeline parses (<target>/obj/gnatprove/gnatprove.out)
      --  when the cached summary exists.  A no-op (silently) when the
      --  summary blob is missing, oversized, or the write fails -- the
      --  pipeline then reports Stone/0-VC exactly as before this restore
      --  existed, never a corrupt summary.
      procedure Restore_Proof_Output (Dir : String; Input_Hash : String) is
         Blob     : String (1 .. Adacovex.Cache.Max_Cache_Blob);
         BLen     : Natural := 0;
         Found    : Boolean := False;
         Out_Path : constant String :=
           Strip_Trailing_Slash (Dir) & "/obj/gnatprove/gnatprove.out";
      begin
         Adacovex.Cache.Get_Cached
           (Proof_Output_Key (Input_Hash), Blob, BLen, Found);
         if not Found or else BLen = 0 then
            return;
         end if;
         declare
            use Ada.Streams.Stream_IO;
            F   : File_Type;
            SEA :
              Ada.Streams.Stream_Element_Array
                (0 .. Ada.Streams.Stream_Element_Offset (BLen - 1));
         begin
            Ada.Directories.Create_Path
              (Strip_Trailing_Slash (Dir) & "/obj/gnatprove");
            if Ada.Directories.Exists (Out_Path) then
               Ada.Directories.Delete_File (Out_Path);
            end if;
            Create (F, Out_File, Out_Path);
            for I in 1 .. BLen loop
               SEA (Ada.Streams.Stream_Element_Offset (I - 1)) :=
                 Ada.Streams.Stream_Element (Character'Pos (Blob (I)));
            end loop;
            Write (F, SEA);
            Close (F);
         exception
            when others =>
               if Is_Open (F) then
                  Close (F);
               end if;
         end;
      end Restore_Proof_Output;
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
      --  analyse identically -- only the patched vendored specs differ.
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
      --  content + .gpr + options) has been proved before, restore the prior
      --  gnatprove.out instead of re-running the prover.  This is the single
      --  biggest CI speedup: an unchanged project serves the proof from disk.
      --  The cached blob carries the gnatprove.out content itself (stored
      --  after a successful run, below), so a warm hit rebuilds the summary
      --  file the assessment pipeline parses even when obj/gnatprove/ was
      --  wiped -- without the restore, a warm hit on a wiped tree left
      --  Stone/0-VC output and a failing assessment.
      if Opts.Cache then
         declare
            In_Hash : constant String := Prove_Cache_Key;
            Hit     : Boolean := Adacovex.Cache.Exists (In_Hash);
         begin
            if Hit then
               Restore_Proof_Output (Target_Dir, In_Hash);
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
         --  The capture file lives in the system temp directory with a
         --  PID-suffixed name (GNAT.OS_Lib.Create_Temp_File would drop a
         --  GNAT-TEMP-*.TMP in the current directory instead, which leaks
         --  into the project tree on interrupted runs).
         declare
            Pid     : constant Integer :=
              GNAT.OS_Lib.Pid_To_Integer (GNAT.OS_Lib.Current_Process_Id);
            Pid_Img : constant String := Integer'Image (Pid);
            Tmp     : constant String :=
              Adacovex.CPUs.Get_Temp_Directory
              & "/adacovex-prove-output-"
              & Pid_Img (2 .. Pid_Img'Last)
              & ".tmp";
         begin
            Spawn
              (Exe (1 .. Exe_Len),
               Args (1 .. N),
               Tmp,
               OK,
               Code,
               Err_To_Out => True);
            if Ada.Directories.Exists (Tmp) then
               Replay_Suppressed
                 (Tmp, Ada.Strings.Unbounded.To_String (Opts.Suppress_Sets));
               declare
                  Del_OK : Boolean;
               begin
                  GNAT.OS_Lib.Delete_File (Tmp, Del_OK);
               end;
            end if;
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
               In_Hash  : constant String := Prove_Cache_Key;
               OK2      : Boolean;
               Out_Buf  : String (1 .. Adacovex.Cache.Max_Cache_Blob);
               Out_Len  : Natural := 0;
               Read_Ok  : Boolean := False;
               Out_Path : constant String :=
                 Strip_Trailing_Slash (Target_Dir)
                 & "/obj/gnatprove/gnatprove.out";
            begin
               --  Read the freshly generated gnatprove.out and store its
               --  content under a summary key derived from the input hash.
               --  A later warm hit (possibly on a tree whose obj/gnatprove/
               --  was wiped) then restores the exact summary the pipeline
               --  parses.
               begin
                  if Ada.Directories.Exists (Out_Path) then
                     Out_Len := Natural (Ada.Directories.Size (Out_Path));
                     if Out_Len > 0 and then Out_Len <= Out_Buf'Length then
                        declare
                           use Ada.Streams.Stream_IO;
                           F    : File_Type;
                           SEA  :
                             Ada.Streams.Stream_Element_Array
                               (0
                                .. Ada.Streams.Stream_Element_Offset
                                     (Out_Len - 1));
                           Last : Ada.Streams.Stream_Element_Offset;
                        begin
                           Open (F, In_File, Out_Path);
                           Read (F, SEA, Last);
                           Close (F);
                           Out_Len := Natural (Last) + 1 - Natural (SEA'First);
                           for I in 1 .. Out_Len loop
                              Out_Buf (I) :=
                                Character'Val
                                  (SEA
                                     (Ada.Streams.Stream_Element_Offset
                                        (I - 1)));
                           end loop;
                           Read_Ok := True;
                        exception
                           when others =>
                              if Is_Open (F) then
                                 Close (F);
                              end if;
                        end;
                     end if;
                  end if;
               exception
                  when others =>
                     null;
               end;
               Adacovex.Cache.Store (In_Hash, "1", OK2);
               if OK2 then
                  Ada.Text_IO.Put_Line
                    ("  cache:     gnatprove result cached for these inputs");
               end if;
               if Read_Ok then
                  Adacovex.Cache.Store
                    (Proof_Output_Key (In_Hash), Out_Buf (1 .. Out_Len), OK2);
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

   --  Gathered status-report data, shared by the human text report
   --  (Run_Status), the JSON export (Export_Status) and the key=value
   --  metrics report (Run_Status_Metrics) so the three outputs never
   --  drift.  String fields are fixed buffers + a length (0 = empty).
   type VCS_Tool_Flags is array (1 .. 6) of Boolean;
   type Status_Data is record
      Target           : String (1 .. Types.Max_Path) := (others => ' ');
      Target_Len       : Natural := 0;
      Alr              : String (1 .. Types.Max_Path) := (others => ' ');
      Alr_Len          : Natural := 0;   --  0 = not found on PATH
      Declared         : Boolean := False;
      Pin              : String (1 .. Types.Max_Path) := (others => ' ');
      Pin_Len          : Natural := 0;
      Gnatprove        : String (1 .. Types.Max_Path) := (others => ' ');
      Gnatprove_Ln     : Natural := 0;   --  0 = not found on PATH
      Cached           : Boolean := False;
      Cached_Dir       : String (1 .. Types.Max_Path) := (others => ' ');
      Cached_Len       : Natural := 0;
      Cores            : Natural := 1;
      In_CI            : Boolean := False;
      --  VCS command-line tool availability on PATH in this fixed order:
      --  git, hg, svn, fossil, jj, mandb.
      VCS_Tool         : VCS_Tool_Flags := (others => False);
      Repo_Kind        : String (1 .. 64) := (others => ' ');
      Repo_Len         : Natural := 0;   --  0 = none detected
      Repo_Tool        : String (1 .. 64) := (others => ' ');
      Repo_Tool_Ln     : Natural := 0;
      Repo_Note        : Boolean :=
        False;  --  target repo tool missing on PATH
      Needs_Alr        : Boolean := False;  --  manifest pin or global pin set
      Alr_Ok           : Boolean := True;
      OK               : Boolean := False;  --  overall usable verdict
      --  Effective display timezone (--tz / --timezone override, else the
      --  operating system's zone) and how many dated release changelogs the
      --  target carries under docs/changelogs.
      Time_Zone        : Adacovex.Timezones.Timezone_Info;
      Dated_Changelogs : Natural := 0;
   end record;

   --  Fill a Status_Data record by probing PATH, the target manifest, the
   --  global pin, and the toolchain cache.  Never deploys or downloads
   --  anything (same contract as Run_Status).
   --  Resolve the display timezone: an explicit TZ spec wins, else the
   --  operating system's timezone.
   function Effective_TZ
     (TZ_Spec : String) return Adacovex.Timezones.Timezone_Info
   is
      Info : Adacovex.Timezones.Timezone_Info;
      OK   : Boolean;
   begin
      if TZ_Spec'Length > 0 then
         Adacovex.Timezones.Parse (TZ_Spec, Info, OK);
         if OK then
            return Info;
         end if;
      end if;
      return Adacovex.Timezones.Default;
   end Effective_TZ;

   --  Count the dated release-changelog files under Dir/changelogs: every
   --  docs/changelogs/adacovex-*.md file represents one dated release entry.
   function Count_Dated_Changelogs (Dir : String) return Natural is
      use Ada.Directories;
      Search : Search_Type;
      Ent    : Directory_Entry_Type;
      N      : Natural := 0;
   begin
      if not Exists (Dir & "/docs/changelogs") then
         return 0;
      end if;
      Start_Search (Search, Dir & "/docs/changelogs", "*");
      while More_Entries (Search) loop
         Get_Next_Entry (Search, Ent);
         declare
            Nm : constant String := Simple_Name (Ent);
         begin
            if Kind (Ent) = Ordinary_File
              and then Nm'Length > 9
              and then Nm (Nm'First .. Nm'First + 8) = "adacovex-"
              and then Nm (Nm'Last - 2 .. Nm'Last) = ".md"
            then
               N := N + 1;
            end if;
         end;
      end loop;
      End_Search (Search);
      return N;
   exception
      when others =>
         End_Search (Search);
         return 0;
   end Count_Dated_Changelogs;

   procedure Gather_Status
     (Target_Dir : String; TZ_Spec : String; S : out Status_Data)
   is
      Exe   : String_Access;
      T     : constant String := Strip_Trailing_Slash (Target_Dir);
      Kind  : constant Adacovex.VCS.VCS_Kind := Adacovex.VCS.Detect (T);
      Names : constant array (1 .. 6) of String (1 .. 8) :=
        ("git" & 5 * " ",
         "hg" & 6 * " ",
         "svn" & 5 * " ",
         "fossil" & 2 * " ",
         "jj" & 6 * " ",
         "mandb" & 3 * " ");
      Lens  : constant array (1 .. 6) of Natural := (3, 2, 3, 6, 2, 5);
      KName : constant String := Adacovex.VCS.To_String (Kind);
      Need  : constant String := Adacovex.VCS.Tool_Name (Kind);
   begin
      S := (others => <>);
      S.Target_Len := T'Length;
      for I in 1 .. T'Length loop
         S.Target (I) := T (T'First + I - 1);
      end loop;
      S.Declared := Manifest_Declares_GNATprove (T);
      declare
         Pin : constant String := Global_GNATprove_Pin;
      begin
         S.Pin_Len := Pin'Length;
         for I in 1 .. Pin'Length loop
            S.Pin (I) := Pin (Pin'First + I - 1);
         end loop;
      end;
      S.Needs_Alr := S.Declared or else S.Pin_Len > 0;

      Exe := Locate_Exec_On_Path ("alr");
      if Exe /= null then
         S.Alr_Len := Exe.all'Length;
         for I in 1 .. Exe.all'Length loop
            S.Alr (I) := Exe.all (Exe.all'First + I - 1);
         end loop;
         Free (Exe);
      end if;
      Exe := Locate_Exec_On_Path ("gnatprove");
      if Exe /= null then
         S.Gnatprove_Ln := Exe.all'Length;
         for I in 1 .. Exe.all'Length loop
            S.Gnatprove (I) := Exe.all (Exe.all'First + I - 1);
         end loop;
         Free (Exe);
      end if;
      Find_Deployed_GNATprove
        (Home_Dir & Toolchain_Subdir,
         "",
         S.Cached_Dir,
         S.Cached_Len,
         S.Cached);
      S.Cores := Adacovex.CPUs.Detect_Core_Count;
      S.In_CI := Adacovex.CPUs.Is_Running_In_CI;
      for I in 1 .. 6 loop
         Exe := Locate_Exec_On_Path (Names (I) (1 .. Lens (I)));
         S.VCS_Tool (I) := Exe /= null;
         if Exe /= null then
            Free (Exe);
         end if;
      end loop;
      if KName'Length > 0 then
         S.Repo_Len := KName'Length;
         for I in 1 .. KName'Length loop
            S.Repo_Kind (I) := KName (KName'First + I - 1);
         end loop;
      end if;
      if Need'Length > 0 and then S.Repo_Len > 0 then
         S.Repo_Tool_Ln := Need'Length;
         for I in 1 .. Need'Length loop
            S.Repo_Tool (I) := Need (Need'First + I - 1);
         end loop;
         Exe := Locate_Exec_On_Path (Need);
         if Exe = null then
            S.Repo_Note := True;
         else
            Free (Exe);
         end if;
      end if;
      S.Alr_Ok := S.Alr_Len > 0 or else not S.Needs_Alr;
      S.OK :=
        (S.Gnatprove_Ln > 0
         or else S.Cached
         or else S.Declared
         or else S.Pin_Len > 0)
        and then S.Alr_Ok;
      S.Time_Zone := Effective_TZ (TZ_Spec);
      S.Dated_Changelogs := Count_Dated_Changelogs (T);
   end Gather_Status;

   procedure Run_Status
     (Target_Dir : String; TZ_Spec : String; Success : out Boolean)
   is
      S : Status_Data;
   begin
      Gather_Status (Target_Dir, TZ_Spec, S);

      Ada.Text_IO.Put_Line
        (Adacovex.Ansi.Bold ("adacovex v" & Adacovex.Version & " status"));
      Ada.Text_IO.Put_Line
        ("  target:             " & S.Target (1 .. S.Target_Len));

      --  Locale/time: the effective timezone, the current wall-clock date and
      --  time in that zone, and how many dated release changelogs the target
      --  carries under docs/changelogs.
      Ada.Text_IO.Put_Line
        ("  timezone:           "
         & (if S.Time_Zone.Display_Len > 0
            then S.Time_Zone.Display (1 .. S.Time_Zone.Display_Len)
            else "UTC"));
      Ada.Text_IO.Put_Line
        ("  date/time:          " & Adacovex.Timezones.Now_Text (S.Time_Zone));
      Ada.Text_IO.Put_Line
        ("  dated changelogs:   "
         & Natural'Image (S.Dated_Changelogs)
         & (if S.Dated_Changelogs = 1
            then " release entry"
            else " release entries"));

      --  Alire: only required when the manifest or a global pin drives the
      --  `alr -n get` deployment path; otherwise gnatprove on PATH / cache
      --  suffices.
      if S.Alr_Len > 0 then
         Ada.Text_IO.Put_Line
           ("  alire:              installed ("
            & S.Alr (1 .. S.Alr_Len)
            & ")");
      else
         Ada.Text_IO.Put_Line
           ("  alire:              NOT FOUND on PATH"
            & (if S.Needs_Alr
               then " (required: manifest/global pin)"
               else ""));
      end if;

      --  gnatprove detectability across the resolution tiers, without
      --  downloading anything.
      Ada.Text_IO.Put_Line ("  gnatprove:");
      if S.Declared then
         declare
            Ver  : constant String :=
              File_GNATprove_Version
                (S.Target (1 .. S.Target_Len) & "/alire-dev.toml");
            Ver2 : constant String :=
              File_GNATprove_Version
                (S.Target (1 .. S.Target_Len) & "/alire.toml");
            Con  : constant String := (if Ver'Length > 0 then Ver else Ver2);
         begin
            Ada.Text_IO.Put_Line
              ("    manifest pin:     "
               & (if Con'Length > 0 then Con else "declared"));
         end;
      else
         Ada.Text_IO.Put_Line ("    manifest pin:     none");
      end if;
      Ada.Text_IO.Put_Line
        ("    global pin:        "
         & (if S.Pin_Len > 0 then S.Pin (1 .. S.Pin_Len) else "none"));
      if S.Gnatprove_Ln > 0 then
         Ada.Text_IO.Put_Line
           ("    on PATH:           " & S.Gnatprove (1 .. S.Gnatprove_Ln));
      else
         Ada.Text_IO.Put_Line ("    on PATH:           not found");
      end if;
      if S.Cached then
         Ada.Text_IO.Put_Line
           ("    toolchain cache:   " & S.Cached_Dir (1 .. S.Cached_Len));
      else
         Ada.Text_IO.Put_Line ("    toolchain cache:   empty");
      end if;

      --  Platform support / parallelism basis.
      Ada.Text_IO.Put_Line ("  platform:");
      Ada.Text_IO.Put_Line
        ("    logical CPUs:      "
         & Natural'Image (S.Cores) (2 .. Natural'Image (S.Cores)'Last));
      Ada.Text_IO.Put_Line
        ("    CI environment:    " & (if S.In_CI then "yes" else "no"));
      Ada.Text_IO.Put_Line
        ("    prove -j default:  "
         & Adacovex.CPUs.Jobs_Justification (-1, S.Cores, S.In_CI));

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
      if not S.VCS_Tool (6) then
         Ada.Text_IO.Put_Line
           ("    note: man-db (mandb) is not on PATH; `adacovex man`");
         Ada.Text_IO.Put_Line
           ("          still installs the page but cannot refresh the");
         Ada.Text_IO.Put_Line
           ("          man database (read it with `man -l`).");
      end if;
      Ada.Text_IO.Put_Line
        ("    target repo:       "
         & (if S.Repo_Len > 0
            then S.Repo_Kind (1 .. S.Repo_Len)
            else "none detected"));
      if S.Repo_Note then
         Ada.Text_IO.Put_Line
           ("    note: '"
            & S.Repo_Tool (1 .. S.Repo_Tool_Ln)
            & "' is not on PATH; differential");
         Ada.Text_IO.Put_Line
           ("          modes (--compare-base / --coverage-delta)");
         Ada.Text_IO.Put_Line
           ("          need it to snapshot base revisions.");
      end if;

      Ada.Text_IO.Put_Line
        ("  release note: CI release binary is Linux x86-64 only for now");

      Success := S.OK;
      if Success then
         Ada.Text_IO.Put_Line
           (Adacovex.Ansi.Green
              ("  => OK (alr + gnatprove available or dependency-managed)"));
      else
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            Adacovex.Ansi.Red
              ("  => FAIL: gnatprove not detectable without a download"
               & (if not S.Alr_Ok
                  then " (and alr is required but missing)"
                  else "")));
      end if;
   end Run_Status;

   --  Escape a string value for JSON output (the same pairing rules as
   --  Adacovex.Renderers.HTML.Json_Escape: backslash and quote are escaped,
   --  everything else passes through).
   function Status_Json_Escape (S : String) return String is
      R : Ada.Strings.Unbounded.Unbounded_String;
      use Ada.Strings.Unbounded;
   begin
      for I in S'Range loop
         case S (I) is
            when '"'    =>
               --  JSON escape: backslash + quote
               Append (R, "\""");

            when '\'    =>
               --  JSON escape: backslash + backslash
               Append (R, "\\");

            when others =>
               Append (R, S (I));
         end case;
      end loop;
      return To_String (R);
   end Status_Json_Escape;

   procedure Export_Status
     (Target_Dir : String;
      Out_Path   : String;
      TZ_Spec    : String;
      Success    : out Boolean)
   is
      S         : Status_Data;
      use Ada.Strings.Unbounded;
      R         : Unbounded_String;
      F         : Ada.Text_IO.File_Type;
      VCS_Names : constant array (1 .. 6) of String (1 .. 12) :=
        ("git" & 9 * " ",
         "hg" & 10 * " ",
         "svn" & 9 * " ",
         "fossil" & 6 * " ",
         "jj" & 10 * " ",
         "mandb" & 7 * " ");
      VCS_Lens  : constant array (1 .. 6) of Natural := (3, 2, 3, 6, 2, 5);
      Label     : String (1 .. 12) := (others => ' ');
      LLen      : Natural := 0;

      --  A single double-quote character, and a string rendering of a
      --  boolean, used to build the JSON document with Ada's doubled-quote
      --  string syntax (no backslash escapes needed).
      Q : constant String := """";

      procedure Put (S : String) is
      begin
         Append (R, S);
      end Put;

      procedure Field (K : String; V : String) is
      begin
         Put (Q & K & Q & ":" & Q & Status_Json_Escape (V) & Q);
      end Field;

      procedure Field_Bool (K : String; B : Boolean) is
      begin
         Put (Q & K & Q & ":" & (if B then "true" else "false"));
      end Field_Bool;
   begin
      Gather_Status (Target_Dir, TZ_Spec, S);
      Put ("{");
      Field ("version", Adacovex.Version);
      Put (",");
      Field ("target", S.Target (1 .. S.Target_Len));
      Put (",");
      Field
        ("timezone",
         (if S.Time_Zone.Display_Len > 0
          then S.Time_Zone.Display (1 .. S.Time_Zone.Display_Len)
          else "UTC"));
      Put (",");
      Field ("date_time", Adacovex.Timezones.Now_Text (S.Time_Zone));
      Put (",");
      Put
        (Q
         & "dated_changelogs"
         & Q
         & ":"
         & Natural'Image (S.Dated_Changelogs)
             (2 .. Natural'Image (S.Dated_Changelogs)'Last));
      Put (",");
      if S.Alr_Len > 0 then
         Field ("alire", S.Alr (1 .. S.Alr_Len));
      else
         Field ("alire", "");
      end if;
      Put (",");
      Field_Bool ("gnatprove_declared", S.Declared);
      Put (",");
      Field ("gnatprove_pin", S.Pin (1 .. S.Pin_Len));
      Put (",");
      Field ("gnatprove_path", S.Gnatprove (1 .. S.Gnatprove_Ln));
      Put (",");
      Field_Bool ("gnatprove_cached", S.Cached);
      Put (",");
      Put
        (Q
         & "logical_cpus"
         & Q
         & ":"
         & Natural'Image (S.Cores) (2 .. Natural'Image (S.Cores)'Last));
      Put (",");
      Field_Bool ("ci", S.In_CI);
      Put (",");
      --  VCS tool availability as a nested object of booleans.
      Put (Q & "vcs" & Q & ":{");
      for I in 1 .. 6 loop
         if I > 1 then
            Put (",");
         end if;
         LLen := VCS_Lens (I);
         Label (1 .. LLen) := VCS_Names (I) (1 .. LLen);
         Put (Q & Label (1 .. LLen) & Q & ":");
         if S.VCS_Tool (I) then
            Put ("true");
         else
            Put ("false");
         end if;
      end loop;
      Put ("}");
      Put (",");
      Field ("target_repo", S.Repo_Kind (1 .. S.Repo_Len));
      Put (",");
      Field_Bool ("ok", S.OK);
      Put ("}");

      if Out_Path'Length = 0 then
         Ada.Text_IO.Put_Line (To_String (R));
         Success := True;
      else
         begin
            Ada.Text_IO.Create (F, Ada.Text_IO.Out_File, Out_Path);
            Ada.Text_IO.Put_Line (F, To_String (R));
            Ada.Text_IO.Close (F);
            Success := True;
         exception
            when others =>
               if Ada.Text_IO.Is_Open (F) then
                  Ada.Text_IO.Close (F);
               end if;
               Success := False;
         end;
      end if;
   end Export_Status;

   procedure Run_Status_Metrics
     (Target_Dir : String; TZ_Spec : String; Success : out Boolean)
   is
      S         : Status_Data;
      VCS_Names : constant array (1 .. 6) of String (1 .. 12) :=
        ("git" & 9 * " ",
         "hg" & 10 * " ",
         "svn" & 9 * " ",
         "fossil" & 6 * " ",
         "jj" & 10 * " ",
         "mandb" & 7 * " ");
      VCS_Lens  : constant array (1 .. 6) of Natural := (3, 2, 3, 6, 2, 5);
   begin
      Gather_Status (Target_Dir, TZ_Spec, S);
      Ada.Text_IO.Put_Line ("version=" & Adacovex.Version);
      Ada.Text_IO.Put_Line ("target=" & S.Target (1 .. S.Target_Len));
      Ada.Text_IO.Put_Line
        ("timezone="
         & (if S.Time_Zone.Display_Len > 0
            then S.Time_Zone.Display (1 .. S.Time_Zone.Display_Len)
            else "UTC"));
      Ada.Text_IO.Put_Line
        ("date_time=" & Adacovex.Timezones.Now_Text (S.Time_Zone));
      Ada.Text_IO.Put_Line
        ("dated_changelogs="
         & Natural'Image (S.Dated_Changelogs)
             (2 .. Natural'Image (S.Dated_Changelogs)'Last));
      Ada.Text_IO.Put_Line
        ("alire="
         & (if S.Alr_Len > 0 then S.Alr (1 .. S.Alr_Len) else "missing"));
      Ada.Text_IO.Put_Line
        ("gnatprove_declared=" & (if S.Declared then "true" else "false"));
      Ada.Text_IO.Put_Line
        ("gnatprove_pin="
         & (if S.Pin_Len > 0 then S.Pin (1 .. S.Pin_Len) else "none"));
      Ada.Text_IO.Put_Line
        ("gnatprove_path="
         & (if S.Gnatprove_Ln > 0
            then S.Gnatprove (1 .. S.Gnatprove_Ln)
            else "missing"));
      Ada.Text_IO.Put_Line
        ("gnatprove_cached=" & (if S.Cached then "yes" else "no"));
      Ada.Text_IO.Put_Line
        ("logical_cpus="
         & Natural'Image (S.Cores) (2 .. Natural'Image (S.Cores)'Last));
      Ada.Text_IO.Put_Line ("ci=" & (if S.In_CI then "yes" else "no"));
      for I in 1 .. 6 loop
         Ada.Text_IO.Put_Line
           ("vcs_"
            & VCS_Names (I) (1 .. VCS_Lens (I))
            & "="
            & (if S.VCS_Tool (I) then "yes" else "no"));
      end loop;
      Ada.Text_IO.Put_Line
        ("target_repo="
         & (if S.Repo_Len > 0 then S.Repo_Kind (1 .. S.Repo_Len) else "none"));
      Ada.Text_IO.Put_Line ("ok=" & (if S.OK then "yes" else "no"));
      Success := S.OK;
   end Run_Status_Metrics;

end Adacovex.Prove;
