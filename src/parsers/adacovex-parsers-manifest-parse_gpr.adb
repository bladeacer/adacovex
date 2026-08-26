separate (Adacovex.Parsers.Manifest)
--  Parse a GNAT project file: extract the project name and with clauses.
procedure Parse_GPR
  (GPR_Path  : String;
   Proj_Name : out Types.Desc_Field;
   Proj_Len  : out Natural;
   Deps      : in out Name_Vectors.Vector)
is
   use Ada.Text_IO;
   F            : File_Type;
   Line         : String (1 .. Types.Max_Line);
   Last         : Natural;
   Overflow     : Boolean;
   Line_Num     : Natural := 0;
   With_Pending : Boolean := False;

   procedure Add_Name (S : String) is
      Item : Name_Item;
      Name : String := Trim (S);
   begin
      --  Strip a trailing ".gpr" extension.
      if Name'Length > 4 and then Name (Name'Last - 3 .. Name'Last) = ".gpr"
      then
         Name := Name (Name'First .. Name'Last - 4);
      end if;
      if Name'Length = 0 then
         return;
      end if;
      --  Skip duplicates.
      for I in 1 .. Integer (Deps.Length) loop
         if Deps (I).Len = Name'Length
           and then Deps (I).Name (1 .. Name'Length) = Name
         then
            return;
         end if;
      end loop;
      Item.Len := Name'Length;
      for I in 1 .. Name'Length loop
         Item.Name (I) := Name (Name'First + I - 1);
      end loop;
      Deps.Append (Item);
   end Add_Name;

   procedure Extract_Quoted (T : String) is
      In_Q  : Boolean := False;
      Start : Natural := 0;
   begin
      for I in T'Range loop
         if T (I) = '"' then
            if not In_Q then
               In_Q := True;
               Start := I + 1;
            else
               Add_Name (T (Start .. I - 1));
               In_Q := False;
            end if;
         end if;
      end loop;
   end Extract_Quoted;

   function Has_Semicolon (T : String) return Boolean is
   begin
      for I in T'Range loop
         if T (I) = ';' then
            return True;
         end if;
      end loop;
      return False;
   end Has_Semicolon;

begin
   Proj_Len := 0;

   begin
      Open (F, In_File, GPR_Path);
   exception
      when others =>
         return;
   end;

   while not End_Of_File (F) loop
      Line_Num := Line_Num + 1;
      Adacovex.Parsers.Read_Line (F, GPR_Path, Line_Num, Line, Last, Overflow);
      if Overflow then
         --  A physical line longer than Max_Line is drained and reported
         --  by Read_Line; the .gpr is not resolved so no partial
         --  dependency graph is produced.
         Close (F);
         return;
      end if;
      declare
         T : constant String := Trim (Line (1 .. Last));
      begin
         if Proj_Len = 0 and then Starts_With (T, "project ") then
            declare
               Name_Start : constant Natural := T'First + 8;
               I          : Natural := Name_Start;
            begin
               while I <= T'Last and then T (I) not in ' ' | ':' | '(' loop
                  I := I + 1;
               end loop;
               if I > Name_Start then
                  Set_Field (Proj_Name, Proj_Len, T (Name_Start .. I - 1));
               end if;
            end;
         end if;

         if Starts_With (T, "with ") then
            Extract_Quoted (T);
            With_Pending := not Has_Semicolon (T);
         elsif With_Pending then
            Extract_Quoted (T);
            With_Pending := not Has_Semicolon (T);
         end if;
      end;
   end loop;

   Close (F);
end Parse_GPR;
