separate (Adacovex.Parsers.Manifest)
--  First <Tag>...</Tag> occurrence on a single line of an XML file
--  (pom.xml).  Returns the inner text, "" when absent.
function Xml_Tag_Value (Path : String; Tag : String) return String is
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
         T  : constant String := Line (1 .. Last);
         O  : constant String := "<" & Tag & ">";
         C  : constant String := "</" & Tag & ">";
         OI : constant Natural := Ada.Strings.Fixed.Index (T, O);
         CI : constant Natural := Ada.Strings.Fixed.Index (T, C);
      begin
         if OI > T'First - 1 and then CI >= OI + O'Length then
            Close (F);
            return T (OI + O'Length .. CI - 1);
         end if;
      end;
   end loop;
   Close (F);
   return "";
end Xml_Tag_Value;
