separate (Adacovex.Parsers.Manifest)
--  Version-probe flag for a registered tool name (the table entry's
--  Flag), defaulting to "--version" for names not in the table.
--  @param Name  Tool name from the System_Tools table.
--  @return The version-probe flag or subcommand.
function Version_Flag (Name : String) return String is
begin
   for T in System_Tools'Range loop
      if System_Tools (T).Len = Name'Length
        and then System_Tools (T).Name (1 .. Name'Length) = Name
      then
         return System_Tools (T).Flag (1 .. System_Tools (T).FLen);
      end if;
   end loop;
   return "--version";
end Version_Flag;
