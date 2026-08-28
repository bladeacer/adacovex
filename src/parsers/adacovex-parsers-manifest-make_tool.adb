separate (Adacovex.Parsers.Manifest)
--  Build a Tool_Entry from a string literal.  The System_Tools table
--  stays readable.  VFlag is the version-probe flag or subcommand.
--  Every tool here accepts "--version" except fossil, git-lfs, and go.
--  Those use the "version" subcommand.  The probe falls back through
--  "--version", "-v", and "version" when the configured flag fails.
--  @param S  Tool name (lowercase, for example "python3").
--  @param VFlag  Version-probe flag (default "--version").
--  @return The Tool_Entry holding S.
function Make_Tool
  (S : String; VFlag : String := "--version") return Tool_Entry
is
   E : Tool_Entry;
begin
   E.Len := S'Length;
   for I in 1 .. S'Length loop
      E.Name (I) := S (S'First + I - 1);
   end loop;
   E.FLen := VFlag'Length;
   for I in 1 .. VFlag'Length loop
      E.Flag (I) := VFlag (VFlag'First + I - 1);
   end loop;
   return E;
end Make_Tool;
