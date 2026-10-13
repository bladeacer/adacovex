separate (Adacovex.Parsers.Manifest)
--  Read "Key = ..." from the "[Section]" header block of a TOML file,
--  structurally: keys before the first header, keys of another section,
--  and keys of a sub-section ([tool.poetry.group] is not [tool.poetry])
--  never match, a commented line is skipped, and the key matches as a
--  whole word so "name" never matches inside "description". The value
--  must be a quoted string on the same physical line (TOML binds a key
--  and its value to one line); "" when absent. Cargo.toml is read from
--  [package] and pyproject.toml from [project] with [tool.poetry] as
--  the fallback, so a [dependencies] or [tool] table can never shadow
--  the package name or version. A physical line longer than Max_Line
--  fails loudly through Read_Line and yields "".
--  @param Path  Path of the TOML file.
--  @param Section  Header text without brackets (for example "package").
--  @param Key  Key to read inside the section.
--  @return The quoted value, or "" when absent or unreadable.
function Toml_Section_Value
  (Path : String; Section : String; Key : String) return String
is
   use Ada.Text_IO;
   F        : File_Type;
   Line     : String (1 .. Types.Max_Line);
   Last     : Natural;
   Overflow : Boolean;
   Line_Num : Natural := 0;

   In_Section : Boolean := False;

   function Is_Word_Char (C : Character) return Boolean is
   begin
      return
        (C in 'a' .. 'z')
        or else (C in 'A' .. 'Z')
        or else (C in '0' .. '9')
        or else C = '_'
        or else C = '-';
   end Is_Word_Char;

   --  Whether T is exactly "[Section]" with at most trailing blanks or a
   --  trailing comment after the closing bracket. A sub-section header
   --  ([tool.poetry.group.test]) does not match "[tool.poetry]".
   function Header_Matches (T : String) return Boolean is
      Open_B  : Natural := 0;
      Close_B : Natural := 0;
   begin
      if T'Length < 2 or else T (T'First) /= '[' then
         return False;
      end if;
      for I in T'First + 1 .. T'Last loop
         if T (I) = ']' then
            Close_B := I;
            exit;
         end if;
      end loop;
      if Close_B = 0 then
         return False;
      end if;
      --  Everything after ']' must be blanks or a comment.
      for I in Close_B + 1 .. T'Last loop
         if T (I) /= ' ' and then T (I) /= ASCII.HT and then T (I) /= '#' then
            return False;
         end if;
      end loop;
      Open_B := T'First;
      return T (Open_B + 1 .. Close_B - 1) = Section;
   end Header_Matches;

   --  The quoted value of a whole-word Key on the header's key line T,
   --  "" when the line carries no such key with a quoted value.
   function Line_Value (T : String) return String is
      Sep : Natural := 0;
   begin
      if Key'Length = 0 then
         return "";
      end if;
      for I in T'First .. T'Last - Key'Length + 1 loop
         if T (I .. I + Key'Length - 1) = Key
           and then (I = T'First or else not Is_Word_Char (T (I - 1)))
           and then (I + Key'Length > T'Last
                     or else not Is_Word_Char (T (I + Key'Length)))
         then
            declare
               J : Natural := I + Key'Length;
            begin
               while J <= T'Last and then T (J) /= '=' loop
                  J := J + 1;
               end loop;
               if J <= T'Last then
                  Sep := J;
                  exit;
               end if;
            end;
         end if;
      end loop;
      if Sep = 0 then
         return "";
      end if;
      --  The value must be a quoted string on this line.
      declare
         Q1 : Natural := 0;
         Q2 : Natural := 0;
      begin
         for Q in Sep + 1 .. T'Last loop
            if T (Q) = '"' then
               Q1 := Q;
               exit;
            end if;
         end loop;
         if Q1 = 0 then
            return "";
         end if;
         for Q in Q1 + 1 .. T'Last loop
            if T (Q) = '"' then
               Q2 := Q;
               exit;
            end if;
         end loop;
         if Q2 = 0 or else Q2 <= Q1 then
            return "";
         end if;
         return T (Q1 + 1 .. Q2 - 1);
      end;
   end Line_Value;
begin
   if Section'Length = 0 or else Key'Length = 0 then
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
         if T'Length = 0 then
            null;
         elsif T (T'First) = '#' then
            null;
         elsif T (T'First) = '[' then
            In_Section := Header_Matches (T);
         elsif In_Section then
            declare
               V : constant String := Line_Value (T);
            begin
               if V'Length > 0 then
                  Close (F);
                  return V;
               end if;
            end;
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
end Toml_Section_Value;
