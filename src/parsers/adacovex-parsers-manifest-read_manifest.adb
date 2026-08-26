separate (Adacovex.Parsers.Manifest)
--  Read root-project metadata from an Alire manifest (alire.toml / dev).
procedure Read_Manifest
  (Manifest_Path    : String;
   Root_Name        : out Types.Desc_Field;
   Root_Name_Len    : out Natural;
   Root_Version     : out Types.Desc_Field;
   Root_Version_Len : out Natural;
   Root_License     : out Types.Desc_Field;
   Root_License_Len : out Natural;
   Root_Desc        : out Types.Path_Field;
   Root_Desc_Len    : out Natural;
   Root_Website     : out Types.Path_Field;
   Root_Website_Len : out Natural;
   Project_File     : out Types.Path_Field;
   Project_File_Len : out Natural;
   Success          : out Boolean)
is
   use Ada.Text_IO;
   F        : File_Type;
   Line     : String (1 .. Types.Max_Line);
   Last     : Natural;
   Overflow : Boolean;
   Line_Num : Natural := 0;
begin
   Root_Name_Len := 0;
   Root_Version_Len := 0;
   Root_License_Len := 0;
   Root_Desc_Len := 0;
   Root_Website_Len := 0;
   Project_File_Len := 0;
   Success := False;

   begin
      Open (F, In_File, Manifest_Path);
   exception
      when others =>
         return;
   end;

   while not End_Of_File (F) loop
      Line_Num := Line_Num + 1;
      Adacovex.Parsers.Read_Line
        (F, Manifest_Path, Line_Num, Line, Last, Overflow);
      if Overflow then
         --  A physical line longer than Max_Line is drained and reported by
         --  Read_Line.  The manifest is not resolved.  No partial dependency
         --  graph is produced.
         Close (F);
         return;
      end if;
      declare
         T : constant String := Trim (Line (1 .. Last));
      begin
         if Root_Name_Len = 0 then
            declare
               V : constant String := Key_Value (T, "name");
            begin
               if V'Length > 0 then
                  Set_Field (Root_Name, Root_Name_Len, V);
               end if;
            end;
         end if;
         if Root_Version_Len = 0 then
            declare
               V : constant String := Key_Value (T, "version");
            begin
               if V'Length > 0 then
                  Set_Field (Root_Version, Root_Version_Len, V);
               end if;
            end;
         end if;
         if Root_License_Len = 0 then
            declare
               V : constant String := Key_Value (T, "licenses");
            begin
               if V'Length > 0 then
                  Set_Field (Root_License, Root_License_Len, V);
               end if;
            end;
         end if;
         if Root_Desc_Len = 0 then
            declare
               V : constant String := Key_Value (T, "description");
            begin
               if V'Length > 0 then
                  Set_Path (Root_Desc, Root_Desc_Len, V);
               end if;
            end;
         end if;
         if Root_Website_Len = 0 then
            declare
               V : constant String := Key_Value (T, "website");
            begin
               if V'Length > 0 then
                  Set_Path (Root_Website, Root_Website_Len, V);
               end if;
            end;
         end if;
         if Project_File_Len = 0 then
            declare
               V : constant String := First_List_Value (T, "project-files");
            begin
               if V'Length > 0 then
                  Set_Path (Project_File, Project_File_Len, V);
               end if;
            end;
         end if;
      end;
   end loop;

   Close (F);
   Success := Root_Name_Len > 0;
end Read_Manifest;
