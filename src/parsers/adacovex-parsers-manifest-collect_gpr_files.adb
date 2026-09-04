separate (Adacovex.Parsers.Manifest)
--  Collect every .gpr file under Target_Dir (excluding obj, alire, and
--  more).  The walk skips every always-excluded directory (VCS metadata,
--  virtual environments, installer/build outputs, and node_modules), so a
--  target with a .venv of thousands of files is never enumerated just to
--  find its .gpr files.  This walk runs on every graph build (before the
--  cached-graph lookup), so its skip set is the difference between a
--  bounded walk and a whole-tree crawl.  Enumerations are served from the
--  shared per-process snapshot memo: the graph build runs several walks
--  over the same directories, and the memo makes the later ones pay one
--  mtime stat instead of a full enumeration.
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
         Snap     : Adacovex.Dir_Cache.Dir_Entry_List;
         SCt      : Natural;
         STrunc   : Boolean;
         SOK      : Boolean;
      begin
         Dir_Stack.Delete_Last;

         --  Shared snapshot first; direct enumeration only on the
         --  fallback path (over-cap tree or unreadable snapshot).
         Adacovex.Dir_Cache.Snapshot (Dir_Path, Snap, SCt, STrunc, SOK);
         if SOK and then not STrunc then
            for SI in 1 .. SCt loop
               declare
                  Name : constant String :=
                    Snap (SI).Name (1 .. Snap (SI).Name_Len);
                  Path : constant String := Dir_Path & "/" & Name;
                  Dot  : Natural := 0;
               begin
                  if Adacovex.Dir_Cache.Is_Directory (Snap (SI).Kind) then
                     if Name /= ".git"
                       and Name /= ".jj"
                       and Name /= ".hg"
                       and Name /= ".svn"
                       and Name /= ".fslckout"
                       and Name /= "_FOSSIL_"
                       and Name /= "obj"
                       and Name /= "config"
                       and Name /= ".adacovex"
                       and Name /= "alire"
                       and Name /= "gnatprove"
                       and Name /= "__pycache__"
                       and Name /= "node_modules"
                       and Name /= ".venv"
                       and Name /= ".headroom"
                       and Name /= ".lccst"
                       and Name /= "bin"
                       and Name /= "_build"
                     then
                        Push_Dir (Path);
                     end if;
                  else
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
         else
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
                          and Name /= ".jj"
                          and Name /= ".hg"
                          and Name /= ".svn"
                          and Name /= ".fslckout"
                          and Name /= "_FOSSIL_"
                          and Name /= "obj"
                          and Name /= "config"
                          and Name /= ".adacovex"
                          and Name /= "alire"
                          and Name /= "gnatprove"
                          and Name /= "__pycache__"
                          and Name /= "node_modules"
                          and Name /= ".venv"
                          and Name /= ".headroom"
                          and Name /= ".lccst"
                          and Name /= "bin"
                          and Name /= "_build"
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
                        if Dot > 0 and then Name (Dot .. Name'Last) = ".gpr"
                        then
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
         end if;
      end;
   end loop;
end Collect_GPR_Files;
