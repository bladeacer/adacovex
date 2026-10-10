separate (Adacovex.Parsers.Manifest)
--  First non-comment requirement line of a requirements*.txt:
--  "requests==2.28.1" -> name "requests", version "2.28.1".
procedure Req_Entry
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
         if T'Length > 0 and then T (T'First) /= '#' then
            declare
               Stop : Natural := T'First - 1;
               I    : Natural := T'First;
            begin
               while I <= T'Last
                 and then T (I) /= ' '
                 and then T (I) /= '='
                 and then T (I) /= '<'
                 and then T (I) /= '>'
                 and then T (I) /= '~'
               loop
                  I := I + 1;
               end loop;
               Stop := I - 1;
               if Stop >= T'First then
                  NLen := Stop - T'First + 1;
                  if NLen > 64 then
                     NLen := 64;
                  end if;
                  N (1 .. NLen) := T (T'First .. T'First + NLen - 1);
                  --  Skip operators and spaces, then take the version
                  --  token (up to whitespace, a comment, or end).
                  while I <= T'Last
                    and then T (I) in ' ' | '=' | '<' | '>' | '~' | '!'
                  loop
                     I := I + 1;
                  end loop;
                  begin
                     while I <= T'Last
                       and then T (I) /= ' '
                       and then T (I) /= '#'
                     loop
                        if VLen < 64 then
                           VLen := VLen + 1;
                           V (VLen) := T (I);
                        end if;
                        I := I + 1;
                     end loop;
                  end;
                  Close (F);
                  if NLen > 0 then
                     Name := N;
                     Version := V;
                     return;
                  end if;
               end if;
            end;
         end if;
      end;
   end loop;
   Close (F);
end Req_Entry;
