separate (Adacovex.Parsers.Manifest)
--  Read the first "module <path>" line of a go.mod (the module path is
--  the Go component's canonical name).
function Go_Module_Path (Path : String) return String is
   use Ada.Text_IO;
   F        : File_Type;
   Line     : String (1 .. Types.Max_Line);
   Last     : Natural;
   Overflow : Boolean;
   Line_Num : Natural := 0;
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
         T : constant String := Trim (Line (1 .. Last));
      begin
         if T'Length > 7 and then T (T'First .. T'First + 6) = "module " then
            Close (F);
            return Trim (T (T'First + 7 .. T'Last));
         end if;
      end;
   end loop;
   Close (F);
   return "";
end Go_Module_Path;
