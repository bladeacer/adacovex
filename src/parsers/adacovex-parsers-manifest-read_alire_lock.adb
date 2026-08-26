separate (Adacovex.Parsers.Manifest)
procedure Read_Alire_Lock
  (Lock_Path : String;
   Graph     : in out Types.Implementation.Component_Vectors.Vector)
is
   use Ada.Text_IO;
   F                 : File_Type;
   Line              : String (1 .. Types.Max_Line);
   Last              : Natural;
   Overflow          : Boolean;
   Line_Num          : Natural := 0;
   In_State          : Boolean := False;
   Has_Crate         : Boolean := False;
   Crate_Name        : Types.Desc_Field;
   Crate_Name_Len    : Natural := 0;
   Crate_Version     : Types.Desc_Field;
   Crate_Version_Len : Natural := 0;
   Crate_License     : Types.Desc_Field;
   Crate_License_Len : Natural := 0;
   Crate_Desc        : Types.Path_Field;
   Crate_Desc_Len    : Natural := 0;
   Crate_Website     : Types.Path_Field;
   Crate_Website_Len : Natural := 0;

   procedure Flush is
   begin
      if In_State and Has_Crate and Crate_Name_Len > 0 then
         declare
            V    : constant String :=
              (if Crate_Version_Len > 0
               then
                 Crate_Name (1 .. Crate_Name_Len)
                 & "@"
                 & Crate_Version (1 .. Crate_Version_Len)
               else Crate_Name (1 .. Crate_Name_Len));
            PURL : constant String := "pkg:alire/" & V;
         begin
            Append_Dependency
              (Graph,
               Crate_Name (1 .. Crate_Name_Len),
               (if Crate_Version_Len > 0
                then Crate_Version (1 .. Crate_Version_Len)
                else ""),
               (if Crate_License_Len > 0
                then Crate_License (1 .. Crate_License_Len)
                else ""),
               Crate_Desc (1 .. Crate_Desc_Len),
               PURL,
               1,
               False,
               Classify_Scope (Crate_Name (1 .. Crate_Name_Len)),
               "Ada",
               (if Crate_Website_Len > 0
                then Crate_Website (1 .. Crate_Website_Len)
                else ""));
         end;
      end if;
      Crate_Name_Len := 0;
      Crate_Version_Len := 0;
      Crate_License_Len := 0;
      Crate_Desc_Len := 0;
      Crate_Website_Len := 0;
      Has_Crate := False;
   end Flush;

   procedure Capture (T : String) is
   begin
      declare
         V : constant String := Key_Value (T, "crate");
      begin
         if V'Length > 0 then
            Set_Field (Crate_Name, Crate_Name_Len, V);
            Has_Crate := True;
         end if;
      end;
      declare
         V : constant String := Key_Value (T, "name");
      begin
         if V'Length > 0 then
            Set_Field (Crate_Name, Crate_Name_Len, V);
            Has_Crate := True;
         end if;
      end;
      declare
         V : constant String := Key_Value (T, "version");
      begin
         if V'Length > 0 then
            Set_Field (Crate_Version, Crate_Version_Len, V);
         end if;
      end;
      declare
         V : constant String := Key_Value (T, "licenses");
      begin
         if V'Length > 0 then
            Set_Field (Crate_License, Crate_License_Len, V);
         end if;
      end;
      declare
         V : constant String := Key_Value (T, "description");
      begin
         if V'Length > 0 then
            Set_Path (Crate_Desc, Crate_Desc_Len, V);
         end if;
      end;
      declare
         V : constant String := Key_Value (T, "website");
      begin
         if V'Length > 0 then
            Set_Path (Crate_Website, Crate_Website_Len, V);
         end if;
      end;
   end Capture;

begin
   begin
      Open (F, In_File, Lock_Path);
   exception
      when others =>
         return;
   end;

   while not End_Of_File (F) loop
      Line_Num := Line_Num + 1;
      Adacovex.Parsers.Read_Line
        (F, Lock_Path, Line_Num, Line, Last, Overflow);
      if Overflow then
         --  A physical line longer than Max_Line is drained and reported
         --  by Read_Line; the lockfile is not resolved so no partial
         --  dependency graph is produced.
         Close (F);
         return;
      end if;
      declare
         T : constant String := Trim (Line (1 .. Last));
      begin
         if T'Length = 0 then
            null;
         elsif T (T'First) = '[' then
            if Starts_With (T, "[[solution.state]]") then
               Flush;
               In_State := True;
            else
               --  A nested section ([solution.state.release.X]); the
               --  crate remains the current one until the next state.
               null;
            end if;
         elsif In_State then
            Capture (T);
         end if;
      end;
   end loop;

   Flush;
   Close (F);
end Read_Alire_Lock;
