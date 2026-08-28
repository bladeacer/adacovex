separate (Adacovex.Parsers.Manifest)
--  Collect the dependency names a project manifest declares as test-only.
--  Every supported ecosystem labels its test dependencies in its own way,
--  and every label carries the literal word "test":
--    * package.json: a dependency section whose key contains "test" (for
--      example "testDependencies" or "devTestDependencies");
--    * Cargo.toml: the [dev-dependencies] section (Cargo's test-only
--      section), or any section whose name contains "test" (for example a
--      [target.'cfg(test)'.dependencies] section);
--    * composer.json: the require-dev section, or any key containing
--      "test";
--    * Gemfile: gems declared inside a `group :test` block (any group
--      name containing "test");
--    * pom.xml: <dependency> blocks whose <scope> is test;
--    * pyproject.toml: optional-dependencies extras whose name contains
--      "test" (for example the "test" extra), and Poetry group sections
--      such as [tool.poetry.group.test.dependencies].
--  The first manifest found in Owner_Dir is used, in the same priority
--  order as Read_Vendor_Manifest.  Missing or unreadable files leave the
--  set unchanged.  A physical line longer than Max_Line stops the read;
--  no partial set is kept.
--  @param Owner_Dir  Directory holding the project manifest that owns a
--    vendored directory (for example tests/e2e owns
--    tests/e2e/node_modules).
--  @param Test_Names  Collected test-labelled dependency names.
procedure Collect_Owner_Test_Names
  (Owner_Dir : String; Test_Names : in out Name_Vectors.Vector)
is
   use Ada.Text_IO;

   --  Whether S contains Sub anywhere, case-insensitively (ASCII only).
   function Contains_CI (S : String; Sub : String) return Boolean is

      --  The ASCII lowercase of C (uppercase letters shifted down).
      --  @param C  Character to fold.
      --  @return Lowercase form of C.
      function Lower (C : Character) return Character is
      begin
         if C in 'A' .. 'Z' then
            return Character'Val (Character'Pos (C) + 32);
         end if;
         return C;
      end Lower;
   begin
      if Sub'Length = 0 or S'Length < Sub'Length then
         return False;
      end if;
      for I in S'First .. S'Last - Sub'Length + 1 loop
         declare
            Match : Boolean := True;
         begin
            for J in Sub'Range loop
               if Lower (S (I + J - Sub'First)) /= Lower (Sub (J)) then
                  Match := False;
                  exit;
               end if;
            end loop;
            if Match then
               return True;
            end if;
         end;
      end loop;
      return False;
   end Contains_CI;

   --  The first double-quoted string on a line, "" when absent.
   function First_Quoted (Line : String) return String is
      Q1 : Natural := 0;
      Q2 : Natural := 0;
   begin
      for I in Line'Range loop
         if Line (I) = '"' then
            if Q1 = 0 then
               Q1 := I;
            else
               Q2 := I;
               exit;
            end if;
         end if;
      end loop;
      if Q1 > 0 and Q2 > Q1 then
         return Line (Q1 + 1 .. Q2 - 1);
      end if;
      return "";
   end First_Quoted;

   --  The "key" of a JSON object line ("key": ...): the first quoted
   --  string when the closing quote is followed by ':'.
   function Json_Key (Line : String) return String is
      K : constant String := First_Quoted (Line);
      J : Natural;
   begin
      if K'Length = 0 then
         return "";
      end if;
      --  Locate the closing quote: it is the first '"' after the key.
      J := Line'First;
      while J <= Line'Last and then Line (J) /= '"' loop
         J := J + 1;
      end loop;
      J := J + 1;
      while J <= Line'Last and then Line (J) /= '"' loop
         J := J + 1;
      end loop;
      J := J + 1;
      while J <= Line'Last and then Line (J) = ' ' loop
         J := J + 1;
      end loop;
      if J <= Line'Last and then Line (J) = ':' then
         return K;
      end if;
      return "";
   end Json_Key;

   --  Add every double-quoted string on a line to Names.
   procedure Collect_Quoted_Names
     (Line : String; Names : in out Name_Vectors.Vector)
   is
      I : Natural := Line'First;
   begin
      while I <= Line'Last loop
         if Line (I) = '"' then
            declare
               J : Natural := I + 1;
            begin
               while J <= Line'Last and then Line (J) /= '"' loop
                  J := J + 1;
               end loop;
               if J <= Line'Last then
                  Add_Dep_Name (Names, Line (I + 1 .. J - 1));
                  I := J + 1;
               else
                  I := Line'Last + 1;
               end if;
            end;
         else
            I := I + 1;
         end if;
      end loop;
   end Collect_Quoted_Names;

   --  First <Tag>...</Tag> occurrence on a single line (pom.xml).
   function Line_Tag_Value (Line : String; Tag : String) return String is
      O  : constant String := "<" & Tag & ">";
      C  : constant String := "</" & Tag & ">";
      OI : constant Natural := Ada.Strings.Fixed.Index (Line, O);
      CI : constant Natural := Ada.Strings.Fixed.Index (Line, C);
   begin
      if OI > Line'First - 1 and then CI >= OI + O'Length then
         return Line (OI + O'Length .. CI - 1);
      end if;
      return "";
   end Line_Tag_Value;

   --  package.json: a dependency section whose key contains "test" (for
   --  example "testDependencies" or "devTestDependencies").  The names
   --  under such a section are test-labelled.
   procedure Collect_Npm_Test
     (Path : String; Names : in out Name_Vectors.Vector)
   is
      F        : File_Type;
      Line     : String (1 .. Types.Max_Line);
      Last     : Natural;
      Overflow : Boolean;
      Line_Num : Natural := 0;
      In_Test  : Boolean := False;
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
            Close (F);
            return;
         end if;
         declare
            T : constant String := Trim (Line (1 .. Last));
            K : constant String := Json_Key (T);
         begin
            if K'Length > 0
              and then Contains_CI (K, "dependencies")
              and then Ada.Strings.Fixed.Index (T, "{") > 0
            then
               In_Test := Contains_CI (K, "test");
            elsif In_Test then
               if T = "}" then
                  In_Test := False;
               else
                  declare
                     Dep : constant String := First_Quoted (T);
                  begin
                     if Dep'Length > 0 then
                        Add_Dep_Name (Names, Dep);
                     end if;
                  end;
               end if;
            end if;
         end;
      end loop;
      Close (F);
   end Collect_Npm_Test;

   --  Cargo.toml: the [dev-dependencies] section is Cargo's test-only
   --  section.  Any section whose name contains "test" (for example a
   --  [target.'cfg(test)'.dependencies] section) is test-labelled too.
   procedure Collect_Cargo_Test
     (Path : String; Names : in out Name_Vectors.Vector)
   is
      F        : File_Type;
      Line     : String (1 .. Types.Max_Line);
      Last     : Natural;
      Overflow : Boolean;
      Line_Num : Natural := 0;
      In_Test  : Boolean := False;
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
            Close (F);
            return;
         end if;
         declare
            T : constant String := Trim (Line (1 .. Last));
         begin
            if T'Length > 2
              and then T (T'First) = '['
              and then T (T'Last) = ']'
            then
               declare
                  Sec : constant String :=
                    Trim (T (T'First + 1 .. T'Last - 1));
               begin
                  In_Test :=
                    Contains_CI (Sec, "test")
                    or else Contains_CI (Sec, "dev-dependencies");
               end;
            elsif In_Test then
               declare
                  Eq : Natural := 0;
               begin
                  for I in T'Range loop
                     if T (I) = '=' then
                        Eq := I;
                        exit;
                     end if;
                  end loop;
                  if Eq > T'First then
                     declare
                        Nm : constant String := Trim (T (T'First .. Eq - 1));
                     begin
                        if Nm'Length > 0 and then Nm (Nm'First) /= '#' then
                           Add_Dep_Name (Names, Nm);
                        end if;
                     end;
                  end if;
               end;
            end if;
         end;
      end loop;
      Close (F);
   end Collect_Cargo_Test;

   --  composer.json: the require-dev section is the native test-only
   --  section.  Any key containing "test" is test-labelled too.
   procedure Collect_Composer_Test
     (Path : String; Names : in out Name_Vectors.Vector)
   is
      F        : File_Type;
      Line     : String (1 .. Types.Max_Line);
      Last     : Natural;
      Overflow : Boolean;
      Line_Num : Natural := 0;
      In_Test  : Boolean := False;
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
            Close (F);
            return;
         end if;
         declare
            T : constant String := Trim (Line (1 .. Last));
            K : constant String := Json_Key (T);
         begin
            if K'Length > 0
              and then Contains_CI (K, "require")
              and then Ada.Strings.Fixed.Index (T, "{") > 0
            then
               In_Test :=
                 Contains_CI (K, "test")
                 or else Contains_CI (K, "require-dev");
            elsif In_Test then
               if T = "}" then
                  In_Test := False;
               else
                  declare
                     Dep : constant String := First_Quoted (T);
                  begin
                     if Dep'Length > 0 then
                        Add_Dep_Name (Names, Dep);
                     end if;
                  end;
               end if;
            end if;
         end;
      end loop;
      Close (F);
   end Collect_Composer_Test;

   --  Whether a Gemfile `group ... do` line declares a test-labelled
   --  group: any of its :symbols contains "test".
   function Gem_Group_Is_Test (T : String) return Boolean is
      I : Natural := T'First;
   begin
      while I <= T'Last loop
         if T (I) = ':' then
            declare
               J : Natural := I + 1;
            begin
               while J <= T'Last
                 and then (T (J) in 'a' .. 'z'
                           or else T (J) in 'A' .. 'Z'
                           or else T (J) in '0' .. '9'
                           or else T (J) = '_')
               loop
                  J := J + 1;
               end loop;
               if Contains_CI (T (I + 1 .. J - 1), "test") then
                  return True;
               end if;
               I := J;
            end;
         else
            I := I + 1;
         end if;
      end loop;
      return False;
   end Gem_Group_Is_Test;

   --  Gemfile: gems declared inside a `group :test ... do` block are
   --  test-labelled.
   procedure Collect_Gemfile_Test
     (Path : String; Names : in out Name_Vectors.Vector)
   is
      F             : File_Type;
      Line          : String (1 .. Types.Max_Line);
      Last          : Natural;
      Overflow      : Boolean;
      Line_Num      : Natural := 0;
      In_Test_Group : Boolean := False;
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
            Close (F);
            return;
         end if;
         declare
            T : constant String := Trim (Line (1 .. Last));
         begin
            if T'Length >= 5
              and then T (T'First .. T'First + 4) = "group"
              and then Ada.Strings.Fixed.Index (T, "do") > 0
            then
               In_Test_Group := Gem_Group_Is_Test (T);
            elsif T = "end" then
               In_Test_Group := False;
            elsif In_Test_Group
              and then T'Length >= 4
              and then T (T'First .. T'First + 3) = "gem "
            then
               declare
                  G : constant String := First_Quoted (T);
               begin
                  if G'Length > 0 then
                     Add_Dep_Name (Names, G);
                  end if;
               end;
            end if;
         end;
      end loop;
      Close (F);
   end Collect_Gemfile_Test;

   --  pom.xml: a <dependency> block whose <scope> is test declares a
   --  test-labelled dependency.  Both the bare artifactId and the
   --  groupId:artifactId forms are recorded so the vendored component
   --  name (which may carry either form) matches.
   procedure Collect_Pom_Test
     (Path : String; Names : in out Name_Vectors.Vector)
   is
      F        : File_Type;
      Line     : String (1 .. Types.Max_Line);
      Last     : Natural;
      Overflow : Boolean;
      Line_Num : Natural := 0;
      In_Dep   : Boolean := False;
      Dep_Test : Boolean := False;
      Artifact : String (1 .. Types.Max_Desc_Str) := (others => ' ');
      ALen     : Natural := 0;
      Group    : String (1 .. Types.Max_Desc_Str) := (others => ' ');
      GLen     : Natural := 0;
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
            Close (F);
            return;
         end if;
         declare
            T : constant String := Trim (Line (1 .. Last));
         begin
            if not In_Dep then
               if Ada.Strings.Fixed.Index (T, "<dependency>") > 0 then
                  In_Dep := True;
                  Dep_Test := False;
                  ALen := 0;
                  GLen := 0;
               end if;
            elsif Ada.Strings.Fixed.Index (T, "</dependency>") > 0 then
               if Dep_Test then
                  if ALen > 0 then
                     Add_Dep_Name (Names, Artifact (1 .. ALen));
                     if GLen > 0 then
                        Add_Dep_Name
                          (Names,
                           Group (1 .. GLen) & ":" & Artifact (1 .. ALen));
                     end if;
                  end if;
               end if;
               In_Dep := False;
            else
               declare
                  A : constant String := Line_Tag_Value (T, "artifactId");
                  G : constant String := Line_Tag_Value (T, "groupId");
                  S : constant String := Line_Tag_Value (T, "scope");
               begin
                  if A'Length > 0 then
                     ALen := A'Length;
                     if ALen > Artifact'Last then
                        ALen := Artifact'Last;
                     end if;
                     Artifact (1 .. ALen) := A (A'First .. A'First + ALen - 1);
                  end if;
                  if G'Length > 0 then
                     GLen := G'Length;
                     if GLen > Group'Last then
                        GLen := Group'Last;
                     end if;
                     Group (1 .. GLen) := G (G'First .. G'First + GLen - 1);
                  end if;
                  if S'Length > 0 and then S = "test" then
                     Dep_Test := True;
                  end if;
               end;
            end if;
         end;
      end loop;
      Close (F);
   end Collect_Pom_Test;

   --  pyproject.toml: optional-dependencies extras whose name contains
   --  "test" (for example the "test" extra), and Poetry group sections
   --  such as [tool.poetry.group.test.dependencies].
   procedure Collect_Pyproject_Test
     (Path : String; Names : in out Name_Vectors.Vector)
   is
      F                : File_Type;
      Line             : String (1 .. Types.Max_Line);
      Last             : Natural;
      Overflow         : Boolean;
      Line_Num         : Natural := 0;
      In_Opt           : Boolean := False;
      In_Test_List     : Boolean := False;
      Cur_Test_Section : Boolean := False;
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
            Close (F);
            return;
         end if;
         declare
            T : constant String := Trim (Line (1 .. Last));
         begin
            if T'Length > 2
              and then T (T'First) = '['
              and then T (T'Last) = ']'
            then
               declare
                  Sec : constant String :=
                    Trim (T (T'First + 1 .. T'Last - 1));
               begin
                  In_Opt := Sec = "project.optional-dependencies";
                  In_Test_List := False;
                  Cur_Test_Section :=
                    Contains_CI (Sec, ".dependencies")
                    and then Contains_CI (Sec, "test");
               end;
            elsif In_Opt then
               declare
                  Eq : Natural := 0;
               begin
                  for I in T'Range loop
                     if T (I) = '=' then
                        Eq := I;
                        exit;
                     end if;
                  end loop;
                  if Eq > T'First then
                     --  An extra key line (for example "test = [").
                     In_Test_List := False;
                     declare
                        K : constant String := Trim (T (T'First .. Eq - 1));
                     begin
                        if Contains_CI (K, "test") then
                           if Ada.Strings.Fixed.Index (T, "[") > 0
                             and then Ada.Strings.Fixed.Index (T, "]") = 0
                           then
                              In_Test_List := True;
                           else
                              Collect_Quoted_Names (T, Names);
                           end if;
                        end if;
                     end;
                  elsif In_Test_List then
                     --  Continuation lines of a multi-line test extra.
                     Collect_Quoted_Names (T, Names);
                     if Ada.Strings.Fixed.Index (T, "]") > 0 then
                        In_Test_List := False;
                     end if;
                  end if;
               end;
            elsif Cur_Test_Section then
               declare
                  Eq : Natural := 0;
               begin
                  for I in T'Range loop
                     if T (I) = '=' then
                        Eq := I;
                        exit;
                     end if;
                  end loop;
                  if Eq > T'First then
                     declare
                        Nm : constant String := Trim (T (T'First .. Eq - 1));
                     begin
                        if Nm'Length > 0 then
                           Add_Dep_Name (Names, Nm);
                        end if;
                     end;
                  end if;
               end;
            end if;
         end;
      end loop;
      Close (F);
   end Collect_Pyproject_Test;

   --  Whether the file or directory P exists on disk.
   --  @param P  Path to probe.
   --  @return True when P exists.
   function Exists (P : String) return Boolean renames Ada.Directories.Exists;
begin
   if Exists (Owner_Dir & "/package.json") then
      Collect_Npm_Test (Owner_Dir & "/package.json", Test_Names);
   elsif Exists (Owner_Dir & "/Cargo.toml") then
      Collect_Cargo_Test (Owner_Dir & "/Cargo.toml", Test_Names);
   elsif Exists (Owner_Dir & "/composer.json") then
      Collect_Composer_Test (Owner_Dir & "/composer.json", Test_Names);
   elsif Exists (Owner_Dir & "/Gemfile") then
      Collect_Gemfile_Test (Owner_Dir & "/Gemfile", Test_Names);
   elsif Exists (Owner_Dir & "/pom.xml") then
      Collect_Pom_Test (Owner_Dir & "/pom.xml", Test_Names);
   elsif Exists (Owner_Dir & "/pyproject.toml") then
      Collect_Pyproject_Test (Owner_Dir & "/pyproject.toml", Test_Names);
   end if;
end Collect_Owner_Test_Names;
