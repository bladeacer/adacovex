separate (Adacovex.Parsers.Manifest)
--  Scan one dev-facing build file for every known system tool. A file that
--  cannot be opened is skipped. A physical line longer than Types.Max_Line
--  stops the scan of that file, so a truncated file never yields a partial
--  tool set.
--  @param Path  Path of the file to read.
procedure Scan_File (Path : String) is
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
         return;
   end;
   while not End_Of_File (F) loop
      Line_Num := Line_Num + 1;
      Adacovex.Parsers.Read_Line
        (F, Path, Line_Num, Line, Last, Overflow);
      if Overflow then
         --  A physical line longer than Max_Line. Stop scanning this
         --  file. A truncated file then never yields a partial tool
         --  set.
         Close (F);
         return;
      end if;
      if Ada.Strings.Fixed.Index
           (Line (1 .. Last), "System_Tools : constant array")
        > 0
      then
         --  This file declares the curated tool table. Every entry is
         --  a literal tool name by construction. References found
         --  here can register every installed tool. This happens
         --  regardless of whether the project actually uses the tool.
         Close (F);
         return;
      end if;
      Note_Referenced_Tools (Line (1 .. Last));
   end loop;
   Close (F);
exception
   when others =>
      if Is_Open (F) then
         Close (F);
      end if;
end Scan_File;