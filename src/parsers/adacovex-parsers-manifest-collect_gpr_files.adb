separate (Adacovex.Parsers.Manifest)
--  Collect every .gpr file under Target_Dir (excluding obj, alire, and
--  more).
procedure Collect_GPR_Files
  (Target_Dir : String; Files : in out Path_Vectors.Vector)
is
   use Ada.Directories;
   type Dir_Entry is record
      Path : Types.Path_Field;
      Len  : Natural := 0;
   end record;
   package Dir_Stacks is new Ada.Containers.Vectors (Positive, Dir_Entry);
   Dir_Stack : Dir_Stacks.Vector;
   Search    : Search_Type;
   Ent       : Directory_Entry_Type;

   procedure Push_Dir (Dir : String) is
      Item : Dir_Entry;
   begin
      if Dir'Length <= Types.Max_Path then
         Item.Len := Dir'Length;
         for I in Dir'Range loop
            Item.Path (I - Dir'First + 1) := Dir (I);
         end loop;
         Dir_Stack.Append (Item);
      end if;
   end Push_Dir;
begin
   Push_Dir (Target_Dir);

   while not Dir_Stack.Is_Empty loop
      declare
         Current  : Dir_Entry := Dir_Stack.Last_Element;
         Dir_Path : String renames Current.Path (1 .. Current.Len);
      begin
         Dir_Stack.Delete_Last;

         Start_Search (Search, Dir_Path, "");
         begin
            while More_Entries (Search) loop
               Get_Next_Entry (Search, Ent);
               declare
                  Name : constant String := Simple_Name (Ent);
                  Path : constant String := Full_Name (Ent);
                  Dot  : Natural := 0;
               begin
                  if Kind (Ent) = Directory then
                     if Name /= "."
                       and Name /= ".."
                       and Name /= ".git"
                       and Name /= "obj"
                       and Name /= "config"
                       and Name /= ".adacovex"
                       and Name /= "alire"
                     then
                        Push_Dir (Path);
                     end if;
                  elsif Kind (Ent) = Ordinary_File then
                     for I in reverse Name'Range loop
                        if Name (I) = '.' then
                           Dot := I;
                           exit;
                        end if;
                     end loop;
                     if Dot > 0 and then Name (Dot .. Name'Last) = ".gpr" then
                        declare
                           Item : Path_Item;
                        begin
                           Item.Len := Path'Length;
                           for I in Path'Range loop
                              Item.Path (I - Path'First + 1) := Path (I);
                           end loop;
                           Files.Append (Item);
                        end;
                     end if;
                  end if;
               end;
            end loop;
         exception
            when others =>
               End_Search (Search);
               raise;
         end;
         End_Search (Search);
      end;
   end loop;
end Collect_GPR_Files;
