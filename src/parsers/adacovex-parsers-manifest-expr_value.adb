separate (Adacovex.Parsers.Manifest)
--  Read the value of a "Key <separator> value" declaration from a manifest
--  whose syntax is a plain key/value line rather than JSON, TOML, or XML.
--  One reader serves every such ecosystem, so a new language is a table row
--  in Read_Vendor_Manifest rather than a new code path:
--    * "colon"  --  "Key: value"        (pubspec.yaml, DESCRIPTION,
--                                        *.opam, *.cabal)
--    * "equals" --  "Key = value"       (build.gradle, conanfile.py,
--                                        *.gemspec, *.rockspec)
--    * "either" --  a colon or an equals, whichever comes first (mix.exs)
--    * "braced" --  "{Key, value}"      (rebar.config)
--  The key matches as a whole word, so "name" never matches inside
--  "namespace". A commented line is skipped. The value is read from its
--  opening quote to the matching closing quote, or -- unquoted -- up to the
--  first comma, semicolon, closing bracket, or brace, so a tuple, a list
--  entry, a version constraint, or a trailing comment never leaks into the
--  value. A leading atom or reference marker (":" in mix.exs's
--  "app: :my_app") is a sigil, not part of the name.
--  The first matching line wins: a manifest states its own package identity
--  once, and a later occurrence belongs to a dependency or a sub-stanza.
--  A value longer than Max_Desc_Str is capped, because the graph stores
--  every metadata field in a Desc_Field. A physical line longer than
--  Max_Line fails loudly through Read_Line and yields "".
--  @param Path  Path of the manifest file.
--  @param Style  The separator style ("colon", "equals", "either", "braced").
--  @param Key  Key to read (for example "name", "version", "vsn").
--  @return The value, or "" when absent or unreadable.
function Expr_Value (Path : String; Style : String; Key : String) return String
is
   use Ada.Text_IO;
   F        : File_Type;
   Line     : String (1 .. Types.Max_Line);
   Last     : Natural;
   Overflow : Boolean;
   Line_Num : Natural := 0;

   function Is_Blank (C : Character) return Boolean is
   begin
      return C = ' ' or else C = ASCII.HT;
   end Is_Blank;

   --  Whether C can appear in a manifest key. '.' is not a word character,
   --  so a dotted prefix ("s.name" in a gemspec) matches the key "name".
   function Is_Word_Char (C : Character) return Boolean is
   begin
      return
        (C in 'a' .. 'z')
        or else (C in 'A' .. 'Z')
        or else (C in '0' .. '9')
        or else C = '_'
        or else C = '-';
   end Is_Word_Char;

   --  Whether C ends an unquoted value.
   function Is_Terminator (C : Character) return Boolean is
   begin
      return
        C = ','
        or else C = ';'
        or else C = ')'
        or else C = '}'
        or else C = ']'
        or else C = '#';
   end Is_Terminator;

   --  The value that follows the separator at position After.
   --  @param Text  The trimmed declaration line.
   --  @param After  Index of the separator character.
   --  @return The cleaned value, or "" when the line carries none.
   function Value_After (Text : String; After : Natural) return String is
      A : Natural := After + 1;
      B : Natural := Text'Last;
      Q : Character;
   begin
      while A <= B and then Is_Blank (Text (A)) loop
         A := A + 1;
      end loop;
      if A > B then
         return "";
      end if;
      if Text (A) = '"' or else Text (A) = ''' then
         --  A quoted value runs to its closing partner. An unterminated
         --  quote takes the rest of the line.
         Q := Text (A);
         A := A + 1;
         B := A;
         while B <= Text'Last and then Text (B) /= Q loop
            B := B + 1;
         end loop;
         if B > Text'Last then
            B := Text'Last;
         elsif B > A then
            B := B - 1;
         else
            return "";
         end if;
      else
         --  An unquoted value ends at the first terminator.
         B := A;
         while B <= Text'Last and then not Is_Terminator (Text (B)) loop
            B := B + 1;
         end loop;
         B := B - 1;
      end if;
      while B >= A and then Is_Blank (Text (B)) loop
         B := B - 1;
      end loop;
      if A <= B and then (Text (A) = ':' or else Text (A) = '@') then
         A := A + 1;
      end if;
      if A > B then
         return "";
      end if;
      if B - A + 1 > Types.Max_Desc_Str then
         B := A + Types.Max_Desc_Str - 1;
      end if;
      return Text (A .. B);
   end Value_After;
begin
   if Key'Length = 0 then
      return "";
   end if;
   begin
      Open (F, In_File, Path);
   exception
      when others =>
         return "";
   end;
   while not End_Of_File (F) loop
      Line_Num := Line_Num + 1;
      Adacovex.Parsers.Read_Line (F, Path, Line_Num, Line, Last, Overflow);
      if Overflow then
         Close (F);
         return "";
      end if;
      declare
         T : constant String := Trim (Line (Line'First .. Last));
      begin
         if T'Length = 0
           or else T (T'First) = '#'
           or else T (T'First) = ';'
           or else T (T'First) = '/'
         then
            null;
         else
            for I in T'First .. T'Last loop
               if I + Key'Length - 1 <= T'Last
                 and then T (I .. I + Key'Length - 1) = Key
                 and then (I = T'First or else not Is_Word_Char (T (I - 1)))
                 and then (I + Key'Length > T'Last
                           or else not Is_Word_Char (T (I + Key'Length)))
               then
                  declare
                     J : Natural := I + Key'Length;
                  begin
                     while J <= T'Last and then Is_Blank (T (J)) loop
                        J := J + 1;
                     end loop;
                     if J <= T'Last
                       and then ((T (J) = ':'
                                  and then (Style = "colon"
                                            or else Style = "either"))
                                 or else (T (J) = '='
                                          and then (Style = "equals"
                                                    or else Style = "either"))
                                 or else (T (J) = ','
                                          and then Style = "braced"))
                     then
                        declare
                           V : constant String := Value_After (T, J);
                        begin
                           if V'Length > 0 then
                              Close (F);
                              return V;
                           end if;
                        end;
                     end if;
                  end;
               end if;
            end loop;
         end if;
      end;
   end loop;
   Close (F);
   return "";
exception
   when others =>
      if Is_Open (F) then
         Close (F);
      end if;
      return "";
end Expr_Value;
