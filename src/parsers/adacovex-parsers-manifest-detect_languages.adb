separate (Adacovex.Parsers.Manifest)
--  Count the source files under Root by language, descending at most
--  Max_Levels subdirectories (0 = Root's direct children only).  Only
--  file names are read (no content), so this is cheap.  When Skip_Vend
--  is True, vendored directories are not descended into -- used for the
--  root project's own language so vendored code is never attributed to
--  the owning project.
procedure Detect_Languages
  (Root          : String;
   Max_Levels    : Natural;
   Langs         : in out Lang_Vectors.Vector;
   Skip_Vendored : Boolean := False)
is
   use Ada.Directories;
   type Dir_Entry is record
      Path  : Types.Path_Field;
      Len   : Natural := 0;
      Level : Natural := 0;
   end record;
   package Dir_Stacks is new Ada.Containers.Vectors (Positive, Dir_Entry);
   Dir_Stack : Dir_Stacks.Vector;
   Search    : Search_Type;
   Ent       : Directory_Entry_Type;

   procedure Push_Dir (Dir : String; Level : Natural) is
      Item : Dir_Entry;
   begin
      if Dir'Length <= Types.Max_Path then
         Item.Len := Dir'Length;
         for I in Dir'Range loop
            Item.Path (I - Dir'First + 1) := Dir (I);
         end loop;
         Item.Level := Level;
         Dir_Stack.Append (Item);
      end if;
   end Push_Dir;

   procedure Count_File (N : String) is
      L : constant String := Extension_Language (N);
   begin
      if L'Length = 0 then
         return;
      end if;
      for I in 1 .. Integer (Langs.Length) loop
         if Langs (I).Len = L'Length
           and then Langs (I).Name (1 .. L'Length) = L
         then
            Langs (I).Ct := Langs (I).Ct + 1;
            return;
         end if;
      end loop;
      declare
         Item : Lang_Item;
      begin
         Item.Len := L'Length;
         for I in 1 .. L'Length loop
            Item.Name (I) := L (L'First + I - 1);
         end loop;
         Item.Ct := 1;
         Langs.Append (Item);
      end;
   end Count_File;
begin
   Langs.Clear;
   Push_Dir (Root, 0);
   while not Dir_Stack.Is_Empty loop
      declare
         Current  : Dir_Entry := Dir_Stack.Last_Element;
         Dir_Path : String renames Current.Path (1 .. Current.Len);
         Snap     : Adacovex.Dir_Cache.Dir_Entry_List;
         SCt      : Natural;
         STrunc   : Boolean;
         SOK      : Boolean;
      begin
         Dir_Stack.Delete_Last;
         --  Shared snapshot first (one enumeration per directory per
         --  process across every walker); direct enumeration only on the
         --  fallback path (over-cap tree or unreadable snapshot).
         Adacovex.Dir_Cache.Snapshot (Dir_Path, Snap, SCt, STrunc, SOK);
         if SOK and then not STrunc then
            for SI in 1 .. SCt loop
               declare
                  N    : constant String :=
                    Snap (SI).Name (1 .. Snap (SI).Name_Len);
                  Is_D : constant Boolean :=
                    Adacovex.Dir_Cache.Is_Directory (Snap (SI).Kind);
               begin
                  if Is_D then
                     if Current.Level < Max_Levels
                       and then not Skip_Walk_Dir (N)
                       and then (not Skip_Vendored
                                 or else not Is_Vendor_Dir_Name (N))
                     then
                        Push_Dir (Dir_Path & "/" & N, Current.Level + 1);
                     end if;
                  else
                     Count_File (N);
                  end if;
               end;
            end loop;
         else
            Start_Search (Search, Dir_Path, "");
            begin
               while More_Entries (Search) loop
                  Get_Next_Entry (Search, Ent);
                  declare
                     N    : constant String := Simple_Name (Ent);
                     Path : constant String := Full_Name (Ent);
                  begin
                     if Kind (Ent) = Directory then
                        if N /= "."
                          and then N /= ".."
                          and then Current.Level < Max_Levels
                          and then not Skip_Walk_Dir (N)
                          and then (not Skip_Vendored
                                    or else not Is_Vendor_Dir_Name (N))
                        then
                           Push_Dir (Path, Current.Level + 1);
                        end if;
                     elsif Kind (Ent) = Ordinary_File then
                        Count_File (N);
                     end if;
                  end;
               end loop;
            exception
               when others =>
                  End_Search (Search);
                  raise;
            end;
            End_Search (Search);
         end if;
      end;
   end loop;
end Detect_Languages;
