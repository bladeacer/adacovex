separate (Adacovex.Parsers.Manifest)
--  Combined content hash of everything that shapes the dependency graph.
--  The publishing manifest, the dev manifest, and the alire.lock are
--  included. Every .gpr file collected from the project tree is
--  included. The vendored directories (classic roots and language-
--  agnostic vendor dirs) are included. The root project's detected
--  language mix is included. It is a cheap probe of the source tree's
--  file-name distribution. A source-language change then invalidates
--  the cached graph too. Returns "" when no input could be hashed.
--  Nothing is cached in that case.
--  The "graph-" prefix (not "graph:") keeps the key usable as an on-disk
--  cache entry name: Windows rejects ':' in a file name, and a keyed blob
--  written under such a name is never found again.
--  @param Target_Dir  Project root directory (for alire-dev.toml,
--    alire/alire.lock, the vendored dirs, and the root language probe,
--    which live beside or under it).
--  @param Manifest_Path  Path to the Alire manifest (can be an override).
--  @param GPR_Files  Every .gpr file found under the target tree.
--  @return "graph-" + SHA-256 digest, or "" when inputs are unhashable.
function Graph_Key
  (Target_Dir    : String;
   Manifest_Path : String;
   GPR_Files     : Path_Vectors.Vector) return String
is
   T    : constant String :=
     (if Target_Dir'Length > 1 and then Target_Dir (Target_Dir'Last) = '/'
      then Target_Dir (Target_Dir'First .. Target_Dir'Last - 1)
      else Target_Dir);
   Comb : String (1 .. Types.Max_Path);
   CLen : Natural := 0;

   procedure Add (S : String) is
   begin
      if S'Length > 0 and then CLen + S'Length <= Comb'Last then
         Comb (CLen + 1 .. CLen + S'Length) := S;
         CLen := CLen + S'Length;
      end if;
   end Add;
begin
   Add (Adacovex.Cache.Hash_File (Manifest_Path));
   Add (Adacovex.Cache.Hash_File (T & "/alire-dev.toml"));
   Add (Adacovex.Cache.Hash_File (T & "/alire/alire.lock"));
   --  A root requirements*.txt shapes the graph (its entries become
   --  pypi components), so editing it must invalidate the cached graph.
   declare
      use Ada.Directories;
      Req_Search : Search_Type;
      Req_Ent    : Directory_Entry_Type;
   begin
      Start_Search (Req_Search, T, "requirements*.txt");
      while More_Entries (Req_Search) loop
         Get_Next_Entry (Req_Search, Req_Ent);
         if Kind (Req_Ent) = Ordinary_File then
            Add (Adacovex.Cache.Hash_File (Full_Name (Req_Ent)));
         end if;
      end loop;
      End_Search (Req_Search);
   exception
      when others =>
         null;
   end;
   Add (Vendored_Hash (Target_Dir));
   declare
      Langs : Lang_Vectors.Vector;
   begin
      Detect_Languages (T, 3, Langs, Skip_Vendored => True);
      Add ("rl:" & Language_Summary (Langs, ""));
   end;
   for I in 1 .. Integer (GPR_Files.Length) loop
      Add
        (Adacovex.Cache.Hash_File
           (GPR_Files (I).Path (1 .. GPR_Files (I).Len)));
   end loop;
   if CLen = 0 then
      return "";
   end if;
   return "graph-" & Adacovex.Cache.Hash_String (Comb (1 .. CLen));
end Graph_Key;
