separate (Adacovex.Parsers.Manifest)
--  Fingerprint of everything that contributes vendored components to
--  the graph. Every file under the classic vendored roots
--  (<target>/.adacovex/patches, resources, vendor, assets) is included.
--  Every file under the language-agnostic vendored directories that
--  Discover_Generic_Vendored discovers is included (deps, third_party,
--  node_modules, and more, hashed to depth 3). Adding, removing, or
--  editing any of those files changes the digest. The cached graph is
--  then invalidated correctly.
--  Returns "" when no vendored input exists.
--  @param Target_Dir  Project root directory.
--  @return SHA256 of the vendored inputs, or "" when none exist.
function Vendored_Hash (Target_Dir : String) return String is
   use Ada.Directories;
   type Dir_Entry is record
      Path  : Types.Path_Field;
      Len   : Natural := 0;
      Level : Natural := 0;
   end record;
   package Dir_Stacks is new Ada.Containers.Vectors (Positive, Dir_Entry);
   Dir_Stack : Dir_Stacks.Vector;
   Search    : Search_Type;
   Ent       : Directory_Entry_Type;
   T         : constant String :=
     (if Target_Dir'Length > 0 and then Target_Dir (Target_Dir'Last) = '/'
      then Target_Dir (Target_Dir'First .. Target_Dir'Last - 1)
      else Target_Dir);
   Comb      : String (1 .. Types.Max_Path);
   CLen      : Natural := 0;

   procedure Push_Dir
     (S         : in out Dir_Stacks.Vector;
      Dir       : String;
      Level     : Natural;
      Max_Depth : Natural)
   is
      Item : Dir_Entry;
   begin
      if Dir'Length <= Types.Max_Path and then Level <= Max_Depth then
         Item.Len := Dir'Length;
         for I in Dir'Range loop
            Item.Path (I - Dir'First + 1) := Dir (I);
         end loop;
         Item.Level := Level;
         S.Append (Item);
      end if;
   end Push_Dir;

   procedure Add (S : String) is
   begin
      if S'Length > 0 and then CLen + S'Length <= Comb'Last then
         Comb (CLen + 1 .. CLen + S'Length) := S;
         CLen := CLen + S'Length;
      end if;
   end Add;

   --  Hash every regular file under Root, descending at most Max_Levels
   --  subdirectories. It uses its own stack. The outer vendor walk is
   --  then unaffected.
   procedure Hash_Tree (Root : String; Max_Levels : Natural) is
      H_Stack  : Dir_Stacks.Vector;
      H_Search : Search_Type;
      H_Ent    : Directory_Entry_Type;
   begin
      if not Exists (Root) then
         return;
      end if;
      Push_Dir (H_Stack, Root, 0, Max_Levels);
      while not H_Stack.Is_Empty loop
         declare
            Current  : Dir_Entry := H_Stack.Last_Element;
            Dir_Path : String renames Current.Path (1 .. Current.Len);
            Snap     : Adacovex.Dir_Cache.Dir_Entry_List;
            SCt      : Natural;
            STrunc   : Boolean;
            SOK      : Boolean;
         begin
            H_Stack.Delete_Last;
            --  Shared snapshot first; direct enumeration on fallback.
            Adacovex.Dir_Cache.Snapshot (Dir_Path, Snap, SCt, STrunc, SOK);
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
                        if N /= "_build" and then not Skip_Walk_Dir (N) then
                           Push_Dir
                             (H_Stack, Path, Current.Level + 1, Max_Levels);
                        end if;
                     else
                        Add (Adacovex.Cache.Hash_File (Path));
                     end if;
                  end;
               end loop;
            else
               Start_Search (H_Search, Dir_Path, "");
               begin
                  while More_Entries (H_Search) loop
                     Get_Next_Entry (H_Search, H_Ent);
                     declare
                        N    : constant String := Simple_Name (H_Ent);
                        Path : constant String := Full_Name (H_Ent);
                     begin
                        if Kind (H_Ent) = Directory then
                           if N /= "."
                             and then N /= ".."
                             and then N /= "_build"
                             and then not Skip_Walk_Dir (N)
                           then
                              Push_Dir
                                (H_Stack, Path, Current.Level + 1, Max_Levels);
                           end if;
                        elsif Kind (H_Ent) = Ordinary_File then
                           Add (Adacovex.Cache.Hash_File (Path));
                        end if;
                     end;
                  end loop;
               exception
                  when others =>
                     End_Search (H_Search);
                     raise;
               end;
               End_Search (H_Search);
            end if;
         end;
      end loop;
   end Hash_Tree;

   --  Whether a file name ends with Suffix. A package-named manifest
   --  (*.csproj, *.gemspec, *.podspec, *.rockspec, *.opam, *.cabal) has no
   --  fixed name, so it is matched by suffix.
   --  @param N  File base name.
   --  @param Suffix  Required base-name suffix, for example ".cabal".
   --  @return True when N ends with Suffix and is longer than it.
   function Has_Suffix (N : String; Suffix : String) return Boolean is
   begin
      return
        Suffix'Length > 0
        and then N'Length > Suffix'Length
        and then N (N'Last - Suffix'Length + 1 .. N'Last) = Suffix;
   end Has_Suffix;

   --  Whether a file name is a supported-language project manifest that
   --  can own a vendored directory (the file set Collect_Owner_Test_Names
   --  reads, plus the npm lockfiles it scans) or that shapes the root
   --  declaration set (every manifest Register_Root_Manifest_Deps reads).
   --  Hashing these files makes the graph key sound: editing the owning
   --  manifest's test-labelled sections (or its npm lockfiles, or the
   --  dependencies it declares) invalidates the cached graph so the graph
   --  is rebuilt from the new content.
   --  @param N  File base name.
   --  @return True for the fixed-name manifests and lockfiles (package.json,
   --    Cargo.toml, Cargo.lock, go.mod, composer.json, Gemfile, pom.xml,
   --    pyproject.toml, Package.swift, the npm lockfiles, pubspec.yaml,
   --    DESCRIPTION, META.json, setup.cfg, mix.exs, rebar.config,
   --    conanfile.py, conanfile.txt, build.gradle, build.gradle.kts) and a
   --    file carrying one of the package-named suffixes.
   function Is_Owner_Manifest (N : String) return Boolean is
   begin
      return
        N = "package.json"
        or else N = "Cargo.toml"
        or else N = "Cargo.lock"
        or else N = "Gemfile.lock"
        or else N = "composer.lock"
        or else N = "poetry.lock"
        or else N = "Pipfile.lock"
        or else N = "pubspec.lock"
        or else N = "packages.lock.json"
        or else N = "Package.resolved"
        or else N = "mix.lock"
        or else N = "go.mod"
        or else N = "composer.json"
        or else N = "Gemfile"
        or else N = "pom.xml"
        or else N = "pyproject.toml"
        or else N = "Package.swift"
        or else N = "pnpm-lock.yaml"
        or else N = "package-lock.json"
        or else N = "yarn.lock"
        or else N = "pubspec.yaml"
        or else N = "DESCRIPTION"
        or else N = "META.json"
        or else N = "setup.cfg"
        or else N = "mix.exs"
        or else N = "rebar.config"
        or else N = "conanfile.py"
        or else N = "conanfile.txt"
        or else N = "build.gradle"
        or else N = "build.gradle.kts"
        or else Has_Suffix (N, ".csproj")
        or else Has_Suffix (N, ".gemspec")
        or else Has_Suffix (N, ".podspec")
        or else Has_Suffix (N, ".rockspec")
        or else Has_Suffix (N, ".opam")
        or else Has_Suffix (N, ".cabal");
   end Is_Owner_Manifest;
begin
   --  Classic doc roots (.adacovex/patches, resources, vendor, assets).
   --  Every regular file counts, at any depth (curated and small).
   Hash_Tree (T & "/.adacovex/patches", 99);
   Hash_Tree (T & "/resources", 99);
   Hash_Tree (T & "/vendor", 99);
   Hash_Tree (T & "/assets", 99);

   --  Language-agnostic vendored directories anywhere in the tree (same
   --  discovery walk as Discover_Generic_Vendored, shallow). Supported-
   --  language project manifests that can own a vendored directory (for
   --  example src/tests/e2e/dashboard/package.json owning its
   --  node_modules) are
   --  hashed so an edit to their test-labelled sections invalidates the
   --  cached graph. The manifests inside vendor roots are already
   --  covered by the Hash_Tree calls above.
   Dir_Stack.Clear;
   Push_Dir (Dir_Stack, Target_Dir, 0, 99);
   while not Dir_Stack.Is_Empty loop
      declare
         Current  : Dir_Entry := Dir_Stack.Last_Element;
         Dir_Path : String renames Current.Path (1 .. Current.Len);
      begin
         Dir_Stack.Delete_Last;
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
                       and then N /= ".."
                       and then not Skip_Walk_Dir (N)
                     then
                        if Is_Vendor_Dir_Name (N) then
                           Hash_Tree
                             (Path, (if N = "node_modules" then 1 else 3));
                        else
                           Push_Dir (Dir_Stack, Path, 0, 99);
                        end if;
                     end if;
                  elsif Kind (Ent) = Ordinary_File
                    and then Is_Owner_Manifest (N)
                  then
                     Add (Adacovex.Cache.Hash_File (Path));
                  end if;
               end;
            end loop;
         exception
            when others =>
               End_Search (Search);
               raise;
         end;
         End_Search (Search);
      end;
   end loop;

   if CLen = 0 then
      return "";
   end if;
   return Adacovex.Cache.Hash_String (Comb (1 .. CLen));
end Vendored_Hash;
