separate (Adacovex.Parsers.Manifest)
--  Read the first "<Key>" quoted value from a key=value or key:value
--  file (TOML or JSON, quoted key or bare): locate Key followed by '='
--  or ':', then the next double-quoted string.  "" when absent.
function File_Quoted_Value (Path : String; Key : String) return String is
   use Ada.Text_IO;
   F        : File_Type;
   Line     : String (1 .. Types.Max_Line);
   Last     : Natural;
   Overflow : Boolean;
   Line_Num : Natural := 0;

   function Is_Word_Char (C : Character) return Boolean is
   begin
      return
        (C in 'a' .. 'z')
        or else (C in 'A' .. 'Z')
        or else (C in '0' .. '9')
        or else C = '_'
        or else C = '-';
   end Is_Word_Char;

   function Line_Value (T : String) return String is
      Sep : Natural := 0;
   begin
      --  Locate Key as a whole word, then find the '=' or ':' separator
      --  right after it (spaces allowed between key and separator).
      for I in T'First .. T'Last - Key'Length + 1 loop
         if T (I .. I + Key'Length - 1) = Key
           and then (I = T'First or else not Is_Word_Char (T (I - 1)))
           and then (I + Key'Length > T'Last
                     or else not Is_Word_Char (T (I + Key'Length)))
         then
            declare
               J : Natural := I + Key'Length;
            begin
               while J <= T'Last and then T (J) /= '=' and then T (J) /= ':'
               loop
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
      --  Find the next quoted string after the separator.
      for Q in Sep + 1 .. T'Last loop
         if T (Q) = '"' then
            for Q2 in Q + 1 .. T'Last loop
               if T (Q2) = '"' then
                  return T (Q + 1 .. Q2 - 1);
               end if;
            end loop;
            return "";
         end if;
      end loop;
      return "";
   end Line_Value;
begin
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
         V : constant String := Line_Value (Trim (Line (1 .. Last)));
      begin
         if V'Length > 0 then
            Close (F);
            return V;
         end if;
      end;
   end loop;
   Close (F);
   return "";
end File_Quoted_Value;
