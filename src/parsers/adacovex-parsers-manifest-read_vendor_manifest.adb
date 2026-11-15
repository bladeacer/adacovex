separate (Adacovex.Parsers.Manifest)
--  Probe Dir for the first recognised ecosystem manifest, in the defined
--  priority order. The manifest filename maps to an ecosystem through a
--  static table (filename -> PURL kind, registry token, primary language,
--  keys, reader); adding an ecosystem is a one-row edit, not a new branch.
--  The table covers every language Anchore's syft catalogues from a source
--  tree plus Ada, which adacovex resolves from its own Alire and GPR
--  manifests: npm, cargo, golang, pypi, composer, gem, maven, swift, pub
--  (Dart), nuget (.NET), hex (Elixir and Erlang), cpan (Perl), cran (R),
--  conan (C/C++), cocoapods, luarocks (Lua), opam (OCaml), and hackage
--  (Haskell).
--  Six ecosystems name their manifest after the package rather than after
--  the ecosystem (*.csproj, *.gemspec, *.podspec, *.rockspec, *.opam,
--  *.cabal), so a row can carry a suffix instead of a fixed filename.
--  The registry token is the PURL kind except for Go, whose PURL type is
--  "golang" while its registry CLI is "go"; Eco holds it so the resolver
--  dispatches on the token its table is keyed by. An ecosystem with no
--  reliable registry CLI carries the empty token: the resolver then returns
--  quietly and only the in-repo reads answer. Name, version, and licence
--  come from the manifest through the row's own keys, and a licence file
--  beside the manifest is classified into an SPDX identifier when the
--  manifest states none. The caller enriches with version and website from
--  the package registry when the manifest is silent.
--  requirements*.txt is matched by glob as a final fallback because it is
--  not a fixed filename.
--  Modules is the parsed vendor manifest of the vendor root the component
--  was found under, empty when the tree carries none. It is parsed once per
--  vendor root by the caller and looked up in memory here.
procedure Read_Vendor_Manifest
  (Dir     : String;
   Modules : Go_Module_Vectors.Vector;
   Info    : out Vendor_Manifest)
is
   use Ada.Directories;

   type Manifest_Reader is
     (R_Json,
      R_Toml,
      R_Pyproj,
      R_Go,
      R_Gem,
      R_Maven,
      R_Swift,
      R_Xml,
      R_Colon,
      R_Equals,
      R_Either,
      R_Braced);

   type Manifest_Row is record
      File     : String (1 .. 24);
      FLen     : Natural;
      --  Whether File is a base-name suffix rather than a fixed filename.
      Suffix   : Boolean;
      Kind     : String (1 .. 10);
      KLen     : Natural;
      Eco      : String (1 .. 10);
      ELen     : Natural;
      Lang     : String (1 .. 16);
      LangLen  : Natural;
      Reader   : Manifest_Reader;
      Name_Key : String (1 .. 24);
      NKLen    : Natural;
      Ver_Key  : String (1 .. 24);
      VKLen    : Natural;
      Lic_Key  : String (1 .. 24);
      LKLen    : Natural;
      --  The TOML section the R_Toml reader reads, "" for the top level.
      Sect     : String (1 .. 16);
      SLen     : Natural;
   end record;

   --  Build one table row from string literals, so the table below reads as
   --  data. A field longer than its component is left empty rather than
   --  truncated: a silently cut filename could match the wrong manifest.
   function Row
     (File     : String;
      Suffix   : Boolean;
      Kind     : String;
      Eco      : String;
      Lang     : String;
      Reader   : Manifest_Reader;
      Name_Key : String := "";
      Ver_Key  : String := "";
      Lic_Key  : String := "";
      Sect     : String := "") return Manifest_Row
   is
      R : Manifest_Row :=
        (File     => (others => ' '),
         FLen     => 0,
         Suffix   => Suffix,
         Kind     => (others => ' '),
         KLen     => 0,
         Eco      => (others => ' '),
         ELen     => 0,
         Lang     => (others => ' '),
         LangLen  => 0,
         Reader   => Reader,
         Name_Key => (others => ' '),
         NKLen    => 0,
         Ver_Key  => (others => ' '),
         VKLen    => 0,
         Lic_Key  => (others => ' '),
         LKLen    => 0,
         Sect     => (others => ' '),
         SLen     => 0);

      procedure Put (Dst : in out String; DLen : in out Natural; S : String) is
      begin
         if S'Length <= Dst'Length then
            DLen := S'Length;
            Dst (1 .. S'Length) := S;
         end if;
      end Put;
   begin
      Put (R.File, R.FLen, File);
      Put (R.Kind, R.KLen, Kind);
      Put (R.Eco, R.ELen, Eco);
      Put (R.Lang, R.LangLen, Lang);
      Put (R.Name_Key, R.NKLen, Name_Key);
      Put (R.Ver_Key, R.VKLen, Ver_Key);
      Put (R.Lic_Key, R.LKLen, Lic_Key);
      Put (R.Sect, R.SLen, Sect);
      return R;
   end Row;

   --  The separator style the generic key/value reader uses for a row.
   --  @param R  The row's reader kind.
   --  @return "colon", "equals", "either", or "braced" ("" for a reader
   --    that is not the generic one).
   function Style_Of (R : Manifest_Reader) return String is
   begin
      case R is
         when R_Colon  =>
            return "colon";

         when R_Equals =>
            return "equals";

         when R_Either =>
            return "either";

         when R_Braced =>
            return "braced";

         when others   =>
            return "";
      end case;
   end Style_Of;

   --  The row's key text, "" when the row carries none.
   function Key (K : String; KLen : Natural) return String is
   begin
      if KLen = 0 then
         return "";
      end if;
      return K (1 .. KLen);
   end Key;

   --  Fixed-name rows first, so a package that also ships a suffixed
   --  manifest in the same directory keeps the ecosystem's primary
   --  identity. The suffix rows follow; their order is the tie-break when
   --  a directory carries more than one of them.
   Table : constant array (1 .. 25) of Manifest_Row :=
     (Row
        ("package.json",
         False,
         "npm",
         "npm",
         "JavaScript",
         R_Json,
         "name",
         "version",
         "license"),
      Row
        ("Cargo.toml",
         False,
         "cargo",
         "cargo",
         "Rust",
         R_Toml,
         "name",
         "version",
         "license",
         "package"),
      --  A vendored Ada crate states its identity at the top level of
      --  alire.toml (no section header), so the row reads the file's top
      --  level rather than a table.
      Row
        ("alire.toml",
         False,
         "alire",
         "alire",
         "Ada",
         R_Toml,
         "name",
         "version",
         "licenses"),
      Row ("go.mod", False, "golang", "go", "Go", R_Go),
      Row
        ("pyproject.toml",
         False,
         "pypi",
         "pypi",
         "Python",
         R_Pyproj,
         "name",
         "version",
         "license"),
      Row
        ("setup.cfg",
         False,
         "pypi",
         "",
         "Python",
         R_Equals,
         "name",
         "version",
         "license"),
      Row
        ("composer.json",
         False,
         "composer",
         "",
         "PHP",
         R_Json,
         "name",
         "version",
         "license"),
      --  CPAN's META.json states its licence in CPAN's own vocabulary
      --  ("perl_5", "apache_2_0"), which is not SPDX, so the field is not
      --  read as one: a licence file beside the manifest classifies into an
      --  SPDX id.
      Row
        ("META.json",
         False,
         "cpan",
         "",
         "Perl",
         R_Json,
         "name",
         "version",
         ""),
      Row ("Gemfile", False, "gem", "", "Ruby", R_Gem),
      Row
        ("pom.xml",
         False,
         "maven",
         "",
         "Java",
         R_Maven,
         "artifactId",
         "version",
         ""),
      Row ("Package.swift", False, "swift", "", "Swift", R_Swift),
      Row
        ("pubspec.yaml",
         False,
         "pub",
         "",
         "Dart",
         R_Colon,
         "name",
         "version",
         ""),
      Row
        ("mix.exs",
         False,
         "hex",
         "",
         "Elixir",
         R_Either,
         "app",
         "version",
         ""),
      Row
        ("rebar.config", False, "hex", "", "Erlang", R_Braced, "", "vsn", ""),
      Row
        ("conanfile.py",
         False,
         "conan",
         "",
         "C++",
         R_Equals,
         "name",
         "version",
         "license"),
      Row ("conanfile.txt", False, "conan", "", "C++", R_Equals),
      --  A Gradle build states a group id, not an artefact name (its
      --  artefact name lives in settings.gradle's rootProject.name), so the
      --  component takes the directory name and the build states only its
      --  version. A group id is a coordinate prefix, never a package name.
      Row
        ("build.gradle",
         False,
         "maven",
         "",
         "Java",
         R_Equals,
         "",
         "version",
         ""),
      Row
        ("build.gradle.kts",
         False,
         "maven",
         "",
         "Kotlin",
         R_Equals,
         "",
         "version",
         ""),
      --  R states its licence in R's own free-form syntax ("MIT + file
      --  LICENSE", "GPL (>= 2)"), which is not an SPDX identifier, so the
      --  field is not read as one: the LICENSE file beside DESCRIPTION is
      --  what classifies into an SPDX id.
      Row
        ("DESCRIPTION",
         False,
         "cran",
         "",
         "R",
         R_Colon,
         "Package",
         "Version",
         ""),
      Row
        (".csproj",
         True,
         "nuget",
         "",
         "C#",
         R_Xml,
         "PackageId",
         "Version",
         "PackageLicenseExpression"),
      Row
        (".gemspec",
         True,
         "gem",
         "",
         "Ruby",
         R_Equals,
         "name",
         "version",
         "license"),
      Row
        (".podspec",
         True,
         "cocoapods",
         "",
         "Swift",
         R_Equals,
         "name",
         "version",
         "license"),
      Row
        (".rockspec",
         True,
         "luarocks",
         "",
         "Lua",
         R_Equals,
         "package",
         "version",
         "license"),
      Row
        (".opam",
         True,
         "opam",
         "",
         "OCaml",
         R_Colon,
         "name",
         "version",
         "license"),
      Row
        (".cabal",
         True,
         "hackage",
         "",
         "Haskell",
         R_Colon,
         "name",
         "version",
         "license"));

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

   --  Set the registry token: the row's own token when it carries one, the
   --  PURL kind otherwise.
   procedure Set_Eco (E : String; ELen : Natural) is
   begin
      if ELen > 0 and then ELen <= Info.Eco'Last then
         Info.Eco_Len := ELen;
         Info.Eco (1 .. ELen) := E (E'First .. E'First + ELen - 1);
      else
         Info.Eco_Len := Info.PURL_Kind_Len;
         Info.Eco (1 .. Info.PURL_Kind_Len) :=
           Info.PURL_Kind (1 .. Info.PURL_Kind_Len);
      end if;
   end Set_Eco;

   function Path (N : String) return String is
   begin
      return Dir & "/" & N;
   end Path;

begin
   Info.Found := False;
   Info.PURL_Kind_Len := 0;
   Info.Eco_Len := 0;
   Info.Primary_Lang_Len := 0;
   Info.Name_Len := 0;
   Info.Version_Len := 0;
   Info.License_Len := 0;

   for I in Table'Range loop
      declare
         Match   : constant String :=
           (if Table (I).Suffix
            then
              First_File_With_Suffix
                (Dir, Table (I).File (1 .. Table (I).FLen))
            else Path (Table (I).File (1 .. Table (I).FLen)));
         Present : constant Boolean :=
           Match'Length > 0 and then (Table (I).Suffix or else Exists (Match));
      begin
         if Present then
            Set_Kind (Table (I).Kind (1 .. Table (I).KLen));
            Set_Eco (Table (I).Eco, Table (I).ELen);
            Set_Lang (Table (I).Lang (1 .. Table (I).LangLen));
            case Table (I).Reader is
               when R_Json                                   =>
                  Set_Text
                    (Info.Name,
                     Info.Name_Len,
                     Json_Top_Value
                       (Match, Key (Table (I).Name_Key, Table (I).NKLen)));
                  Set_Text
                    (Info.Version,
                     Info.Version_Len,
                     Json_Top_Value
                       (Match, Key (Table (I).Ver_Key, Table (I).VKLen)));
                  Set_Text
                    (Info.License,
                     Info.License_Len,
                     Json_Top_Value
                       (Match, Key (Table (I).Lic_Key, Table (I).LKLen)));

               when R_Xml                                    =>
                  Set_Text
                    (Info.Name,
                     Info.Name_Len,
                     Xml_Tag_Value
                       (Match, Key (Table (I).Name_Key, Table (I).NKLen)));
                  Set_Text
                    (Info.Version,
                     Info.Version_Len,
                     Xml_Tag_Value
                       (Match, Key (Table (I).Ver_Key, Table (I).VKLen)));
                  Set_Text
                    (Info.License,
                     Info.License_Len,
                     Xml_Tag_Value
                       (Match, Key (Table (I).Lic_Key, Table (I).LKLen)));

               when R_Colon | R_Equals | R_Either | R_Braced =>
                  Set_Text
                    (Info.Name,
                     Info.Name_Len,
                     Expr_Value
                       (Match,
                        Style_Of (Table (I).Reader),
                        Key (Table (I).Name_Key, Table (I).NKLen)));
                  Set_Text
                    (Info.Version,
                     Info.Version_Len,
                     Expr_Value
                       (Match,
                        Style_Of (Table (I).Reader),
                        Key (Table (I).Ver_Key, Table (I).VKLen)));
                  Set_Text
                    (Info.License,
                     Info.License_Len,
                     Expr_Value
                       (Match,
                        Style_Of (Table (I).Reader),
                        Key (Table (I).Lic_Key, Table (I).LKLen)));

               when R_Toml                                   =>
                  --  The row's own section, "" for the file's top level.
                  Set_Text
                    (Info.Name,
                     Info.Name_Len,
                     Toml_Section_Value
                       (Match,
                        Key (Table (I).Sect, Table (I).SLen),
                        Key (Table (I).Name_Key, Table (I).NKLen)));
                  Set_Text
                    (Info.Version,
                     Info.Version_Len,
                     Toml_Section_Value
                       (Match,
                        Key (Table (I).Sect, Table (I).SLen),
                        Key (Table (I).Ver_Key, Table (I).VKLen)));
                  Set_Text
                    (Info.License,
                     Info.License_Len,
                     Toml_Section_Value
                       (Match,
                        Key (Table (I).Sect, Table (I).SLen),
                        Key (Table (I).Lic_Key, Table (I).LKLen)));

               when R_Pyproj                                 =>
                  declare
                     --  PEP 621's [project] first, Poetry's [tool.poetry]
                     --  table as the fallback.
                     function PV (K : String) return String is
                        V : constant String :=
                          Toml_Section_Value (Match, "project", K);
                     begin
                        if V'Length > 0 then
                           return V;
                        end if;
                        return Toml_Section_Value (Match, "tool.poetry", K);
                     end PV;
                  begin
                     Set_Text (Info.Name, Info.Name_Len, PV ("name"));
                     Set_Text (Info.Version, Info.Version_Len, PV ("version"));
                     Set_Text (Info.License, Info.License_Len, PV ("license"));
                  end;

               when R_Go                                     =>
                  declare
                     Mod_Path : constant String := Go_Module_Path (Match);
                  begin
                     Set_Text (Info.Name, Info.Name_Len, Mod_Path);
                     --  A module's own go.mod states its path but never its
                     --  version, so the version comes from the parsed vendor
                     --  manifest. It is absent for a module outside a Go
                     --  vendor tree, and the registry resolver then supplies
                     --  it.
                     if Mod_Path'Length > 0 then
                        Set_Text
                          (Info.Version,
                           Info.Version_Len,
                           Go_Module_Version (Modules, Mod_Path));
                     end if;
                  end;

               when R_Gem                                    =>
                  declare
                     G_N : String (1 .. 64) := (others => ' ');
                     G_V : String (1 .. 64) := (others => ' ');
                     N_L : Natural := 0;
                     V_L : Natural := 0;
                  begin
                     Gem_Entry (Match, G_N, N_L, G_V, V_L);
                     Set_Text (Info.Name, Info.Name_Len, G_N (1 .. N_L));
                     Set_Text (Info.Version, Info.Version_Len, G_V (1 .. V_L));
                  end;

               when R_Maven                                  =>
                  declare
                     A : constant String :=
                       Xml_Tag_Value (Match, "artifactId");
                     G : constant String := Xml_Tag_Value (Match, "groupId");
                     V : constant String := Xml_Tag_Value (Match, "version");
                  begin
                     if G'Length > 0 then
                        Set_Text (Info.Name, Info.Name_Len, G & ":" & A);
                     else
                        Set_Text (Info.Name, Info.Name_Len, A);
                     end if;
                     Set_Text (Info.Version, Info.Version_Len, V);
                  end;

               when R_Swift                                  =>
                  null;
            end case;
            --  A licence file beside the manifest classifies into an SPDX
            --  identifier. It runs last so a licence the manifest states
            --  explicitly (for example a package.json "license" field) wins.
            if Info.License_Len = 0 then
               Set_Text (Info.License, Info.License_Len, License_Id (Dir));
            end if;
            Info.Found := True;
            return;
         end if;
      end;
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
            Set_Eco ("", 0);
            Set_Lang ("Python");
            if Info.License_Len = 0 then
               Set_Text (Info.License, Info.License_Len, License_Id (Dir));
            end if;
            Info.Found := True;
            Found := True;
         end if;
      end loop;
      End_Search (Search);
   end;
end Read_Vendor_Manifest;
