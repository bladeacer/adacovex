separate (Adacovex.Parsers.Manifest)
--  Probe Dir for the first recognised ecosystem manifest, in the defined
--  priority order.  The manifest filename maps to an ecosystem through a
--  static table (filename -> PURL kind, primary language, reader); adding
--  an ecosystem is a one-row edit, not a new branch.  Name and version come
--  from the manifest when present.  The caller enriches with licence,
--  version and website from the package registry when the manifest is
--  silent.  requirements*.txt is matched by glob as a final fallback
--  because it is not a fixed filename.
procedure Read_Vendor_Manifest (Dir : String; Info : out Vendor_Manifest) is
   use Ada.Directories;

   type Manifest_Reader is (R_Json, R_Go, R_Gem, R_Maven, R_Swift);
   type Manifest_Row is record
      File    : String (1 .. 16);
      FLen    : Natural;
      Kind    : String (1 .. 8);
      KLen    : Natural;
      Lang    : String (1 .. 16);
      LangLen : Natural;
      Reader  : Manifest_Reader;
   end record;

   Table : constant array (1 .. 8) of Manifest_Row :=
     (1 =>
        (File    => "package.json" & (13 .. 16 => ' '),
         FLen    => 12,
         Kind    => "npm" & (4 .. 8 => ' '),
         KLen    => 3,
         Lang    => "JavaScript" & (11 .. 16 => ' '),
         LangLen => 10,
         Reader  => R_Json),
      2 =>
        (File    => "Cargo.toml" & (11 .. 16 => ' '),
         FLen    => 10,
         Kind    => "cargo" & (6 .. 8 => ' '),
         KLen    => 5,
         Lang    => "Rust" & (5 .. 16 => ' '),
         LangLen => 4,
         Reader  => R_Json),
      3 =>
        (File    => "go.mod" & (7 .. 16 => ' '),
         FLen    => 6,
         Kind    => "golang" & (7 .. 8 => ' '),
         KLen    => 6,
         Lang    => "Go" & (3 .. 16 => ' '),
         LangLen => 2,
         Reader  => R_Go),
      4 =>
        (File    => "pyproject.toml" & (15 .. 16 => ' '),
         FLen    => 14,
         Kind    => "pypi" & (5 .. 8 => ' '),
         KLen    => 4,
         Lang    => "Python" & (7 .. 16 => ' '),
         LangLen => 6,
         Reader  => R_Json),
      5 =>
        (File    => "composer.json" & (14 .. 16 => ' '),
         FLen    => 13,
         Kind    => "composer",
         KLen    => 8,
         Lang    => "PHP" & (4 .. 16 => ' '),
         LangLen => 3,
         Reader  => R_Json),
      6 =>
        (File    => "Gemfile" & (8 .. 16 => ' '),
         FLen    => 7,
         Kind    => "gem" & (4 .. 8 => ' '),
         KLen    => 3,
         Lang    => "Ruby" & (5 .. 16 => ' '),
         LangLen => 4,
         Reader  => R_Gem),
      7 =>
        (File    => "pom.xml" & (8 .. 16 => ' '),
         FLen    => 7,
         Kind    => "maven" & (6 .. 8 => ' '),
         KLen    => 5,
         Lang    => "Java" & (5 .. 16 => ' '),
         LangLen => 4,
         Reader  => R_Maven),
      8 =>
        (File    => "Package.swift" & (14 .. 16 => ' '),
         FLen    => 13,
         Kind    => "swift" & (6 .. 8 => ' '),
         KLen    => 5,
         Lang    => "Swift" & (6 .. 16 => ' '),
         LangLen => 5,
         Reader  => R_Swift));

   procedure Set_Text
     (DST : out Types.Desc_Field; DST_Len : out Natural; S : String) is
   begin
      DST_Len := S'Length;
      if DST_Len > Types.Max_Desc_Str then
         DST_Len := Types.Max_Desc_Str;
      end if;
      for I in 1 .. DST_Len loop
         DST (I) := S (S'First + I - 1);
      end loop;
   end Set_Text;

   procedure Set_Kind (K : String) is
   begin
      if K'Length <= Info.PURL_Kind'Last then
         Info.PURL_Kind_Len := K'Length;
         Info.PURL_Kind (1 .. K'Length) := K;
      end if;
   end Set_Kind;

   procedure Set_Lang (L : String) is
   begin
      if L'Length <= Info.Primary_Lang'Last then
         Info.Primary_Lang_Len := L'Length;
         Info.Primary_Lang (1 .. L'Length) := L;
      end if;
   end Set_Lang;

   function Path (N : String) return String is
   begin
      return Dir & "/" & N;
   end Path;

begin
   Info.Found := False;
   Info.PURL_Kind_Len := 0;
   Info.Primary_Lang_Len := 0;
   Info.Name_Len := 0;
   Info.Version_Len := 0;
   Info.License_Len := 0;

   for I in Table'Range loop
      if Exists (Path (Table (I).File (1 .. Table (I).FLen))) then
         Set_Kind (Table (I).Kind (1 .. Table (I).KLen));
         Set_Lang (Table (I).Lang (1 .. Table (I).LangLen));
         case Table (I).Reader is
            when R_Json  =>
               Set_Text
                 (Info.Name,
                  Info.Name_Len,
                  File_Quoted_Value
                    (Path (Table (I).File (1 .. Table (I).FLen)), "name"));
               Set_Text
                 (Info.Version,
                  Info.Version_Len,
                  File_Quoted_Value
                    (Path (Table (I).File (1 .. Table (I).FLen)), "version"));
               Set_Text
                 (Info.License,
                  Info.License_Len,
                  File_Quoted_Value
                    (Path (Table (I).File (1 .. Table (I).FLen)), "license"));

            when R_Go    =>
               Set_Text
                 (Info.Name,
                  Info.Name_Len,
                  Go_Module_Path
                    (Path (Table (I).File (1 .. Table (I).FLen))));

            when R_Gem   =>
               declare
                  G_N : String (1 .. 64) := (others => ' ');
                  G_V : String (1 .. 64) := (others => ' ');
                  N_L : Natural := 0;
                  V_L : Natural := 0;
               begin
                  Gem_Entry
                    (Path (Table (I).File (1 .. Table (I).FLen)),
                     G_N,
                     N_L,
                     G_V,
                     V_L);
                  Set_Text (Info.Name, Info.Name_Len, G_N (1 .. N_L));
                  Set_Text (Info.Version, Info.Version_Len, G_V (1 .. V_L));
               end;

            when R_Maven =>
               declare
                  A : constant String :=
                    Xml_Tag_Value
                      (Path (Table (I).File (1 .. Table (I).FLen)),
                       "artifactId");
                  G : constant String :=
                    Xml_Tag_Value
                      (Path (Table (I).File (1 .. Table (I).FLen)), "groupId");
                  V : constant String :=
                    Xml_Tag_Value
                      (Path (Table (I).File (1 .. Table (I).FLen)), "version");
               begin
                  if G'Length > 0 then
                     Set_Text (Info.Name, Info.Name_Len, G & ":" & A);
                  else
                     Set_Text (Info.Name, Info.Name_Len, A);
                  end if;
                  Set_Text (Info.Version, Info.Version_Len, V);
               end;

            when R_Swift =>
               null;
         end case;
         Info.Found := True;
         return;
      end if;
   end loop;

   --  requirements*.txt (pick the first match).
   declare
      Search : Search_Type;
      Ent    : Directory_Entry_Type;
      Found  : Boolean := False;
   begin
      Start_Search (Search, Dir, "requirements*.txt");
      while not Found and then More_Entries (Search) loop
         Get_Next_Entry (Search, Ent);
         if Kind (Ent) = Ordinary_File then
            declare
               R_N : String (1 .. 64) := (others => ' ');
               R_V : String (1 .. 64) := (others => ' ');
               N_L : Natural := 0;
               V_L : Natural := 0;
            begin
               Req_Entry (Full_Name (Ent), R_N, N_L, R_V, V_L);
               Set_Text (Info.Name, Info.Name_Len, R_N (1 .. N_L));
               Set_Text (Info.Version, Info.Version_Len, R_V (1 .. V_L));
            end;
            Set_Kind ("pypi");
            Set_Lang ("Python");
            Info.Found := True;
            Found := True;
         end if;
      end loop;
      End_Search (Search);
   end;
end Read_Vendor_Manifest;
