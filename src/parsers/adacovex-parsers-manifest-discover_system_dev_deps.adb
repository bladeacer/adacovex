separate (Adacovex.Parsers.Manifest)
--  Discover system-tool dev dependencies referenced by the project.
--  Walk the project tree and read only dev-facing build files: Makefile
--  variants, shell scripts, GNAT project files, CI workflows, and the
--  project's build manifests (Cargo.toml, go.mod, pyproject.toml,
--  package.json, ...). Register every known system tool that those files
--  reference and that is actually installed on PATH. Register it as a
--  dev-scope dependency of the root. A Makefile at the project root
--  implies make. This applies even when no recipe spells out the driver
--  by name.
--
--  Source files (.ads/.adb/.c/.go/.rs/.js/.ts/...) are NOT scanned. They
--  are not tool invocations: scanning them is a source of false positives
--  because identifiers and keywords collide with tool names (every Ada
--  source contains the word "ada", which matches the curated "ada" tool;
--  a Rust file contains "go"; a C file contains "make"). The detection is
--  therefore scoped to files that actually drive a build, never to source
--  text. Docstrings (.md prose) are also skipped: prose is not tool
--  interaction and words like "make" are common in it.
--
--  The pass state (Scan_Stack, Referenced, Probes, From_Cache, Refreshed,
--  Key_Img, Key_Len) is package level because the steps live in their own
--  separate bodies. Every one of them is reset here, so the pass has the
--  same per-call lifetime the nested declarations had before the split.
--  @param Target_Dir  Project root directory to scan.
--  @param Graph  Dependency graph to extend (root at index 1).
procedure Discover_System_Dev_Deps
  (Target_Dir : String;
   Graph      : in out Types.Implementation.Component_Vectors.Vector)
is
   use Ada.Directories;
   Search : Search_Type;
   Ent    : Directory_Entry_Type;
begin
   Scan_Stack.Clear;
   Referenced.Clear;
   Probes.Clear;
   From_Cache := False;
   Refreshed  := False;
   Key_Len    := 0;

   --  Serve the referenced-tool set from the on-disk cache when the
   --  project's inputs are unchanged. The key covers every file the
   --  scan reads, so an unchanged project skips the tree walk and the
   --  per-file word scan entirely; an edit invalidates the key and the
   --  next run re-scans. The key value is kept for the store step that
   --  runs after a scan.
   declare
      K     : constant String := Tools_Key (Target_Dir);
      Blob  : String (1 .. 8192) := (others => ' ');
      BLen  : Natural := 0;
      Found : Boolean := False;
   begin
      if K'Length > 0 then
         if K'Length <= Key_Img'Last then
            Key_Img (1 .. K'Length) := K;
            Key_Len := K'Length;
         end if;
         Adacovex.Cache.Get_Cached (K, Blob, BLen, Found);
         if Found and then BLen > 0 then
            Deserialize_Set (Blob (1 .. BLen));
            From_Cache := True;
         end if;
      end if;

      if not From_Cache then
         Push_Scan_Dir (Target_Dir);

         while not Scan_Stack.Is_Empty loop
            declare
               Current  : Scan_Dir_Entry := Scan_Stack.Last_Element;
               Dir_Path : String renames Current.Path (1 .. Current.Len);
               Snap     : Adacovex.Dir_Cache.Dir_Entry_List;
               SCt      : Natural;
               STrunc   : Boolean;
               SOK      : Boolean;
            begin
               Scan_Stack.Delete_Last;

               --  Shared snapshot first; direct enumeration only on the
               --  fallback path (over-cap tree or unreadable snapshot).
               Adacovex.Dir_Cache.Snapshot
                 (Dir_Path, Snap, SCt, STrunc, SOK);
               if SOK and then not STrunc then
                  for SI in 1 .. SCt loop
                     declare
                        N    : constant String :=
                          Snap (SI).Name (1 .. Snap (SI).Name_Len);
                        Path : constant String := Dir_Path & "/" & N;
                        Is_D : constant Boolean :=
                          Adacovex.Dir_Cache.Is_Directory (Snap (SI).Kind);
                     begin
                        if Is_D then
                           if N /= ".git"
                             and N /= ".jj"
                             and N /= ".hg"
                             and N /= ".svn"
                             and N /= "obj"
                             and N /= "tests"
                             and N /= "config"
                             and N /= ".adacovex"
                             and N /= "alire"
                             and N /= "gnatprove"
                             and N /= "__pycache__"
                             and N /= "node_modules"
                             and N /= ".venv"
                             and N /= ".headroom"
                             and N /= ".lccst"
                             and N /= "_build"
                           then
                              Push_Scan_Dir (Path);
                           end if;
                        elsif Should_Scan (N) then
                           Scan_File (Path);
                        end if;
                     end;
                  end loop;
               else
                  Start_Search (Search, Dir_Path, "");
                  begin
                     while More_Entries (Search) loop
                        Get_Next_Entry (Search, Ent);
                        declare
                           N    : constant String := Simple_Name (Ent);
                           Path : constant String := Full_Name (Ent);
                        begin
                           if Kind (Ent) = Directory then
                              if N /= "."
                                and N /= ".."
                                and N /= ".git"
                                and N /= ".jj"
                                and N /= ".hg"
                                and N /= ".svn"
                                and N /= "obj"
                                and N /= "tests"
                                and N /= "config"
                                and N /= ".adacovex"
                                and N /= "alire"
                                and N /= "gnatprove"
                                and N /= "__pycache__"
                                and N /= "node_modules"
                                and N /= ".venv"
                                and N /= ".headroom"
                                and N /= ".lccst"
                                and N /= "_build"
                              then
                                 Push_Scan_Dir (Path);
                              end if;
                           elsif Kind (Ent) = Ordinary_File then
                              if Should_Scan (N) then
                                 Scan_File (Path);
                              end if;
                           end if;
                        end;
                     end loop;
                  exception
                     when others =>
                        End_Search (Search);
                        raise;
                  end;
                  End_Search (Search);
               end if;
            end;
         end loop;

      end if;
   end;

   --  A Makefile at the project root implies make even when no recipe
   --  spells out the driver by name.
   if Has_Makefile (Target_Dir) then
      for T in System_Tools'Range loop
         if System_Tools (T).Len = 4
           and then System_Tools (T).Name (1 .. 4) = "make"
         then
            Note_Tool (System_Tools (T));
            exit;
         end if;
      end loop;
   end if;

   --  Register every referenced tool that is actually installed on PATH.
   --  Register it as a dev-scope dependency of the root. Probe its
   --  version ("<Tool> <flag>") when possible. Tools the project does
   --  not reference, or that are not installed, are skipped.
   --  Append_Dependency also deduplicates against manifest, lockfile, and
   --  GPR deps (for example gnatprove declared in alire-dev.toml). A
   --  manifest-pinned tool never appears twice.
   --
   --  Cache hit: the probe results were restored with the set. Each
   --  restored probe is re-validated against the identity digest of the
   --  tool's installed binary before its version is trusted: a tool
   --  upgraded since the set was cached re-probes here (and refreshes
   --  both cache layers), while an unchanged toolchain serves entirely
   --  from cache with no subprocess probes.
   if From_Cache then
      for PI in 1 .. Integer (Probes.Length) loop
         declare
            Nm          : constant String :=
              Probes (PI).Name (1 .. Probes (PI).NLen);
            Live_Digest : constant String := Tool_Fp_Digest (Nm);
         begin
            if Live_Digest'Length > 0
              and then Probes (PI).FpLen = Live_Digest'Length
              and then Probes (PI).Fp (1 .. Live_Digest'Length)
                        = Live_Digest
            then
               Append_Dependency
                 (Graph,
                  Nm,
                  Probes (PI).Ver (1 .. Probes (PI).VLen),
                  "",
                  "System tool referenced by the project (dev dependency)",
                  "pkg:generic/" & Nm,
                  1,
                  False,
                  Types.Scope_System);
            else
               --  Upgraded/replaced binary (or a stale digest-free
               --  entry): probe fresh and refresh the stored set.
               declare
                  Exe : GNAT.OS_Lib.String_Access :=
                    GNAT.OS_Lib.Locate_Exec_On_Path (Nm);
                  Fp  : constant String :=
                    (if Exe /= null
                     then Adacovex.Cache.Tool_Fingerprint (Exe.all)
                     else "");
                  V   : constant String :=
                    (if Fp'Length > 0
                     then Probe_Version (Nm, "--version")
                     else "");
                  procedure Store is
                  begin
                     if Fp'Length > 0 then
                        Adacovex.Cache.Put_Probe (Nm, Fp, V);
                     end if;
                  end Store;
               begin
                  if Exe /= null then
                     GNAT.OS_Lib.Free (Exe);
                     Store;
                     Add_Probe_Fp (Nm, V, Adacovex.Cache.Hash_String (Fp));
                     Refreshed := True;
                     Append_Dependency
                       (Graph,
                        Nm,
                        V,
                        "",
                        "System tool referenced by the project (dev dependency)",
                        "pkg:generic/" & Nm,
                        1,
                        False,
                        Types.Scope_System);
                  end if;
               end;
            end if;
         end;
      end loop;
   else
      for I in 1 .. Integer (Referenced.Length) loop
         declare
            Name : constant String :=
              Referenced (I).Name (1 .. Referenced (I).Len);
            Exe  : GNAT.OS_Lib.String_Access :=
              GNAT.OS_Lib.Locate_Exec_On_Path (Name);
         begin
            if Exe /= null then
               --  Identity of the installed binary (path + size + mtime).
               --  Both cache layers below key on it, so an upgraded or
               --  replaced tool re-probes on the next run instead of
               --  serving a version the old binary reported.
               declare
                  Fp : constant String :=
                    Adacovex.Cache.Tool_Fingerprint (Exe.all);
               begin
                  GNAT.OS_Lib.Free (Exe);
                  --  Version probing spawns a subprocess per tool. Cache
                  --  the result on disk (7-day TTL), validated against
                  --  the binary fingerprint. Unchanged toolchains then do
                  --  not pay tens of milliseconds per referenced tool on
                  --  every run; an upgrade re-probes exactly once.
                  declare
                     Probe : String (1 .. 512) := (others => ' ');
                     PLen  : Natural := 0;
                     Found : Boolean := False;
                     --  Version text (up to the 4096-char Probe_Version
                     --  reader cap). It is copied into a fixed buffer.
                     --  The cache-hit and cache-miss paths then share one
                     --  Append_Dependency call.
                     VBuf  : String (1 .. 4096);
                     VLen  : Natural := 0;
                  begin
                     Adacovex.Cache.Get_Probe
                       (Name, Fp, Probe, PLen, Found);
                     if Found then
                        VLen := PLen;
                        VBuf (1 .. VLen) := Probe (1 .. VLen);
                     else
                        declare
                           V : constant String :=
                             Probe_Version (Name, "--version");
                        begin
                           VLen := V'Length;
                           if VLen > VBuf'Last then
                              VLen := VBuf'Last;
                           end if;
                           VBuf (1 .. VLen) :=
                             V (V'First .. V'First + VLen - 1);
                        end;
                        Adacovex.Cache.Put_Probe
                          (Name, Fp, VBuf (1 .. VLen));
                     end if;
                     Add_Probe_Fp
                       (Name,
                        VBuf (1 .. VLen),
                        Adacovex.Cache.Hash_String (Fp));
                     Append_Dependency
                       (Graph,
                        Name,
                        VBuf (1 .. VLen),
                        "",
                        "System tool referenced by the project (dev dependency)",
                        "pkg:generic/" & Name,
                        1,
                        False,
                        Types.Scope_System);
                  end;
               end;
            end if;
         end;
      end loop;
   end if;

   --  Store the freshly scanned set (now including probe results) for
   --  the next run. On a cache hit nothing is stored, because the entry
   --  is still current and complete -- unless a re-validation
   --  re-probed a replaced binary, in which case the corrected
   --  fingerprints must be written back or the stale blob re-probes on
   --  every later run (Refreshed).
   if (not From_Cache or else Refreshed) and then Key_Len > 0 then
      declare
         S  : constant String := Serialize_Set;
         OK : Boolean;
      begin
         if S'Length > 0 then
            Adacovex.Cache.Put_Cached (Key_Img (1 .. Key_Len), S, OK);
         end if;
      end;
   end if;
end Discover_System_Dev_Deps;