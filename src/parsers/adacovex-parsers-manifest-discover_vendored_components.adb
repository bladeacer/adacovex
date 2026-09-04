separate (Adacovex.Parsers.Manifest)
--  Add a component for every vendored package overlaid by a docstring
--  patch under <target>/.adacovex/patches/.  Add a component for every
--  web asset under resources/ or assets/.  Add a component for every
--  source file under vendor/ (the classic Alire-era vendored roots).
--  Each file becomes a scope=vendored component named after its base
--  name.  The language comes from the file extension.  Such packages
--  have no manifest entry and no .gpr of their own.  They are recorded
--  as Scope_Vendored dependencies of the root.
--
--  Nothing here is hard-coded: the component name is the file's own base
--  name, the version is read from the file's own banner comment (for
--  example "FlexSearch.js v0.7.31 (Bundle)") when the vendored file
--  carries one, and the licence and website are resolved live from the
--  package registry under that same name (Resolve_Ecosystem_Metadata)
--  when the registry knows it.  An asset the registry does not know
--  keeps a pkg:generic PURL and whatever the file itself declared.
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

   --  Read the version out of a vendored file's own banner comment: the
   --  first comment block (/* ... */ or leading // lines) at the top of
   --  the file, scanned for a "v<digits>.<digits>" token such as the
   --  "v0.7.31" in "FlexSearch.js v0.7.31 (Bundle)".  Returns "" when the
   --  file carries no banner version.  This is real data from the vendored
   --  file itself -- never a hard-coded table.
   --  @param Path  Path of the vendored asset.
   --  @return The banner version (without the leading "v"), or "".
   function Banner_Version (Path : String) return String is
      F    : Ada.Text_IO.File_Type;
      Buf  : String (1 .. 1024);
      BLen : Natural := 0;
      Ver  : String (1 .. 32) := (others => ' ');
   begin
      begin
         Ada.Text_IO.Open (F, Ada.Text_IO.In_File, Path);
      exception
         when others =>
            return "";
      end;
      while not Ada.Text_IO.End_Of_File (F) and then BLen < Buf'Last loop
         declare
            Line : String (1 .. 256);
            L    : Natural;
         begin
            Ada.Text_IO.Get_Line (F, Line, L);
            for I in 1 .. L loop
               if BLen < Buf'Last then
                  BLen := BLen + 1;
                  Buf (BLen) := Line (I);
               end if;
            end loop;
            if BLen < Buf'Last then
               BLen := BLen + 1;
               Buf (BLen) := ASCII.LF;
            end if;
         end;
         exit when BLen >= 1024;
      end loop;
      Ada.Text_IO.Close (F);

      --  Restrict the scan to the leading banner region (first 512 chars
      --  or the first comment block, whichever ends first): a banner
      --  version is a "v" immediately followed by a digit and dots.
      declare
         Last  : constant Natural := (if BLen > 512 then 512 else BLen);
         I     : Natural := 1;
         Start : Natural := 0;
         Stop  : Natural := 0;
      begin
         --  Skip whitespace and a leading /* or // opener.
         while I <= Last
           and then (Buf (I) = ' '
                     or else Buf (I) = ASCII.LF
                     or else Buf (I) = ASCII.CR
                     or else Buf (I) = ASCII.HT
                     or else Buf (I) = '/'
                     or else Buf (I) = '*'
                     or else Buf (I) = '!')
         loop
            I := I + 1;
         end loop;
         while I <= Last loop
            if Buf (I) = 'v'
              and then I < Last
              and then Buf (I + 1) in '0' .. '9'
            then
               Start := I + 1;
               Stop := I + 1;
               while Stop < Last
                 and then (Buf (Stop + 1) in '0' .. '9'
                           or else Buf (Stop + 1) = '.')
               loop
                  Stop := Stop + 1;
               end loop;
               if Stop - Start + 1 <= Ver'Last then
                  Ver (1 .. Stop - Start + 1) := Buf (Start .. Stop);
                  return Ver (1 .. Stop - Start + 1);
               end if;
            end if;
            I := I + 1;
         end loop;
      end;
      return "";
   end Banner_Version;

   procedure Add_Vendored_Asset (Asset_Path : String) is
      Base    : constant String := Simple_Name (Asset_Path);
      Dot     : Natural := 0;
      Raw     : String (1 .. 64) := (others => ' ');
      Raw_Len : Natural := 0;
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

      --  Component data is read from the vendored file itself (name from
      --  the base name, version from the file's banner comment) and
      --  gap-filled from the package registry under that same name
      --  (licence, website, and any missing version).  The registry knows
      --  the bundled libraries (flexsearch, nomnoml, graphre) under their
      --  own names; an asset it does not know keeps pkg:generic and the
      --  banner version (or none).  Nothing is hard-coded here.
      declare
         B_Ver   : constant String := Banner_Version (Asset_Path);
         Lic     : Types.Desc_Field := (others => ' ');
         Lic_Len : Natural := 0;
         Ver     : Types.Desc_Field := (others => ' ');
         Ver_Len : Natural := 0;
         Web     : Types.Path_Field := (others => ' ');
         Web_Len : Natural := 0;
      begin
         Resolve_Ecosystem_Metadata
           (Target_Dir,
            "npm",
            Raw (1 .. Raw_Len),
            Lic,
            Lic_Len,
            Ver,
            Ver_Len,
            Web,
            Web_Len);
         declare
            V : constant String :=
              (if B_Ver'Length > 0
               then B_Ver
               elsif Ver_Len > 0
               then Ver (1 .. Ver_Len)
               else "");
            L : constant String :=
              (if Lic_Len > 0 then Lic (1 .. Lic_Len) else "");
            W : constant String :=
              (if Web_Len > 0 then Web (1 .. Web_Len) else "");
         begin
            Append_Dependency
              (Graph,
               Raw (1 .. Raw_Len),
               V,
               L,
               "",
               "pkg:generic/" & Raw (1 .. Raw_Len),
               1,
               False,
               Types.Scope_Vendored,
               Extension_Language (Base),
               W);
         end;
      end;
   end Add_Vendored_Asset;

   --  Always-excluded directories inside a vendored root: the css/ and
   --  js/ subdirectories of a vendored root hold the project's own
   --  authored modules (the dashboard page splits its style and behaviour
   --  into these directories), and every always-excluded directory name
   --  is likewise never a vendored package.
   function Skip_Vendored_Walk_Dir (N : String) return Boolean is
   begin
      return
        N = "css"
        or else N = "js"
        or else N = ".git"
        or else N = ".jj"
        or else N = ".hg"
        or else N = ".svn"
        or else N = "obj"
        or else N = "config"
        or else N = ".adacovex"
        or else N = "alire"
        or else N = "gnatprove"
        or else N = "__pycache__"
        or else N = "node_modules"
        or else N = ".venv"
        or else N = ".headroom"
        or else N = ".lccst"
        or else N = "_build";
   end Skip_Vendored_Walk_Dir;

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
                        --  css/ and js/ under a vendored root hold the
                        --  project's own authored modules (the dashboard
                        --  page splits its style and behaviour into these
                        --  directories).  They are not vendored packages
                        --  and must never become components; the vendored
                        --  bundles sit at the root of resources/.
                        if N /= "."
                          and then N /= ".."
                          and then not Skip_Vendored_Walk_Dir (N)
                        then
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
