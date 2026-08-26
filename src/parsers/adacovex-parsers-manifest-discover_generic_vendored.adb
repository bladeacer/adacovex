separate (Adacovex.Parsers.Manifest)
--  Language-agnostic vendored-component discovery.  Walk the target tree
--  (excluding VCS, build, and installer noise).  Treat every directory
--  whose base name is a known vendor directory as a vendored source.
--  Scan it shallowly (max 2 levels):
--    * A directory that carries an ecosystem manifest (package.json,
--      Cargo.toml, go.mod, pyproject.toml, composer.json, Gemfile,
--      pom.xml, Package.swift, requirements*.txt) becomes one
--      Scope_Vendored component.  The manifest names and versions it.
--      Its ecosystem PURL is pkg:npm/... or pkg:cargo/... and more.
--    * A directory that holds Ada sources (.ads/.adb) without a manifest
--      becomes a Scope_Vendored Ada component.  It is named after the
--      directory (for example a hand-vendored Ada library under
--      third_party/).  npm scope containers (node_modules/@scope without
--      a manifest) never become components; the scoped package below
--      them does.  pnpm store and shim dirs (.pnpm, .bin) are skipped
--      entirely -- they are not packages.
--  Every component carries its language or languages.  The languages are
--  detected from file extensions.  The ecosystem language is first.  The
--  top 3 are used and mixed sources list the leading languages.
procedure Discover_Generic_Vendored
  (Target_Dir : String;
   Graph      : in out Types.Implementation.Component_Vectors.Vector)
is
   use Ada.Directories;
   type Dir_Entry is record
      Path  : Types.Path_Field;
      Len   : Natural := 0;
      Level : Natural := 0;
   end record;
   package Dir_Stacks is new Ada.Containers.Vectors (Positive, Dir_Entry);
   Tree_Stack : Dir_Stacks.Vector;
   Scan_Stack : Dir_Stacks.Vector;
   Search     : Search_Type;
   Ent        : Directory_Entry_Type;

   procedure Push_Dir
     (S : in out Dir_Stacks.Vector; Dir : String; Level : Natural)
   is
      Item : Dir_Entry;
   begin
      if Dir'Length <= Types.Max_Path then
         Item.Len := Dir'Length;
         for I in Dir'Range loop
            Item.Path (I - Dir'First + 1) := Dir (I);
         end loop;
         Item.Level := Level;
         S.Append (Item);
      end if;
   end Push_Dir;

   --  Directory names inside a vendor root that never represent a
   --  package: pnpm's virtual store (.pnpm holds lock.yaml + the
   --  resolved store, not a dependency) and the .bin shim dir.  They are
   --  skipped entirely -- never descended into, never componentised.
   function Skip_Vendor_Scan_Dir (N : String) return Boolean is
   begin
      return N = ".pnpm" or else N = ".bin";
   end Skip_Vendor_Scan_Dir;

   --  One component per manifest-carrying (or Ada-source-carrying)
   --  directory inside a matched vendor root.  The scan is shallow.  It
   --  uses its own directory-search handles.  It can run while the
   --  caller's tree walk is mid-search.
   procedure Scan_Vendor_Root (Root : String; Max_Levels : Natural) is
      S2 : Search_Type;
      E2 : Directory_Entry_Type;
   begin
      Scan_Stack.Clear;
      Push_Dir (Scan_Stack, Root, 0);
      while not Scan_Stack.Is_Empty loop
         declare
            Current  : Dir_Entry := Scan_Stack.Last_Element;
            Dir_Path : String renames Current.Path (1 .. Current.Len);
         begin
            Scan_Stack.Delete_Last;
            --  Subdirectory bookkeeping: descend up to Max_Levels.
            Start_Search (S2, Dir_Path, "");
            begin
               while More_Entries (S2) loop
                  Get_Next_Entry (S2, E2);
                  declare
                     N    : constant String := Simple_Name (E2);
                     Path : constant String := Full_Name (E2);
                  begin
                     if Kind (E2) = Directory then
                        if N /= "."
                          and then N /= ".."
                          and then not Skip_Vendor_Scan_Dir (N)
                          and then Current.Level < Max_Levels
                        then
                           Push_Dir (Scan_Stack, Path, Current.Level + 1);
                        end if;
                     end if;
                  end;
               end loop;
            exception
               when others =>
                  End_Search (S2);
                  raise;
            end;
            End_Search (S2);

            --  Component source: ecosystem manifest or source files.
            --  The vendor root itself (level 0) is not a component.  Only
            --  its children are components.
            if Current.Level > 0 then
               declare
                  M : Vendor_Manifest;
               begin
                  Read_Vendor_Manifest (Dir_Path, M);
                  if M.Found then
                     declare
                        N       : String :=
                          (if M.Name_Len > 0
                           then M.Name (1 .. M.Name_Len)
                           else Simple_Name (Dir_Path));
                        V       : String :=
                          (if M.Version_Len > 0
                           then M.Version (1 .. M.Version_Len)
                           else "");
                        Lic_Buf : Types.Desc_Field;
                        Lic_Len : Natural := 0;
                        Ver_Buf : Types.Desc_Field;
                        Ver_Len : Natural := 0;
                        Web_Buf : Types.Path_Field;
                        Web_Len : Natural := 0;
                        Pur     : String :=
                          "pkg:"
                          & M.PURL_Kind (1 .. M.PURL_Kind_Len)
                          & "/"
                          & N
                          & (if V'Length > 0 then "@" & V else "");
                        L       : constant String :=
                          Language_Of_Dir
                            (Dir_Path,
                             2,
                             M.Primary_Lang (1 .. M.Primary_Lang_Len));
                     begin
                        --  The vendored-manifest scanner reads name and
                        --  version offline.  The registry resolver enriches
                        --  with version and website (which the in-repo
                        --  scanner does not capture) and supplies the
                        --  licence when the manifest ships none.  Local
                        --  values win; the registry fills the gaps.
                        Resolve_Ecosystem_Metadata
                          (M.PURL_Kind (1 .. M.PURL_Kind_Len),
                           N,
                           Lic_Buf,
                           Lic_Len,
                           Ver_Buf,
                           Ver_Len,
                           Web_Buf,
                           Web_Len);
                        declare
                           Lic : constant String :=
                             (if M.License_Len > 0
                              then M.License (1 .. M.License_Len)
                              elsif Lic_Len > 0
                              then Lic_Buf (1 .. Lic_Len)
                              else "");
                           Ver : constant String :=
                             (if V'Length > 0
                              then V
                              elsif Ver_Len > 0
                              then Ver_Buf (1 .. Ver_Len)
                              else "");
                           Web : constant String :=
                             (if Web_Len > 0
                              then Web_Buf (1 .. Web_Len)
                              else "");
                        begin
                           Append_Dependency
                             (Graph,
                              N,
                              Ver,
                              Lic,
                              "",
                              Pur,
                              1,
                              False,
                              Types.Scope_Vendored,
                              L,
                              Web);
                        end;
                     end;
                  else
                     --  Library vendored without a manifest.  The directory
                     --  itself is the component.  The language is the top-3
                     --  summary of its source-file extensions.  Ada-only
                     --  directories are included.  npm scope containers
                     --  (a node_modules/@scope directory without its own
                     --  package.json) are never components themselves --
                     --  only the scoped package below them is.
                     declare
                        Dir_N : constant String := Simple_Name (Dir_Path);
                        L     : constant String :=
                          Language_Of_Dir (Dir_Path, 2);
                     begin
                        if L'Length > 0
                          and then (Dir_N'Length = 0
                                    or else Dir_N (Dir_N'First) /= '@')
                        then
                           Append_Dependency
                             (Graph,
                              Dir_N,
                              "",
                              "",
                              "",
                              "pkg:generic/" & Dir_N,
                              1,
                              False,
                              Types.Scope_Vendored,
                              L);
                        end if;
                     end;
                  end if;
               end;
            end if;
         end;
      end loop;
   end Scan_Vendor_Root;
begin
   Push_Dir (Tree_Stack, Target_Dir, 0);
   while not Tree_Stack.Is_Empty loop
      declare
         Current  : Dir_Entry := Tree_Stack.Last_Element;
         Dir_Path : String renames Current.Path (1 .. Current.Len);
      begin
         Tree_Stack.Delete_Last;
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
                           --  node_modules needs depth 2 so scoped
                           --  packages (node_modules/@scope/pkg) resolve;
                           --  the pnpm store (.pnpm) and .bin are skipped
                           --  inside the scan itself.
                           Scan_Vendor_Root (Path, 2);
                        else
                           Push_Dir (Tree_Stack, Path, 0);
                        end if;
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
      end;
   end loop;
end Discover_Generic_Vendored;
