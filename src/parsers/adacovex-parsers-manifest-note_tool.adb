separate (Adacovex.Parsers.Manifest)
--  Record Tool as referenced by the project's files. The referenced set is
--  deduplicated, so a tool named by twenty build files is stored once.
--  @param Tool  Tool entry from the curated system-tool table.
procedure Note_Tool (Tool : Tool_Entry) is
begin
   Add_Dep_Name (Referenced, Tool.Name (1 .. Tool.Len));
end Note_Tool;