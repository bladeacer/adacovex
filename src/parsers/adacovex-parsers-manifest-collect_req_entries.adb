separate (Adacovex.Parsers.Manifest)
--  Collect every non-comment requirement line of a requirements*.txt:
--  \"requests==2.28.1\" -> name \"requests\", version \"2.28.1\"; a bare
--  \"requests\" -> name \"requests\", empty version.  An overlong physical
--  line stops the read (the file is never partially trusted beyond the
--  entries already collected).
procedure Collect_Req_Entries (Path : String; Reqs : in out Req_Vectors.Vector)
is
   use Ada.Text_IO;
   F        : File_Type;
   Line     : String (1 .. Types.Max_Line);
   Last     : Natural;
   Overflow : Boolean;
   Line_Num : Natural := 0;
   Item     : Req_Item;
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
         if T'Length > 0 and then T (T'First) /= '#' then
            declare
               I : Natural := T'First;
            begin
               --  The package name runs up to whitespace or a version
               --  operator (=, <, >, ~, !).
               while I <= T'Last
                 and then T (I) /= ' '
                 and then T (I) /= '='
                 and then T (I) /= '<'
                 and then T (I) /= '>'
                 and then T (I) /= '~'
               loop
                  I := I + 1;
               end loop;
               Item.Len := I - T'First;
               if Item.Len > Item.Name'Last then
                  Item.Len := Item.Name'Last;
               end if;
               if Item.Len > 0 then
                  Item.Name (1 .. Item.Len) :=
                    T (T'First .. T'First + Item.Len - 1);
                  --  Skip operators and spaces, then take the version token
                  --  (up to whitespace, a comment, or end).
                  while I <= T'Last
                    and then T (I) in ' ' | '=' | '<' | '>' | '~' | '!'
                  loop
                     I := I + 1;
                  end loop;
                  Item.VLen := 0;
                  while I <= T'Last and then T (I) /= ' ' and then T (I) /= '#'
                  loop
                     if Item.VLen < Item.Ver'Last then
                        Item.VLen := Item.VLen + 1;
                        Item.Ver (Item.VLen) := T (I);
                     end if;
                     I := I + 1;
                  end loop;
                  Reqs.Append (Item);
                  Item := (others => <>);
               end if;
            end;
         end if;
      end;
   end loop;
   Close (F);
end Collect_Req_Entries;
