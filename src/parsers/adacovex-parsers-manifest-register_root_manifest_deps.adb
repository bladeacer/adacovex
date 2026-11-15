separate (Adacovex.Parsers.Manifest)
--  Register the dependencies the root project's own ecosystem manifest
--  declares, for the ecosystems no dedicated pass covers: npm has
--  Register_Root_Npm_Deps, Go has Register_Root_Go_Deps, and Python has
--  Register_Root_Python_Deps. This pass is table-driven: one row per
--  ecosystem names the manifest (a fixed filename or a package-named
--  suffix), the read dialect, the base and dev section, the PURL type, and
--  the primary language. Adding an ecosystem is a one-row edit.
--  Every read is structural, never a substring match:
--    * JSON -- a key must belong to the top-level section object
--      (Collect_Json_Section_Names).
--    * TOML -- a key must sit inside the section header, and a
--      "[section.name]" sub-table header names the dependency "name"
--      (Cargo's dependency table form).
--    * YAML -- a key must sit inside the section block at the block's own
--      indentation, so a nested map (pubspec's "sdk: flutter") never
--      registers a component.
--    * LIST -- a "Section: a (>= 1.0), b" line, as R's DESCRIPTION and a
--      cabal stanza write it; each entry stops at its version constraint,
--      and an indented continuation line extends the list.
--  A base-scope declaration becomes Scope_Base and a dev-scope one
--  Scope_Dev. A name already in the graph (a vendored tree resolved it) is
--  left alone, so an installed tree stays authoritative. The registry
--  resolver fills a version, licence, and website gap where the ecosystem
--  has a registry CLI; an ecosystem without one keeps the name-only entry,
--  and nothing is ever guessed.
--  @param Target_Dir  Project root.
--  @param Graph  Component graph to register into.
procedure Register_Root_Manifest_Deps
  (Target_Dir : String;
   Graph      : in out Types.Implementation.Component_Vectors.Vector)
is
   use Ada.Directories;
   use Ada.Text_IO;

   T : constant String :=
     (if Target_Dir'Length > 1 and then Target_Dir (Target_Dir'Last) = '/'
      then Target_Dir (Target_Dir'First .. Target_Dir'Last - 1)
      else Target_Dir);

   type Dialect is (D_Json, D_Toml, D_Yaml, D_List);

   type Dep_Row is record
      File    : String (1 .. 20);
      FLen    : Natural;
      Suffix  : Boolean;
      Read    : Dialect;
      Base    : String (1 .. 20);
      BLen    : Natural;
      Dev     : String (1 .. 20);
      DLen    : Natural;
      Kind    : String (1 .. 10);
      KLen    : Natural;
      Lang    : String (1 .. 16);
      LangLen : Natural;
   end record;

   function Row
     (File   : String;
      Suffix : Boolean;
      Read   : Dialect;
      Base   : String;
      Dev    : String;
      Kind   : String;
      Lang   : String) return Dep_Row
   is
      R : Dep_Row :=
        (File    => (others => ' '),
         FLen    => 0,
         Suffix  => Suffix,
         Read    => Read,
         Base    => (others => ' '),
         BLen    => 0,
         Dev     => (others => ' '),
         DLen    => 0,
         Kind    => (others => ' '),
         KLen    => 0,
         Lang    => (others => ' '),
         LangLen => 0);

      procedure Put (Dst : in out String; DLen : in out Natural; S : String) is
      begin
         if S'Length <= Dst'Length then
            DLen := S'Length;
            Dst (1 .. S'Length) := S;
         end if;
      end Put;
   begin
      Put (R.File, R.FLen, File);
      Put (R.Base, R.BLen, Base);
      Put (R.Dev, R.DLen, Dev);
      Put (R.Kind, R.KLen, Kind);
      Put (R.Lang, R.LangLen, Lang);
      return R;
   end Row;

   Table : constant array (1 .. 5) of Dep_Row :=
     (Row
        ("composer.json",
         False,
         D_Json,
         "require",
         "require-dev",
         "composer",
         "PHP"),
      Row
        ("Cargo.toml",
         False,
         D_Toml,
         "dependencies",
         "dev-dependencies",
         "cargo",
         "Rust"),
      Row
        ("pubspec.yaml",
         False,
         D_Yaml,
         "dependencies",
         "dev_dependencies",
         "pub",
         "Dart"),
      Row ("DESCRIPTION", False, D_List, "Imports", "Suggests", "cran", "R"),
      Row (".cabal", True, D_List, "build-depends", "", "hackage", "Haskell"));

   function Is_Blank (C : Character) return Boolean is
   begin
      return C = ' ' or else C = ASCII.HT;
   end Is_Blank;

   --  Append one dependency name to Names, capped at the Desc_Field bound
   --  the graph stores.
   procedure Add_Name (Names : in out Name_Vectors.Vector; N : String) is
      Item : Name_Item;
   begin
      if N'Length = 0 then
         return;
      end if;
      Item.Len := N'Length;
      if Item.Len > Types.Max_Desc_Str then
         Item.Len := Types.Max_Desc_Str;
      end if;
      for I in 1 .. Item.Len loop
         Item.Name (I) := N (N'First + I - 1);
      end loop;
      Names.Append (Item);
   end Add_Name;

   --  Collect the keys a TOML section declares. A key must sit inside the
   --  "[Section]" header, so another table's key never registers. A
   --  "[Section.Name]" sub-table header names the dependency Name (Cargo's
   --  per-dependency table form), and its own keys are that dependency's
   --  metadata, not further dependencies.
   --  @param Path  Manifest path.
   --  @param Section  Section header text without brackets.
   --  @param Names  Collected names (appended).
   procedure Collect_Toml_Keys
     (Path : String; Section : String; Names : in out Name_Vectors.Vector)
   is
      F        : File_Type;
      Line     : String (1 .. Types.Max_Line);
      Last     : Natural;
      Overflow : Boolean;
      Line_Num : Natural := 0;
      In_Sec   : Boolean := False;
   begin
      if Section'Length = 0 then
         return;
      end if;
      begin
         Open (F, In_File, Path);
      exception
         when others =>
            return;
      end;
      while not End_Of_File (F) loop
         Line_Num := Line_Num + 1;
         Adacovex.Parsers.Read_Line (F, Path, Line_Num, Line, Last, Overflow);
         if Overflow then
            Close (F);
            return;
         end if;
         declare
            S : constant String := Trim (Line (Line'First .. Last));
         begin
            if S'Length = 0 or else S (S'First) = '#' then
               null;
            elsif S (S'First) = '[' then
               --  A header ends the previous section. "[Section.Name]" names
               --  a dependency in the section; anything else closes it.
               In_Sec := False;
               if S'Length > Section'Length + 2
                 and then S (S'First + 1 .. S'First + Section'Length) = Section
                 and then S (S'First + Section'Length + 1) = '.'
               then
                  declare
                     B : Natural := S'First + Section'Length + 2;
                     E : Natural := B;
                  begin
                     while E <= S'Last
                       and then S (E) /= ']'
                       and then not Is_Blank (S (E))
                     loop
                        E := E + 1;
                     end loop;
                     if E > B then
                        Add_Name (Names, S (B .. E - 1));
                     end if;
                  end;
               elsif S'Length > Section'Length + 1
                 and then S (S'First + 1 .. S'First + Section'Length) = Section
                 and then S (S'First + Section'Length + 1) = ']'
               then
                  In_Sec := True;
               end if;
            elsif In_Sec then
               --  "key = value": the key is the dependency name.
               declare
                  E : Natural := S'First;
               begin
                  while E <= S'Last
                    and then S (E) /= '='
                    and then not Is_Blank (S (E))
                  loop
                     E := E + 1;
                  end loop;
                  if E > S'First then
                     Add_Name (Names, S (S'First .. E - 1));
                  end if;
               end;
            end if;
         end;
      end loop;
      Close (F);
   exception
      when others =>
         if Is_Open (F) then
            Close (F);
         end if;
   end Collect_Toml_Keys;

   --  Collect the keys a YAML section declares. The section header sits at
   --  column 0 ("dependencies:"), its keys at the first indentation the
   --  block uses, and a deeper indentation belongs to that key's own map
   --  (pubspec's "sdk: flutter"), so it never registers a component. The
   --  block ends at the next column-0 line.
   --  @param Path  Manifest path.
   --  @param Section  Section key text without the colon.
   --  @param Names  Collected names (appended).
   procedure Collect_Yaml_Keys
     (Path : String; Section : String; Names : in out Name_Vectors.Vector)
   is
      F          : File_Type;
      Line       : String (1 .. Types.Max_Line);
      Last       : Natural;
      Overflow   : Boolean;
      Line_Num   : Natural := 0;
      In_Sec     : Boolean := False;
      Key_Indent : Natural := 0;
   begin
      if Section'Length = 0 then
         return;
      end if;
      begin
         Open (F, In_File, Path);
      exception
         when others =>
            return;
      end;
      while not End_Of_File (F) loop
         Line_Num := Line_Num + 1;
         Adacovex.Parsers.Read_Line (F, Path, Line_Num, Line, Last, Overflow);
         if Overflow then
            Close (F);
            return;
         end if;
         declare
            Indent : Natural := 0;
            S      : constant String := Trim (Line (Line'First .. Last));
         begin
            while Line'First + Indent <= Last
              and then Is_Blank (Line (Line'First + Indent))
            loop
               Indent := Indent + 1;
            end loop;
            if S'Length = 0 or else S (S'First) = '#' then
               null;
            elsif Indent = 0 then
               In_Sec :=
                 S'Length = Section'Length + 1
                 and then S (S'First .. S'Last - 1) = Section
                 and then S (S'Last) = ':';
               Key_Indent := 0;
            elsif In_Sec then
               if Key_Indent = 0 then
                  Key_Indent := Indent;
               end if;
               if Indent = Key_Indent then
                  declare
                     E : Natural := S'First;
                  begin
                     while E <= S'Last
                       and then S (E) /= ':'
                       and then not Is_Blank (S (E))
                     loop
                        E := E + 1;
                     end loop;
                     if E > S'First then
                        Add_Name (Names, S (S'First .. E - 1));
                     end if;
                  end;
               end if;
            end if;
         end;
      end loop;
      Close (F);
   exception
      when others =>
         if Is_Open (F) then
            Close (F);
         end if;
   end Collect_Yaml_Keys;

   --  Append every entry of one comma-separated dependency list. An entry
   --  ends at its first blank or at the bracket that opens a version
   --  constraint, so "text (>= 1.2)" and "base >= 4.7" both yield just the
   --  package name. An empty entry (a trailing comma) is skipped.
   procedure Add_List (Names : in out Name_Vectors.Vector; S : String) is
      A : Natural := S'First;
   begin
      for I in S'First .. S'Last + 1 loop
         if I > S'Last or else S (I) = ',' then
            declare
               B : Natural := A;
            begin
               --  Skip the blanks a comma leaves before the next entry.
               while B < I and then Is_Blank (S (B)) loop
                  B := B + 1;
               end loop;
               A := B;
               while B < I
                 and then not Is_Blank (S (B))
                 and then S (B) /= '('
                 and then S (B) /= '['
               loop
                  B := B + 1;
               end loop;
               if B > A then
                  Add_Name (Names, S (A .. B - 1));
               end if;
            end;
            A := I + 1;
         end if;
      end loop;
   end Add_List;

   --  Collect the names a "Section: a, b" line declares. The field may sit
   --  at any indentation, because a cabal stanza indents its
   --  "build-depends:" inside the component. The line may wrap: an
   --  indented line that is neither blank nor a new "Key:" field extends
   --  the list, as R's DESCRIPTION and a cabal stanza write it, and a line
   --  that starts a new field or leaves the indented block ends it.
   --  @param Path  Manifest path.
   --  @param Section  Field name before the colon.
   --  @param Names  Collected names (appended).
   procedure Collect_List_Names
     (Path : String; Section : String; Names : in out Name_Vectors.Vector)
   is
      F        : File_Type;
      Line     : String (1 .. Types.Max_Line);
      Last     : Natural;
      Overflow : Boolean;
      Line_Num : Natural := 0;
      In_List  : Boolean := False;
   begin
      if Section'Length = 0 then
         return;
      end if;
      begin
         Open (F, In_File, Path);
      exception
         when others =>
            return;
      end;
      while not End_Of_File (F) loop
         Line_Num := Line_Num + 1;
         Adacovex.Parsers.Read_Line (F, Path, Line_Num, Line, Last, Overflow);
         if Overflow then
            Close (F);
            return;
         end if;
         declare
            Indented : constant Boolean :=
              Line'First <= Last and then Is_Blank (Line (Line'First));
            S        : constant String := Trim (Line (Line'First .. Last));
         begin
            if S'Length = 0 then
               In_List := False;
            elsif S'Length >= Section'Length + 1
              and then S (S'First .. S'First + Section'Length - 1) = Section
              and then S (S'First + Section'Length) = ':'
            then
               In_List := True;
               Add_List (Names, S (S'First + Section'Length + 1 .. S'Last));
            elsif In_List and then Indented then
               --  A continuation line, unless it starts a new field.
               declare
                  Is_Field : Boolean := False;
               begin
                  for I in S'First .. S'Last loop
                     if S (I) = ':' then
                        Is_Field := True;
                        exit;
                     end if;
                  end loop;
                  if Is_Field then
                     In_List := False;
                  else
                     Add_List (Names, S);
                  end if;
               end;
            else
               In_List := False;
            end if;
         end;
      end loop;
      Close (F);
   end Collect_List_Names;

   --  Collect the names one row's section declares through its dialect.
   --  @param Path  Manifest path.
   --  @param Read  Row dialect.
   --  @param Section  Section to read.
   --  @param Names  Collected names (appended).
   procedure Collect
     (Path    : String;
      Read    : Dialect;
      Section : String;
      Names   : in out Name_Vectors.Vector) is
   begin
      case Read is
         when D_Json =>
            Collect_Json_Section_Names (Path, Section, Names);

         when D_Toml =>
            Collect_Toml_Keys (Path, Section, Names);

         when D_Yaml =>
            Collect_Yaml_Keys (Path, Section, Names);

         when D_List =>
            Collect_List_Names (Path, Section, Names);
      end case;
   end Collect;

   --  Append every collected name to the graph at version "" (the manifest
   --  states a constraint, not a resolved version) and let the registry
   --  resolver fill the version, licence, and website where the ecosystem
   --  has a CLI. A name already in the graph keeps its entry.
   procedure Register
     (Names : Name_Vectors.Vector;
      Kind  : String;
      Eco   : String;
      Lang  : String;
      Sc    : Types.Component_Scope) is
   begin
      for I in 1 .. Integer (Names.Length) loop
         declare
            N     : constant String := Names (I).Name (1 .. Names (I).Len);
            Lic   : Types.Desc_Field;
            L_Len : Natural := 0;
            Vbuf  : Types.Desc_Field;
            V_Len : Natural := 0;
            Web   : Types.Path_Field;
            W_Len : Natural := 0;
            --  composer.json declares platform packages ("php", "ext-json",
            --  "composer-runtime-api") beside real dependencies. They name
            --  the runtime, not a distribution, so they never become
            --  components.
            Skip  : constant Boolean :=
              N = "php"
              or else N = "hhvm"
              or else N = "composer-runtime-api"
              or else N = "composer-plugin-api"
              or else (N'Length > 4
                       and then N (N'First .. N'First + 3) = "ext-");
         begin
            if N'Length > 0
              and then not Skip
              and then not Name_In_Graph (Graph, N)
            then
               Resolve_Ecosystem_Metadata
                 (T,
                  Eco,
                  N,
                  False,
                  False,
                  Lic,
                  L_Len,
                  Vbuf,
                  V_Len,
                  Web,
                  W_Len);
               declare
                  Ver : constant String :=
                    (if V_Len > 0 then Vbuf (1 .. V_Len) else "");
               begin
                  Append_Dependency
                    (Graph,
                     N,
                     Ver,
                     (if L_Len > 0 then Lic (1 .. L_Len) else ""),
                     "declared by the project (" & Kind & " manifest)",
                     "pkg:"
                     & Kind
                     & "/"
                     & N
                     & (if Ver'Length > 0 then "@" & Ver else ""),
                     1,
                     False,
                     Sc,
                     Lang,
                     (if W_Len > 0 then Web (1 .. W_Len) else ""));
               end;
            end if;
         end;
      end loop;
   end Register;
begin
   for I in Table'Range loop
      declare
         File : constant String := Table (I).File (1 .. Table (I).FLen);
         Path : constant String :=
           (if Table (I).Suffix
            then First_File_With_Suffix (T, File)
            else T & "/" & File);
         Kind : constant String := Table (I).Kind (1 .. Table (I).KLen);
         Lang : constant String := Table (I).Lang (1 .. Table (I).LangLen);
      begin
         if Path'Length > 0 then
            if Table (I).BLen > 0 then
               declare
                  Names : Name_Vectors.Vector;
               begin
                  Collect
                    (Path,
                     Table (I).Read,
                     Table (I).Base (1 .. Table (I).BLen),
                     Names);
                  Register (Names, Kind, Kind, Lang, Types.Scope_Base);
               end;
            end if;
            if Table (I).DLen > 0 then
               declare
                  Names : Name_Vectors.Vector;
               begin
                  Collect
                    (Path,
                     Table (I).Read,
                     Table (I).Dev (1 .. Table (I).DLen),
                     Names);
                  Register (Names, Kind, Kind, Lang, Types.Scope_Dev);
               end;
            end if;
         end if;
      end;
   end loop;
end Register_Root_Manifest_Deps;
