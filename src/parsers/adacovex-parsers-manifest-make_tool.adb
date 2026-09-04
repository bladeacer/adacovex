separate (Adacovex.Parsers.Manifest)
--  Build a Tool_Entry from a string literal.  The System_Tools table
--  stays readable.  The version-probe flag is deliberately NOT stored:
--  Probe_Version infers it at run time by trying the standard chain
--  ("--version", then "-v", then "version") and taking the first flag
--  that yields a version token, so a tool that only understands a
--  subcommand (go, fossil, git-lfs) needs no special-cased column here
--  and a misconfigured entry cannot exist.
--  @param S  Tool name (lowercase, for example "python3").
--  @param C  Category (default C_Build).
--  @return The Tool_Entry holding S.
function Make_Tool (S : String; C : Tool_Category := C_Build) return Tool_Entry
is
   E : Tool_Entry;
begin
   E.Len := S'Length;
   for I in 1 .. S'Length loop
      E.Name (I) := S (S'First + I - 1);
   end loop;
   E.Cat := C;
   return E;
end Make_Tool;
