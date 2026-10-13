separate (Adacovex.Parsers.Manifest)
--  Read the top-level "<Key>" value of a JSON object file (package.json,
--  composer.json) with a structural scan: brace depth and string state are
--  tracked across the whole file, so only a key of the root object matches
--  (depth 1) and a key inside a string value never matches. A nested
--  "name" under another object cannot shadow the package name, and braces
--  or quotes inside a value change no state. The value must be a quoted
--  string; the capture is capped at Max_Desc_Str because the graph stores
--  every metadata field in a Desc_Field, so a longer capture could never
--  survive Append_Dependency. A physical line longer than Max_Line fails
--  loudly through Read_Line and yields "".
--  @param Path  Path of the JSON file.
--  @param Key  Top-level key to read.
--  @return The quoted value, or "" when absent or unreadable.
function Json_Top_Value (Path : String; Key : String) return String is
   use Ada.Text_IO;
   F        : File_Type;
   Line     : String (1 .. Types.Max_Line);
   Last     : Natural;
   Overflow : Boolean;
   Line_Num : Natural := 0;

   Buf  : String (1 .. Types.Max_Desc_Str);
   BLen : Natural := 0;

   --  Parsing state carried across physical lines: the key, its colon, and
   --  its value may sit on different lines.
   Depth     : Natural := 0;
   In_Str    : Boolean := False;
   Esc       : Boolean := False;
   After_Key : Boolean := False;
   Want_Val  : Boolean := False;
   In_Val    : Boolean := False;
   Val_Esc   : Boolean := False;

   function Is_Json_Ws (C : Character) return Boolean is
   begin
      return C = ' ' or else C = ASCII.HT or else C = ASCII.CR;
   end Is_Json_Ws;

   --  Whether the string T opens at position At_I with '"' & Key & '"'.
   --  The closing quote makes the match exact: "namefoo" never matches
   --  "name". The bound test is written as a subtraction so it cannot
   --  overflow for any Key length; the slice tests below are then only
   --  reached when every index is inside T.
   function Key_Matches (T : String; At_I : Natural) return Boolean is
   begin
      return
        Key'Length > 0
        and then Key'Length <= T'Last - At_I - 1
        and then T (At_I + 1 .. At_I + Key'Length) = Key
        and then T (At_I + Key'Length + 1) = '"';
   end Key_Matches;

   procedure Capture (C : Character) is
   begin
      if BLen < Buf'Last then
         BLen := BLen + 1;
         Buf (BLen) := C;
      end if;
   end Capture;

   --  Close F and hand back the captured value.
   function Captured return String is
   begin
      Close (F);
      return Buf (1 .. BLen);
   end Captured;
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
         I : Positive := Line'First;
      begin
         while I <= Last loop
            declare
               C : constant Character := Line (I);
            begin
               if In_Val then
                  if Val_Esc then
                     Capture (C);
                     Val_Esc := False;
                  elsif C = '\' then
                     Capture (C);
                     Val_Esc := True;
                  elsif C = '"' then
                     return Captured;
                  else
                     Capture (C);
                  end if;
               elsif In_Str then
                  if Esc then
                     Esc := False;
                  elsif C = '\' then
                     Esc := True;
                  elsif C = '"' then
                     In_Str := False;
                  end if;
               elsif Want_Val then
                  if C = '"' then
                     In_Val := True;
                     BLen := 0;
                  elsif C = '{' then
                     --  Not a string value (invalid for name, version, or
                     --  licence): give up on this key and keep the depth
                     --  state correct anyway.
                     Want_Val := False;
                     Depth := Depth + 1;
                  elsif C = '}' then
                     Want_Val := False;
                     if Depth > 0 then
                        Depth := Depth - 1;
                     end if;
                  elsif not Is_Json_Ws (C) then
                     --  null, a number, or a boolean: no quoted value to
                     --  read, and no brace that could desynchronise the
                     --  depth state.
                     Want_Val := False;
                  end if;
               elsif After_Key then
                  if C = ':' then
                     Want_Val := True;
                     After_Key := False;
                  elsif not Is_Json_Ws (C) then
                     --  No colon after the key (invalid JSON): give up on
                     --  this key and keep scanning from here.
                     After_Key := False;
                  end if;
               elsif C = '"' then
                  if Depth = 1
                    and then Key_Matches (Line (Line'First .. Last), I)
                  then
                     After_Key := True;
                     I := I + Key'Length + 1;
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
   return "";
exception
   when others =>
      if Is_Open (F) then
         Close (F);
      end if;
      return "";
end Json_Top_Value;
