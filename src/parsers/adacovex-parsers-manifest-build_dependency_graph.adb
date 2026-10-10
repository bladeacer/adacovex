separate (Adacovex.Parsers.Manifest)
--  Build the dependency graph for a project rooted at Target_Dir.
--  Read alire.toml / alire-dev.toml (root metadata), alire.lock
--  (solved dependencies), and the root .gpr file (project name and
--  with clauses). The root component is stored at index 1.
--  Dependency components reference their parent via the Parent field.
--  @param Target_Dir  Project root directory.
--  @param Manifest_Path  Path to the Alire manifest (alire.toml or dev).
--  @param Graph  Output dependency graph (index 1 = root project).
--  @param Success  True if the manifest was readable and the root
--    component was resolved.
--  @param Use_Cache  When True the resolved graph is keyed in the on-disk
--    result cache by the combined content hash of the manifests, the
--    lockfile, and every .gpr file, so an unchanged dependency set is
--    served without re-parsing; when False it is always rebuilt.
procedure Build_Dependency_Graph
  (Target_Dir    : String;
   Manifest_Path : String;
   Graph         : out Types.Implementation.Component_Vectors.Vector;
   Success       : out Boolean;
   Use_Cache     : Boolean := False)
is
   Root_Name        : Types.Desc_Field;
   Root_Name_Len    : Natural := 0;
   Root_Version     : Types.Desc_Field;
   Root_Version_Len : Natural := 0;
   Root_License     : Types.Desc_Field;
   Root_License_Len : Natural := 0;
   Root_Desc        : Types.Path_Field;
   Root_Desc_Len    : Natural := 0;
   Root_Website     : Types.Path_Field;
   Root_Website_Len : Natural := 0;
   Proj_File        : Types.Path_Field;
   Proj_File_Len    : Natural := 0;
   Manifest_OK      : Boolean := False;

   GPR_Files    : Path_Vectors.Vector;
   GPR_Name     : Types.Desc_Field;
   GPR_Name_Len : Natural := 0;
   GPR_Deps     : Name_Vectors.Vector;
   Root_GPR_Len : Natural := 0;
   Root_GPR     : Types.Path_Field;
   Root         : Types.Implementation.Component_Info;
begin
   Graph := Types.Implementation.Component_Vectors.Empty_Vector;

   --  Reset the package-level dependency-scope sets for this resolution.
   Base_Names.Clear;
   Dev_Names.Clear;
   Test_Names.Clear;

   Read_Manifest
     (Manifest_Path,
      Root_Name,
      Root_Name_Len,
      Root_Version,
      Root_Version_Len,
      Root_License,
      Root_License_Len,
      Root_Desc,
      Root_Desc_Len,
      Root_Website,
      Root_Website_Len,
      Proj_File,
      Proj_File_Len,
      Manifest_OK);

   --  Collect the base (publishing manifest), dev (alire-dev.toml), and
   --  test ([[test-depends-on]] in either manifest) dependency crate sets
   --  used to classify every resolved component.
   Read_Manifest_Deps (Manifest_Path, Base_Names, Test_Names);
   declare
      T : constant String :=
        (if Target_Dir'Length > 0 and then Target_Dir (Target_Dir'Last) = '/'
         then Target_Dir (Target_Dir'First .. Target_Dir'Last - 1)
         else Target_Dir);
   begin
      if T & "/alire-dev.toml" /= Manifest_Path then
         Read_Manifest_Deps (T & "/alire-dev.toml", Dev_Names, Test_Names);
      end if;
   end;

   Collect_GPR_Files (Target_Dir, GPR_Files);

   --  Serve a previously resolved (unchanged) graph straight from the
   --  on-disk result cache instead of re-parsing the lockfile and every
   --  .gpr file. The directory walk above is cheap. The recursive GPR
   --  and lock parsing that it saves is not cheap.
   if Use_Cache then
      declare
         K     : constant String :=
           Graph_Key (Target_Dir, Manifest_Path, GPR_Files);
         Blob  : String (1 .. Adacovex.Cache.Max_Cache_Blob);
         Blen  : Natural;
         Found : Boolean;
      begin
         if K'Length > 0 then
            Adacovex.Cache.Get_Cached (K, Blob, Blen, Found);
            if Found and then Graph_Store.Deserialize (Blob (1 .. Blen), Graph)
            then
               Success := True;
               return;
            end if;
         end if;
      end;
   end if;

   --  Locate the root .gpr. Use the manifest project-files entry if
   --  present. Otherwise use a .gpr whose project name matches the
   --  manifest crate name.
   if Proj_File_Len > 0 then
      declare
         Cand : constant String :=
           Target_Dir & "/" & Proj_File (1 .. Proj_File_Len);
      begin
         if Ada.Directories.Exists (Cand) then
            Root_GPR_Len := Cand'Length;
            for I in Cand'Range loop
               Root_GPR (I - Cand'First + 1) := Cand (I);
            end loop;
         end if;
      end;
   end if;
   if Root_GPR_Len = 0 then
      if Root_Name_Len > 0 then
         Find_GPR
           (GPR_Files, Root_Name (1 .. Root_Name_Len), Root_GPR, Root_GPR_Len);
      end if;
   end if;

   if Root_GPR_Len > 0 then
      Parse_GPR
        (Root_GPR (1 .. Root_GPR_Len), GPR_Name, GPR_Name_Len, GPR_Deps);
   end if;

   --  Root component (index 1). Name falls back to the GPR project name.
   if Root_Name_Len = 0 then
      if GPR_Name_Len > 0 then
         Set_Field (Root_Name, Root_Name_Len, GPR_Name (1 .. GPR_Name_Len));
      else
         Set_Field
           (Root_Name,
            Root_Name_Len,
            Ada.Directories.Simple_Name (Target_Dir));
      end if;
   end if;

   declare
      V : constant String :=
        (if Root_Version_Len > 0
         then
           Root_Name (1 .. Root_Name_Len)
           & "@"
           & Root_Version (1 .. Root_Version_Len)
         else Root_Name (1 .. Root_Name_Len));
   begin
      Set_Path (Root.PURL, Root.PURL_Len, "pkg:alire/" & V);
      Set_Path (Root.Ref, Root.Ref_Len, "pkg:alire/" & V);
   end;
   --  Root language. The top languages of the project's own sources are
   --  used (vendored directories excluded). The SBOM root component then
   --  records the language mix that created it (top 3 for mixed trees).
   declare
      Root_T     : constant String :=
        (if Target_Dir'Length > 0 and then Target_Dir (Target_Dir'Last) = '/'
         then Target_Dir (Target_Dir'First .. Target_Dir'Last - 1)
         else Target_Dir);
      Root_Langs : Lang_Vectors.Vector;
   begin
      Detect_Languages (Root_T, 3, Root_Langs, Skip_Vendored => True);
      if not Root_Langs.Is_Empty then
         declare
            RL : constant String := Language_Summary (Root_Langs, "");
         begin
            if RL'Length > 0 then
               Set_Field (Root.Language, Root.Language_Len, RL);
            end if;
         end;
      end if;
   end;

   Set_Field (Root.Name, Root.Name_Len, Root_Name (1 .. Root_Name_Len));
   Set_Field
     (Root.Version, Root.Version_Len, Root_Version (1 .. Root_Version_Len));
   Set_Field
     (Root.License, Root.License_Len, Root_License (1 .. Root_License_Len));
   Set_Path
     (Root.Description, Root.Description_Len, Root_Desc (1 .. Root_Desc_Len));
   if Root_Website_Len > 0 then
      Set_Path
        (Root.Website, Root.Website_Len, Root_Website (1 .. Root_Website_Len));
   end if;
   Root.Kind := Types.Root_Component;
   Root.Parent := 0;
   Graph.Append (Root);

   --  Resolve alire.lock dependencies (solved crates).
   Read_Alire_Lock (Target_Dir & "/alire/alire.lock", Graph);

   --  Resolve GPR with-clause dependencies, including transitives.
   Resolve_GPR_Deps (Graph, GPR_Files, GPR_Deps, 1, 8);

   --  Add vendored packages overlaid by .adacovex/patches/ docstring
   --  patches (for example a third-party copy under demo/deps) as
   --  scope=vendored dependencies of the root.
   Discover_Vendored_Components (Target_Dir, Graph);

   --  Add language-agnostic vendored components. These are ecosystem
   --  manifests (package.json, Cargo.toml, and more) and Ada library dirs
   --  under any vendor-named directory (third_party, deps, node_modules,
   --  and more). Each has its ecosystem PURL and detected language or
   --  languages.
   Discover_Generic_Vendored (Target_Dir, Graph);

   --  Register manifest-declared deps (base from alire.toml, dev from
   --  alire-dev.toml) that no GPR with-clause or lockfile resolved. The
   --  SBOM captures the declared dependency set. This applies even for
   --  zero-`with` projects whose toolchain deps live only in the dev
   --  manifest.
   Register_Manifest_Deps (Target_Dir, Graph, Base_Names, Dev_Names);

   --  Register the root's Python requirements (requirements*.txt) as
   --  dev-scope pypi dependencies resolved from the package registry.
   Register_Root_Python_Deps (Target_Dir, Graph);

   Success := Root.Name_Len > 0;

   --  Store the freshly resolved graph for the next run. Store it only on
   --  success. A partial graph is then never cached.
   if Use_Cache then
      declare
         K  : constant String :=
           Graph_Key (Target_Dir, Manifest_Path, GPR_Files);
         OK : Boolean;
      begin
         if K'Length > 0 then
            declare
               S_Blob : constant String := Graph_Store.Serialize (Graph);
            begin
               if S_Blob'Length > 0 then
                  Adacovex.Cache.Put_Cached (K, S_Blob, OK);
               end if;
            end;
         end if;
      end;
   end if;
end Build_Dependency_Graph;
