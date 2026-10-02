separate (Adacovex.Parsers.Manifest)
--  Version recorded for a module in a parsed vendor manifest, "" when the
--  table does not list it.
--  @param Table  Parsed vendor/modules.txt.
--  @param Module  Module path to look for (for example "golang.org/x/text").
--  @return The version token (for example "v0.42.0"), or "" when absent.
function Go_Module_Version
  (Table : Go_Module_Vectors.Vector; Module : String) return String is
begin
   if Module'Length = 0 then
      return "";
   end if;
   for I in 1 .. Integer (Table.Length) loop
      if Table (I).PLen > 0
        and then Table (I).PLen = Module'Length
        and then Table (I).Path (1 .. Table (I).PLen) = Module
      then
         return Table (I).Ver (1 .. Table (I).VLen);
      end if;
   end loop;
   return "";
end Go_Module_Version;
