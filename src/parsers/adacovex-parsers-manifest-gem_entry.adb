separate (Adacovex.Parsers.Manifest)
--  First "gem " entry of a Gemfile: name and cleaned version.
procedure Gem_Entry
  (Path    : String;
   Name    : out String;
   NLen    : out Natural;
   Version : out String;
   VLen    : out Natural)
is
   use Ada.Text_IO;
   F        : File_Type;
   Line     : String (1 .. Types.Max_Line);
   Last     : Natural;
   Overflow : Boolean;
   Line_Num : Natural := 0;
   N        : String (1 .. 64) := (others => ' ');
   V        : String (1 .. 64) := (others => ' ');
begin
   NLen := 0;
   VLen := 0;
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
         if T'Length > 4 and then T (T'First .. T'First + 3) = "gem " then
            --  Extract the quoted strings (name, then version).
            declare
               Got : Natural := 0;
               I   : Natural := T'First + 4;
            begin
               while I <= T'Last and Got < 2 loop
                  if T (I) = '"' then
                     declare
                        J : Natural := I + 1;
                     begin
                        while J <= T'Last and then T (J) /= '"' loop
                           J := J + 1;
                        end loop;
                        if J <= T'Last then
                           Got := Got + 1;
                           if Got = 1 then
                              NLen := J - I - 1;
                              if NLen > 64 then
                                 NLen := 64;
                              end if;
                              N (1 .. NLen) := T (I + 1 .. I + NLen);
                           else
                              VLen := J - I - 1;
                              if VLen > 64 then
                                 VLen := 64;
                              end if;
                              V (1 .. VLen) := T (I + 1 .. I + VLen);
                           end if;
                           I := J;
                        end if;
                     end;
                  end if;
                  I := I + 1;
               end loop;
            end;
            if NLen > 0 then
               Close (F);
               --  Trim non-version decoration from the version (for example
               --  ">= 12" -> "12").
               begin
                  while VLen > 0 and then V (1) not in '0' .. '9' loop
                     --  Skip "v" prefixes too but keep 'v' starts
                     V (1 .. VLen - 1) := V (2 .. VLen);
                     VLen := VLen - 1;
                  end loop;
               end;
               Name := N;
               Version := V;
               return;
            end if;
         end if;
      end;
   end loop;
   Close (F);
end Gem_Entry;
