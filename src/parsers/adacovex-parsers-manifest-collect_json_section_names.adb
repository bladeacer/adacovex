separate (Adacovex.Parsers.Manifest)
--  Collect every dependency name a JSON manifest's section declares: the
--  keys directly inside the top-level "<Section>" object (package.json's
--  "dependencies" or "devDependencies"). The parse is structural -- brace
--  depth and string state are tracked across the whole file -- so a key
--  nested deeper, a key inside a string value, or a section of another
--  name never contributes. Names longer than Max_Desc_Str keep their
--  first Max_Desc_Str bytes (the graph stores names in a Desc_Field).
--  A physical line longer than Max_Line fails loudly through Read_Line,
--  and a section that never closes contributes nothing: Names gains the
--  collected names only when the section's closing brace is seen.
--  @param Path  Path of the JSON file.
--  @param Section  Top-level section whose keys to collect.
--  @param Names  Collected names, appended to on success.
procedure Collect_Json_Section_Names
  (Path : String; Section : String; Names : in out Name_Vectors.Vector)
is
   use Ada.Text_IO;
   F        : File_Type;
   Line     : String (1 .. Types.Max_Line);
   Last     : Natural;
   Overflow : Boolean;
   Line_Num : Natural := 0;

   --  Collected names. Appended to Names only when the section closes
   --  cleanly, so an unreadable file or an unterminated section leaves
   --  the caller's vector untouched.
   Local : Name_Vectors.Vector;

   --  Parsing state carried across physical lines.
   Depth      : Natural := 0;
   In_Str     : Boolean := False;
   Esc        : Boolean := False;
   Want_Obj   : Boolean := False;
   In_Section : Boolean := False;
   Sec_Depth  : Natural := 0;

   function Is_Json_Ws (C : Character) return Boolean is
   begin
      return C = ' ' or else C = ASCII.HT or else C = ASCII.CR;
   end Is_Json_Ws;

   --  Whether the string T opens at position At_I with '"' & Wanted & '"'.
   --  The closing quote makes the match exact. The bound test is a
   --  subtraction so it cannot overflow for any Wanted length; the slice
   --  tests are only reached when every index is inside T.
   function Key_Matches
     (T : String; At_I : Natural; Wanted : String) return Boolean is
   begin
      return
        Wanted'Length > 0
        and then Wanted'Length <= T'Last - At_I - 1
        and then T (At_I + 1 .. At_I + Wanted'Length) = Wanted
        and then T (At_I + Wanted'Length + 1) = '"';
   end Key_Matches;

   --  Whether the string starting at At_I in T is a key of the current
   --  object: a closing quote (escape pairs honoured), optional blanks,
   --  then ':'. On success K_First and K_Last bound the key text.
   function Dep_Key
     (T : String; At_I : Natural; K_First : out Natural; K_Last : out Natural)
      return Boolean
   is
      J : Natural := At_I;
   begin
      K_First := 0;
      K_Last := 0;
      while J < T'Last loop
         J := J + 1;
         if T (J) = '\' then
            J := J + 1;
         elsif T (J) = '"' then
            --  J is the closing quote. Blanks, then ':' makes it a key.
            declare
               K : Natural := J + 1;
            begin
               while K <= T'Last and then Is_Json_Ws (T (K)) loop
                  K := K + 1;
               end loop;
               if K <= T'Last and then T (K) = ':' then
                  K_First := At_I + 1;
                  K_Last := J - 1;
                  return K_Last >= K_First;
               end if;
               return False;
            end;
         end if;
      end loop;
      return False;
   end Dep_Key;

   --  Append the key text T (K_First .. K_Last) to Local, capped at the
   --  Desc_Field bound the graph can hold.
   procedure Append_Key (T : String; K_First : Natural; K_Last : Natural) is
      Item : Name_Item;
      N    : constant Natural := K_Last - K_First + 1;
   begin
      Item.Len := N;
      if Item.Len > Types.Max_Desc_Str then
         Item.Len := Types.Max_Desc_Str;
      end if;
      for K in 1 .. Item.Len loop
         Item.Name (K) := T (K_First + K - 1);
      end loop;
      Local.Append (Item);
   end Append_Key;
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
         I : Positive := Line'First;
      begin
         while I <= Last loop
            declare
               C  : constant Character := Line (I);
               T  : constant String := Line (Line'First .. Last);
               K1 : Natural := 0;
               K2 : Natural := 0;
            begin
               if In_Str then
                  if Esc then
                     Esc := False;
                  elsif C = '\' then
                     Esc := True;
                  elsif C = '"' then
                     In_Str := False;
                  end if;
               elsif Want_Obj then
                  if Is_Json_Ws (C) or else C = ':' then
                     --  Blanks and the key's colon pass before the
                     --  section's opening brace.
                     null;
                  elsif C = '{' then
                     Depth := Depth + 1;
                     Sec_Depth := Depth;
                     In_Section := True;
                     Want_Obj := False;
                  else
                     --  The section value is not an object: give up on
                     --  this key (invalid manifest for dependency use).
                     Want_Obj := False;
                  end if;
               elsif In_Section and then Depth = Sec_Depth and then C = '}'
               then
                  --  The section's own closing brace: commit and finish.
                  Depth := Depth - 1;
                  In_Section := False;
                  Close (F);
                  for K in 1 .. Integer (Local.Length) loop
                     Names.Append (Local (K));
                  end loop;
                  return;
               elsif C = '"' then
                  if In_Section
                    and then Depth = Sec_Depth
                    and then Dep_Key (T, I, K1, K2)
                  then
                     Append_Key (T, K1, K2);
                     --  Land on the key's closing quote: the loop step
                     --  then moves past it, so the quote state stays
                     --  balanced for the rest of the file.
                     I := K2 + 1;
                  elsif Depth = 1 and then Key_Matches (T, I, Section) then
                     Want_Obj := True;
                     I := I + Section'Length + 1;
                  else
                     In_Str := True;
                  end if;
               elsif C = '{' then
                  Depth := Depth + 1;
               elsif C = '}' then
                  if Depth > 0 then
                     Depth := Depth - 1;
                  end if;
               end if;
            end;
            I := I + 1;
         end loop;
      end;
   end loop;
   Close (F);
exception
   when others =>
      if Is_Open (F) then
         Close (F);
      end if;
end Collect_Json_Section_Names;
