separate (Adacovex.Parsers.Manifest)
--  Source-tree content hash used by Tools_Key. Walks the same
--  directories and files that Discover_System_Dev_Deps scans and
--  combines per-file digests. This is what makes the tool-set cache
--  sound: a file edit that adds or removes a tool reference changes
--  the hash, so the next run re-scans instead of serving a stale
--  set. The directory-exclusion list matches the main walk exactly.
--  @param Dir  Project root directory to hash.
--  @return SHA-256 of the hashed dev-facing files, "" when none.
function Source_Tree_Hash (Dir : String) return String is
   use Ada.Directories;
   type Dir_Entry is record
      Path : Types.Path_Field;
      Len  : Natural := 0;
   end record;
   package Hash_Dir_Stacks is new Ada.Containers.Vectors (Positive, Dir_Entry);
   Stack : Hash_Dir_Stacks.Vector;
   H     : String (1 .. Types.Max_Path * 8);
   HLen  : Natural := 0;

   procedure Add (S : String) is
   begin
      if S'Length > 0 and then HLen + S'Length <= H'Last then
         H (HLen + 1 .. HLen + S'Length) := S;
         HLen := HLen + S'Length;
      end if;
   end Add;

   procedure Push (P : String) is
      Item : Dir_Entry;
   begin
      if P'Length <= Types.Max_Path then
         Item.Len := P'Length;
         Item.Path (1 .. Item.Len) := P (P'First .. P'First + Item.Len - 1);
         Stack.Append (Item);
      end if;
   end Push;
begin
   if not Ada.Directories.Exists (Dir) then
      return "";
   end if;
   Push (Dir);
   while not Stack.Is_Empty loop
      declare
         C  : Dir_Entry := Stack.Last_Element;
         CP : String renames C.Path (1 .. C.Len);
         S  : Search_Type;
         E  : Directory_Entry_Type;
      begin
         Stack.Delete_Last;
         if not Ada.Directories.Exists (CP) then
            null;
         else
            --  Serve the shared snapshot (one enumeration per
            --  directory per process across every walker) with a
            --  direct-enumeration fallback for over-cap trees.
            declare
               Snap   : Adacovex.Dir_Cache.Dir_Entry_List;
               SCt    : Natural;
               STrunc : Boolean;
               SOK    : Boolean;
            begin
               Adacovex.Dir_Cache.Snapshot (CP, Snap, SCt, STrunc, SOK);
               if SOK and then not STrunc then
                  for SI in 1 .. SCt loop
                     declare
                        N    : constant String :=
                          Snap (SI).Name (1 .. Snap (SI).Name_Len);
                        NP   : constant String := CP & "/" & N;
                        Is_D : constant Boolean :=
                          Adacovex.Dir_Cache.Is_Directory (Snap (SI).Kind);
                     begin
                        if Is_D then
                           if N /= ".git"
                             and then N /= ".jj"
                             and then N /= ".hg"
                             and then N /= ".svn"
                             and then N /= "obj"
                             and then N /= "tests"
                             and then N /= "config"
                             and then N /= ".adacovex"
                             and then N /= "alire"
                             and then N /= "gnatprove"
                             and then N /= "__pycache__"
                             and then N /= "node_modules"
                             and then N /= ".venv"
                             and then N /= ".headroom"
                             and then N /= ".lccst"
                             and then N /= "_build"
                           then
                              Push (NP);
                           end if;
                        elsif Should_Scan (N) then
                           Add (Adacovex.Cache.Hash_File (NP));
                        end if;
                     end;
                  end loop;
               else
                  Start_Search (S, CP, "");
                  while More_Entries (S) loop
                     Get_Next_Entry (S, E);
                     declare
                        N : constant String := Simple_Name (E);
                     begin
                        if Kind (E) = Directory then
                           if N /= "."
                             and then N /= ".."
                             and then N /= ".git"
                             and then N /= ".jj"
                             and then N /= ".hg"
                             and then N /= ".svn"
                             and then N /= "obj"
                             and then N /= "tests"
                             and then N /= "config"
                             and then N /= ".adacovex"
                             and then N /= "alire"
                             and then N /= "gnatprove"
                             and then N /= "__pycache__"
                             and then N /= "node_modules"
                             and then N /= ".venv"
                             and then N /= ".headroom"
                             and then N /= ".lccst"
                             and then N /= "_build"
                           then
                              Push (Full_Name (E));
                           end if;
                        elsif Kind (E) = Ordinary_File then
                           if Should_Scan (Simple_Name (E)) then
                              Add (Adacovex.Cache.Hash_File (Full_Name (E)));
                           end if;
                        end if;
                     end;
                  end loop;
                  End_Search (S);
               end if;
            end;
         end if;
      end;
   end loop;
   if HLen = 0 then
      return "";
   end if;
   return Adacovex.Cache.Hash_String (H (1 .. HLen));
end Source_Tree_Hash;
