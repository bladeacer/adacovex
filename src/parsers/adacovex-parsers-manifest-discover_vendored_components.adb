separate (Adacovex.Parsers.Manifest)
--  Add a component for every vendored package overlaid by a docstring
--  patch under <target>/.adacovex/patches/.  Add a component for every
--  web asset under resources/ or assets/.  Add a component for every
--  source file under vendor/ (the classic Alire-era vendored roots).
--  Each file becomes a scope=vendored component named after its base
--  name.  The language comes from the file extension.  Such packages
--  have no manifest entry and no .gpr of their own.  They are recorded
--  as Scope_Vendored dependencies of the root.
procedure Discover_Vendored_Components
  (Target_Dir : String;
   Graph      : in out Types.Implementation.Component_Vectors.Vector)
is
   use Ada.Directories;
   type Dir_Entry is record
      Path : Types.Path_Field;
      Len  : Natural := 0;
   end record;
   package Dir_Stacks is new Ada.Containers.Vectors (Positive, Dir_Entry);
   Dir_Stack : Dir_Stacks.Vector;
   Search    : Search_Type;
   Ent       : Directory_Entry_Type;

   procedure Push_Dir (Dir : String) is
      Item : Dir_Entry;
   begin
      if Dir'Length <= Types.Max_Path then
         Item.Len := Dir'Length;
         for I in Dir'Range loop
            Item.Path (I - Dir'First + 1) := Dir (I);
         end loop;
         Dir_Stack.Append (Item);
      end if;
   end Push_Dir;

   procedure Add_Vendored (Ads_Path : String) is
      Base : constant String := Simple_Name (Ads_Path);
      Dot  : Natural := 0;
   begin
      for I in reverse Base'Range loop
         if Base (I) = '.' then
            Dot := I;
            exit;
         end if;
      end loop;
      if Dot <= Base'First then
         return;
      end if;
      Append_Dependency
        (Graph,
         Base (Base'First .. Dot - 1),
         "",
         "",
         "",
         "pkg:gpr/" & Base (Base'First .. Dot - 1),
         1,
         False,
         Types.Scope_Vendored,
         "Ada");
   end Add_Vendored;

   subtype Lib_Name_Field is String (1 .. 32);
   --  Return the upstream npm package name and version for a bundled
   --  dashboard asset, or False for an unknown asset.  The dashboard
   --  vendors exactly four third-party libraries into the binary
   --  (resources/*.js|css); their versions are stable build-time
   --  constants (also listed in the Credits tab and docs/dashboard.md).
   --  adacovex's own dashboard sources match none of these and never
   --  become packages.  The licence and website are no longer hard-coded:
   --  the caller resolves them live from the registry (preferring pnpm,
   --  then npm, then yarn, then bun) via Resolve_Ecosystem_Metadata, so
   --  the SBOM and Credits tab track the real upstream licence.
   function Bundled_Library
     (Raw      : String;
      Npm_Name : out Lib_Name_Field;
      NN       : out Natural;
      Lib_Ver  : out Lib_Name_Field;
      VN       : out Natural) return Boolean
   is
      N : String (1 .. 32) := (others => ' ');
      V : String (1 .. 32) := (others => ' ');
   begin
      if Raw = "flexsearch" then
         N (1 .. 10) := "flexsearch";
         NN := 10;
         V (1 .. 6) := "0.7.31";
         VN := 6;
      elsif Raw = "nomnoml" then
         N (1 .. 7) := "nomnoml";
         NN := 7;
         V (1 .. 5) := "1.7.0";
         VN := 5;
      elsif Raw = "graphre" then
         N (1 .. 7) := "graphre";
         NN := 7;
         V (1 .. 5) := "0.1.3";
         VN := 5;
      elsif Raw = "charts.min" then
         N (1 .. 10) := "charts.css";
         NN := 10;
         V (1 .. 5) := "1.2.0";
         VN := 5;
      else
         return False;
      end if;
      Npm_Name := N;
      Lib_Ver := V;
      return True;
   end Bundled_Library;

   procedure Add_Vendored_Asset (Asset_Path : String) is
      Base    : constant String := Simple_Name (Asset_Path);
      Dot     : Natural := 0;
      Raw     : String (1 .. 64) := (others => ' ');
      Raw_Len : Natural := 0;
      Name    : String (1 .. 64) := (others => ' ');
      NLen    : Natural := 0;
   begin
      for I in reverse Base'Range loop
         if Base (I) = '.' then
            Dot := I;
            exit;
         end if;
      end loop;
      if Dot <= Base'First then
         return;
      end if;
      Raw_Len := Dot - Base'First;
      if Raw_Len > 64 then
         Raw_Len := 64;
      end if;
      for I in 1 .. Raw_Len loop
         Raw (I) := Base (Base'First + I - 1);
      end loop;
      --  adacovex's own dashboard sources are not a package and never
      --  become SBOM components.
      if Raw_Len = 9 and then Raw (1 .. 9) = "dashboard" then
         return;
      end if;
      --  The component name is the raw base name, bounded to 64.
      NLen := Raw_Len;
      Name (1 .. NLen) := Raw (1 .. NLen);
      --  Known bundled libraries get their upstream npm name and version,
      --  and a PURL; everything else keeps the generic fallback.  The
      --  licence and website are resolved live from the registry (preferring
      --  pnpm, then npm, then yarn, then bun) so the SBOM and Credits tab
      --  track the real upstream licence rather than a built-in copy.  The
      --  version stays the build-time constant (the actual vendored file).
      --  The language comes from the asset's extension (.js -> JavaScript,
      --  .css -> CSS), like every other vendored file.
      declare
         NN       : Natural := 0;
         VN       : Natural := 0;
         Npm_Name : Lib_Name_Field := (others => ' ');
         Lib_Ver  : Lib_Name_Field := (others => ' ');
         Lic      : Types.Desc_Field := (others => ' ');
         Lic_Len  : Natural := 0;
         Ver      : Types.Desc_Field := (others => ' ');
         Ver_Len  : Natural := 0;
         Web      : Types.Path_Field := (others => ' ');
         Web_Len  : Natural := 0;
      begin
         if Bundled_Library (Raw (1 .. Raw_Len), Npm_Name, NN, Lib_Ver, VN)
         then
            Resolve_Ecosystem_Metadata
              (Target_Dir,
               "npm",
               Npm_Name (1 .. NN),
               Lic,
               Lic_Len,
               Ver,
               Ver_Len,
               Web,
               Web_Len);
            Append_Dependency
              (Graph,
               Npm_Name (1 .. NN),
               Lib_Ver (1 .. VN),
               Lic (1 .. Lic_Len),
               Web (1 .. Web_Len),
               "pkg:npm/" & Npm_Name (1 .. NN) & "@" & Lib_Ver (1 .. VN),
               1,
               False,
               Types.Scope_Vendored,
               Extension_Language (Base));
         else
            Append_Dependency
              (Graph,
               Name (1 .. NLen),
               "",
               "",
               "",
               "pkg:generic/" & Name (1 .. NLen),
               1,
               False,
               Types.Scope_Vendored,
               Extension_Language (Base));
         end if;
      end;
   end Add_Vendored_Asset;

   procedure Scan_One_Vendored_Root (Root : String) is
   begin
      if not Ada.Directories.Exists (Root) then
         return;
      end if;
      Dir_Stack.Clear;
      Push_Dir (Root);
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
                        if N /= "." and N /= ".." then
                           Push_Dir (Path);
                        end if;
                     elsif Kind (Ent) = Ordinary_File then
                        if N'Length > 4
                          and then N (N'Last - 3 .. N'Last) = ".ads"
                        then
                           Add_Vendored (Path);
                        elsif N'Length > 3
                          and then (N (N'Last - 2 .. N'Last) = ".js"
                                    or else N (N'Last - 3 .. N'Last) = ".css")
                        then
                           Add_Vendored_Asset (Path);
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
   end Scan_One_Vendored_Root;

   Patches_Root   : constant String :=
     (if Target_Dir'Length > 0 and then Target_Dir (Target_Dir'Last) = '/'
      then Target_Dir (Target_Dir'First .. Target_Dir'Last - 1)
      else Target_Dir)
     & "/.adacovex/patches";
   Resources_Root : constant String :=
     (if Target_Dir'Length > 0 and then Target_Dir (Target_Dir'Last) = '/'
      then Target_Dir (Target_Dir'First .. Target_Dir'Last - 1)
      else Target_Dir)
     & "/resources";
   --  The vendor/ root itself is not scanned here.  Loose files under it
   --  must never become components.  Discover_Generic_Vendored turns each
   --  manifest-carrying or source-carrying vendor subdirectory into one
   --  component.  The component carries its top-3 language summary.
   Assets_Root    : constant String :=
     (if Target_Dir'Length > 0 and then Target_Dir (Target_Dir'Last) = '/'
      then Target_Dir (Target_Dir'First .. Target_Dir'Last - 1)
      else Target_Dir)
     & "/assets";
begin
   Scan_One_Vendored_Root (Patches_Root);
   Scan_One_Vendored_Root (Resources_Root);
   Scan_One_Vendored_Root (Assets_Root);
end Discover_Vendored_Components;
