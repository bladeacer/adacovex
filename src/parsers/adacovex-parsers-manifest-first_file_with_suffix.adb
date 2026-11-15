separate (Adacovex.Parsers.Manifest)
--  Full path of the first ordinary file directly inside Dir whose base name
--  ends with Suffix, or "" when the directory holds none. Several
--  ecosystems name their manifest after the package rather than after the
--  ecosystem (.NET's *.csproj, Ruby's *.gemspec, CocoaPods' *.podspec,
--  LuaRocks' *.rockspec, OCaml's *.opam, Haskell's *.cabal), so a fixed
--  filename cannot find them. The match is case-sensitive and exact, and
--  the search reads names only, never content.
--  @param Dir  Directory to search (not descended into).
--  @param Suffix  Required base-name suffix, for example ".gemspec".
--  @return The full path of the first match, or "" when there is none.
function First_File_With_Suffix (Dir : String; Suffix : String) return String
is
   use Ada.Directories;
   Search : Search_Type;
   Ent    : Directory_Entry_Type;
begin
   if Dir'Length = 0 or else Suffix'Length = 0 then
      return "";
   end if;
   Start_Search (Search, Dir, "*" & Suffix);
   while More_Entries (Search) loop
      Get_Next_Entry (Search, Ent);
      if Kind (Ent) = Ordinary_File then
         declare
            N : constant String := Simple_Name (Ent);
         begin
            if N'Length > Suffix'Length
              and then N (N'Last - Suffix'Length + 1 .. N'Last) = Suffix
            then
               declare
                  R : constant String := Full_Name (Ent);
               begin
                  End_Search (Search);
                  return R;
               end;
            end if;
         end;
      end if;
   end loop;
   End_Search (Search);
   return "";
exception
   when others =>
      return "";
end First_File_With_Suffix;
