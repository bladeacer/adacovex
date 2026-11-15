separate (Adacovex.Parsers.Manifest)
--  Resolve the transitive dependency set from the project's lockfiles and
--  register it in the graph. A manifest states the dependencies the project
--  declares; a lockfile states the set the project actually resolves, which
--  is larger, because every declared package pulls its own dependencies.
--  The SBOM reports both: a declared package keeps its base, dev, or test
--  scope, and every package only the lockfile names is a transitive
--  component of the root.
--  The lockfile set is a static table. A row names the lockfile, its
--  dialect, the keys that state the package name and version, the PURL type,
--  and the language, and one reader per dialect walks the file, so a new
--  lockfile is a one-row edit. The dialects cover a TOML package list
--  (Cargo.lock, poetry.lock), an indented gem list (Gemfile.lock), a JSON
--  object map (composer.lock, package-lock.json, packages.lock.json,
--  Package.resolved), a YAML package map (pubspec.lock), and the Elixir term
--  map (mix.lock).
--  A package the graph already holds keeps its entry and takes the locked
--  version when the declaration could not state one. A licence is never
--  read from a lockfile: a lockfile states a version, not a licence.
--  @param Target_Dir  Project root directory.
--  @param Graph  Dependency graph to extend (root at index 1).
procedure Read_Lockfiles
  (Target_Dir : String;
   Graph      : in out Types.Implementation.Component_Vectors.Vector)
is
   use Ada.Strings;
   use Ada.Strings.Fixed;

   --  How a lockfile states its entries.
   type Lock_Style is
     (S_Toml,
      --  A [[package]] block with `name = "x"` and `version = "y"`.
      S_Gem,
      --  `name (version)` at four spaces under `specs:`.
      S_Json,
      --  A JSON object map: the entry key, or a `"name"` key, then the
      --  version key.
      S_Yaml,
      --  A two-space package key, then `version: "x"` at four spaces.
      S_Hex);
   --  An Elixir term map: `"name": {:hex, :name, "version", ...}`.

   type Lock_Row is record
      File     : String (1 .. 24);
      FLen     : Natural;
      Style    : Lock_Style;
      --  The name key. Empty means the object's own key is the name.
      Name_Key : String (1 .. 10);
      NKLen    : Natural;
      Ver_Key  : String (1 .. 10);
      VKLen    : Natural;
      Purl     : String (1 .. 16);
      PLen     : Natural;
      Lang     : String (1 .. 10);
      LLen     : Natural;
   end record;

   --  Build one table row from string literals, so the table reads as data.
   --  A field longer than its component is left empty rather than
   --  truncated: a silently cut filename could match the wrong lockfile.
   --  @param File  Lockfile base name.
   --  @param Style  Dialect that states its entries.
   --  @param Purl  PURL type prefix, with its trailing slash.
   --  @param Lang  Language of the packages the lockfile resolves.
   --  @param Name_Key  JSON key that states the name ("" for the entry key).
   --  @param Ver_Key  JSON key that states the version.
   --  @return The table row.
   function Row
     (File     : String;
      Style    : Lock_Style;
      Purl     : String;
      Lang     : String;
      Name_Key : String := "";
      Ver_Key  : String := "") return Lock_Row
   is
      R : Lock_Row :=
        (File     => (others => ' '),
         FLen     => 0,
         Style    => Style,
         Name_Key => (others => ' '),
         NKLen    => 0,
         Ver_Key  => (others => ' '),
         VKLen    => 0,
         Purl     => (others => ' '),
         PLen     => 0,
         Lang     => (others => ' '),
         LLen     => 0);

      procedure Put (Dst : in out String; DLen : in out Natural; S : String) is
      begin
         if S'Length <= Dst'Length then
            DLen := S'Length;
            Dst (1 .. S'Length) := S;
         end if;
      end Put;
   begin
      Put (R.File, R.FLen, File);
      Put (R.Purl, R.PLen, Purl);
      Put (R.Lang, R.LLen, Lang);
      Put (R.Name_Key, R.NKLen, Name_Key);
      Put (R.Ver_Key, R.VKLen, Ver_Key);
      return R;
   end Row;

   --  The lockfiles adacovex resolves. The order is irrelevant: every
   --  present file is read, and every entry is deduplicated by name.
   Table : constant array (Positive range <>) of Lock_Row :=
     (Row ("Cargo.lock", S_Toml, "pkg:cargo/", "Rust"),
      Row ("poetry.lock", S_Toml, "pkg:pypi/", "Python"),
      Row ("Gemfile.lock", S_Gem, "pkg:gem/", "Ruby"),
      Row ("composer.lock", S_Json, "pkg:composer/", "PHP", "name", "version"),
      Row
        ("package-lock.json", S_Json, "pkg:npm/", "JavaScript", "", "version"),
      Row ("packages.lock.json", S_Json, "pkg:nuget/", "C#", "", "resolved"),
      Row
        ("Package.resolved",
         S_Json,
         "pkg:swift/",
         "Swift",
         "identity",
         "version"),
      Row ("pubspec.lock", S_Yaml, "pkg:pub/", "Dart"),
      Row ("mix.lock", S_Hex, "pkg:hex/", "Elixir"));

   --  A JSON key whose value is an object, and which therefore holds
   --  entries rather than being one. Such a key never names a package.
   --  @param K  Object key from a JSON lockfile.
   --  @return True when the key is a section rather than an entry.
   function Is_Section_Key (K : String) return Boolean is
   begin
      return
        K = "dependencies"
        or else K = "devDependencies"
        or else K = "peerDependencies"
        or else K = "optionalDependencies"
        or else K = "packages"
        or else K = "packages-dev"
        or else K = "metadata"
        or else K = "dist"
        or else K = "engines"
        or else K = "scripts"
        or else K = "require"
        or else K = "require-dev"
        or else K = "autoload"
        or else K = "support"
        or else K = "funding"
        or else K = "author"
        or else K = "repository"
        or else K = "bugs"
        or else K = "config"
        or else K = "extra"
        or else K = "state"
        or else K = "pins"
        or else K = "targets"
        or else K = "frameworks"
        or else K = "importers"
        or else K = "description";
   end Is_Section_Key;

   --  A version as the lockfile states it, without the decoration a
   --  dialect adds: surrounding spaces, and the `==` that a Python
   --  lockfile prefixes to a pinned version.
   --  @param V  Version text as read from the lockfile.
   --  @return The bare version, or "" when nothing remains.
   function Clean_Version (V : String) return String is
      S : constant String := Trim (V, Both);
   begin
      if S'Length = 0 then
         return "";
      end if;
      if S'Length > 2 and then S (S'First .. S'First + 1) = "==" then
         return Trim (S (S'First + 2 .. S'Last), Both);
      end if;
      return S;
   end Clean_Version;

   --  Register one resolved entry. A package the graph already holds keeps
   --  its scope and takes the locked version when it states none.
   --  @param R  The lockfile row that resolved the entry.
   --  @param Name  Package name as the lockfile states it.
   --  @param Ver  Version as the lockfile states it.
   procedure Emit (R : Lock_Row; Name : String; Ver : String) is
      N : constant String := Trim (Name, Both);
      V : constant String := Clean_Version (Ver);
   begin
      if N'Length = 0 or else N'Length > Types.Max_Desc_Str then
         return;
      end if;
      if V'Length > Types.Max_Desc_Str then
         return;
      end if;
      if Name_In_Graph (Graph, N) then
         --  The manifest declared the package, so its base, dev, or test
         --  scope stands. A declaration that states only a constraint (for
         --  example ">= 1.0") has no version yet, and the lockfile answers
         --  it.
         for I in 1 .. Integer (Graph.Length) loop
            if Graph (I).Name_Len = N'Length
              and then Graph (I).Name (1 .. N'Length) = N
            then
               if Graph (I).Version_Len = 0 and then V'Length > 0 then
                  declare
                     C : Types.Implementation.Component_Info := Graph (I);
                  begin
                     Set_Field (C.Version, C.Version_Len, V);
                     --  The declaration stated no version, so its PURL and
                     --  bom-ref carry none either; the locked version
                     --  completes both.
                     if C.PURL_Len > 0
                       and then Index (C.PURL (1 .. C.PURL_Len), "@") = 0
                       and then C.PURL_Len + 1 + V'Length <= Types.Max_Path
                     then
                        C.PURL (C.PURL_Len + 1) := '@';
                        C.PURL (C.PURL_Len + 2 .. C.PURL_Len + 1 + V'Length) :=
                          V;
                        C.PURL_Len := C.PURL_Len + 1 + V'Length;
                        Set_Path (C.Ref, C.Ref_Len, C.PURL (1 .. C.PURL_Len));
                     end if;
                     Graph (I) := C;
                  end;
               end if;
               exit;
            end if;
         end loop;
         return;
      end if;
      Append_Dependency
        (Graph,
         N,
         V,
         "",
         "Transitive dependency resolved by " & R.File (1 .. R.FLen),
         R.Purl (1 .. R.PLen) & N & (if V'Length > 0 then "@" & V else ""),
         1,
         False,
         Types.Scope_Transitive,
         R.Lang (1 .. R.LLen));
   end Emit;

   --  Value of a `"Key": "value"` pair that opens a line. A pair nested
   --  inside a deeper object is not the entry's own, so only a key that
   --  follows the indentation counts.
   --  @param L  One physical line.
   --  @param Key  The JSON key to read.
   --  @return The quoted value, or "" when the line states no such pair.
   function Json_Value (L : String; Key : String) return String is
      P : constant Natural := Index (L, """" & Key & """");
   begin
      if P = 0 then
         return "";
      end if;
      for I in L'First .. P - 1 loop
         if L (I) /= ' ' and then L (I) /= Character'Val (9) then
            return "";
         end if;
      end loop;
      declare
         I : Natural := P + Key'Length + 2;
      begin
         while I <= L'Last and then L (I) /= ':' loop
            I := I + 1;
         end loop;
         if I >= L'Last then
            return "";
         end if;
         I := I + 1;
         while I <= L'Last
           and then (L (I) = ' ' or else L (I) = Character'Val (9))
         loop
            I := I + 1;
         end loop;
         if I > L'Last or else L (I) /= '"' then
            return "";
         end if;
         declare
            F : constant Natural := I + 1;
            K : Natural := F;
         begin
            while K <= L'Last and then L (K) /= '"' loop
               K := K + 1;
            end loop;
            if K <= L'Last and then K > F then
               return L (F .. K - 1);
            end if;
            return "";
         end;
      end;
   end Json_Value;

   --  The key of a line whose value opens an object (`"key": {`), or "" for
   --  any other line. The `{` must be the last non-space character, so a
   --  nested pair is never taken for an entry key.
   --  @param L  One physical line.
   --  @return The key text, or "" when the line opens no object.
   function Json_Object_Key (L : String) return String is
      V : constant String := Trim (L, Both);
   begin
      if V'Length < 4 or else V (V'First) /= '"' or else V (V'Last) /= '{' then
         return "";
      end if;
      declare
         Q : Natural := 0;
      begin
         for I in V'First + 1 .. V'Last loop
            if V (I) = '"' then
               Q := I;
               exit;
            end if;
         end loop;
         if Q = 0 or else Q = V'First + 1 then
            return "";
         end if;
         return V (V'First + 1 .. Q - 1);
      end;
   end Json_Object_Key;

   --  First quoted token at or after a position in a line.
   --  @param S  The line.
   --  @param Start  Position to search from.
   --  @return The token between the first pair of quotes, or "" when the
   --    line holds no complete quoted token at or after Start.
   function Quoted_At (S : String; Start : Natural) return String is
      F : Natural := Start;
   begin
      if Start < S'First or else Start > S'Last then
         return "";
      end if;
      while F <= S'Last and then S (F) /= '"' loop
         F := F + 1;
      end loop;
      if F >= S'Last then
         return "";
      end if;
      declare
         K : Natural := F + 1;
      begin
         while K <= S'Last and then S (K) /= '"' loop
            K := K + 1;
         end loop;
         if K > S'Last or else K = F + 1 then
            return "";
         end if;
         return S (F + 1 .. K - 1);
      end;
   end Quoted_At;

   --  How many leading spaces a line carries.
   --  @param L  One physical line.
   --  @return The number of leading spaces.
   function Indent_Of (L : String) return Natural is
      N : Natural := 0;
   begin
      for I in L'Range loop
         exit when L (I) /= ' ';
         N := N + 1;
      end loop;
      return N;
   end Indent_Of;

   --  A package-lock key names a location, not a package: an entry under
   --  `node_modules/` is that package, and a nested
   --  `node_modules/a/node_modules/b` is package b.
   --  @param K  Object key from the lockfile.
   --  @return The package name, or "" when the key names no location entry.
   function Entry_Name (K : String) return String is
      Mark  : constant String := "node_modules/";
      Start : Natural := K'First;
   begin
      for I in K'Range loop
         if I + Mark'Length - 1 <= K'Last
           and then K (I .. I + Mark'Length - 1) = Mark
         then
            Start := I + Mark'Length;
         end if;
      end loop;
      if Start > K'Last then
         return "";
      end if;
      return K (Start .. K'Last);
   end Entry_Name;

   --  Whether a name is a usable package name. A JSON key that carries a
   --  path separator's decoration, a colon, or a quote is not one.
   --  @param N  Candidate name.
   --  @return True when the name can be registered.
   function Usable_Name (N : String) return Boolean is
   begin
      if N'Length = 0 or else N'Length > Types.Max_Desc_Str then
         return False;
      end if;
      for I in N'Range loop
         if N (I) = ':'
           or else N (I) = '{'
           or else N (I) = '"'
           or else N (I) = ' '
         then
            return False;
         end if;
      end loop;
      return True;
   end Usable_Name;

   --  Read one lockfile and emit every entry it resolves.
   --  @param R  The table row being read.
   --  @param Path  Lockfile path.
   procedure Read (R : Lock_Row; Path : String) is
      use Ada.Text_IO;
      F        : File_Type;
      Line     : String (1 .. Types.Max_Line);
      Last     : Natural;
      Overflow : Boolean;
      Line_Num : Natural := 0;
      --  The entry name the current line belongs to.
      Cur      : Types.Desc_Field;
      Cur_Len  : Natural := 0;
      --  Whether the gem reader is inside the resolved `specs:` section.
      In_Specs : Boolean := False;

      --  Set the current entry name.
      --  @param N  Candidate name.
      procedure Set_Cur (N : String) is
      begin
         if N'Length > 0 and then N'Length <= Types.Max_Desc_Str then
            Cur (1 .. N'Length) := N;
            Cur_Len := N'Length;
         else
            Cur_Len := 0;
         end if;
      end Set_Cur;

      --  Emit the current entry and forget it, so a later version key
      --  never reuses a stale name.
      --  @param V  Version for the current entry.
      procedure Emit_Cur (V : String) is
      begin
         if Cur_Len > 0 then
            Emit (R, Cur (1 .. Cur_Len), V);
            Cur_Len := 0;
         end if;
      end Emit_Cur;

      --  The trimmed line, without leading indentation.
      function T (L : String) return String is
      begin
         if Indent_Of (L) >= L'Length then
            return "";
         end if;
         return Trim (L, Both);
      end T;
   begin
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
            --  A line longer than Max_Line stops the read of this file, so
            --  a truncated lockfile never yields a partial resolution.
            Close (F);
            return;
         end if;
         declare
            L : constant String := Line (1 .. Last);
            S : constant String := T (L);
         begin
            case R.Style is
               when S_Toml =>
                  --  A [[package]] block opens a new entry, and its name and
                  --  version keys follow.
                  if Index (S, "[[package]]") = S'First then
                     Cur_Len := 0;
                  elsif Index (S, "name") = S'First then
                     Set_Cur (Quoted_At (S, S'First));
                  elsif Index (S, "version") = S'First then
                     if Cur_Len > 0 then
                        Emit_Cur (Quoted_At (S, S'First));
                     end if;
                  end if;

               when S_Gem  =>
                  --  Only the `specs:` section states resolved versions; a
                  --  section header returns to the top of the file's list.
                  if S = "specs:" then
                     In_Specs := True;
                  elsif Indent_Of (L) = 0 and then S'Length > 0 then
                     In_Specs := False;
                  elsif In_Specs and then Indent_Of (L) = 4 then
                     declare
                        Open_Paren : constant Natural := Index (S, " (");
                     begin
                        if Open_Paren > S'First and then S (S'Last) = ')' then
                           Set_Cur (S (S'First .. Open_Paren - 1));
                           Emit_Cur (S (Open_Paren + 2 .. S'Last - 1));
                        end if;
                     end;
                  end if;

               when S_Json =>
                  --  The entry key, or the name key, states the name; the
                  --  version key states the version for that entry.
                  if R.NKLen = 0 then
                     declare
                        K : constant String :=
                          Entry_Name (Json_Object_Key (L));
                     begin
                        if K'Length > 0 then
                           if Is_Section_Key (K) or else not Usable_Name (K)
                           then
                              Cur_Len := 0;
                           else
                              Set_Cur (K);
                           end if;
                        end if;
                     end;
                  else
                     declare
                        N : constant String :=
                          Json_Value (L, R.Name_Key (1 .. R.NKLen));
                     begin
                        if N'Length > 0 then
                           Set_Cur (N);
                        end if;
                     end;
                  end if;
                  declare
                     V : constant String :=
                       Json_Value (L, R.Ver_Key (1 .. R.VKLen));
                  begin
                     if V'Length > 0 then
                        Emit_Cur (V);
                     end if;
                  end;

               when S_Yaml =>
                  --  A package key sits at two spaces and ends with the
                  --  colon; its version key sits at four spaces. A section
                  --  key carries a value, so it never ends with the colon.
                  if Indent_Of (L) = 2
                    and then S'Length > 1
                    and then S (S'Last) = ':'
                  then
                     Set_Cur (S (S'First .. S'Last - 1));
                  elsif Indent_Of (L) = 4
                    and then Index (S, "version:") = S'First
                  then
                     Emit_Cur (Quoted_At (S, S'First));
                  end if;

               when S_Hex  =>
                  --  A hex entry is `"name": {:hex, :name, "version", ...}`.
                  --  A git or path entry carries no hex tuple, so it states
                  --  no resolved version and is skipped.
                  declare
                     Hex_At : constant Natural := Index (S, ":hex,");
                  begin
                     if Hex_At > 0 then
                        Set_Cur (Quoted_At (S, S'First));
                        Emit_Cur (Quoted_At (S, Hex_At + 6));
                     end if;
                  end;
            end case;
         end;
      end loop;
      Close (F);
   exception
      when others =>
         if Is_Open (F) then
            Close (F);
         end if;
   end Read;

   T_Dir : constant String :=
     (if Target_Dir'Length > 1 and then Target_Dir (Target_Dir'Last) = '/'
      then Target_Dir (Target_Dir'First .. Target_Dir'Last - 1)
      else Target_Dir);
begin
   for R of Table loop
      declare
         Path : constant String := T_Dir & "/" & R.File (1 .. R.FLen);
      begin
         if Ada.Directories.Exists (Path) then
            Read (R, Path);
         end if;
      end;
   end loop;
end Read_Lockfiles;
